# init DRC ruledeck

# create dummy check to allow safe deletion
create_drc_check -name QDICHK-10000 -rule_body {}

foreach cc [get_drc_checks QDICHK-*] {
	delete_drc_check $cc
}

create_drc_ruledeck qdi

# create DRCs
proc drc_qdichk1_gateRoutingChecker {} {
	set delay_limit 1500
	set vios {}

	foreach cc [get_cells -hierarchical NCL_GATE*] {
		set opin [get_pins -of $cc -filter "DIRECTION == OUT"]
		set ipin [get_pins -of [get_nets -of $opin] -filter "DIRECTION == IN && PARENT_CELL == $cc"]
		set net  [get_nets -of $opin]

		set delay [get_net_delays -of $net -filter "TO_PIN == $ipin"]

		if {[get_property SLOW_MAX $delay] > $delay_limit} {
			lappend vios [create_drc_violation -name {QDICHK-1} -msg "The feedback delay for cell %ELG is too high." $cc ]
		}
	}

	if {[llength $vios] > 0} {
		return -code error $vios
	} else {
		return {}
	}
}

create_drc_check -name {QDICHK-1} -hiername {Implementation.Routing} -desc {QDI feedback delay} -rule_body drc_qdichk1_gateRoutingChecker -severity {Critical Warning}

proc drc_qdichk2_isoforkChecker {} {
	set skew_limit 1500
	set vios {}
	array unset grps

	set idmax -1
	foreach pp [get_pins -filter "QDI_ISOFORK" -hierarchical *] {
		set grp [get_property QDI_ISOFORK_GRPS $pp]
		if {$grp > $idmax} {set idmax $grp}
		lappend grps($grp) $pp
	}

	for {set ii 0} {$ii <= $idmax} {incr ii} {
		set max 0
		set min infinity
		foreach pp $grps($ii) {
			set delay [get_property SLOW_MAX [get_net_delays -of [get_nets -of $pp] -filter "TO_PIN == $pp"]]
			if {$delay < $min} {set min $delay}
			if {$delay > $max} {set max $delay}
		}
		if {[expr $max - $min] > $skew_limit} {
			lappend vios [create_drc_violation -name {QDICHK-2} -msg "Skew of isochronicity group with pin %ELG is too high." [lindex $grps($ii) 0]]
		}
	}

	if {[llength $vios] > 0} {
		return -code error $vios
	} else {
		return {}
	}
}

create_drc_check -name {QDICHK-2} -hiername {Implementation.Placement} -desc {QDI isochronic regions} -rule_body drc_qdichk2_isoforkChecker -severity {Critical Warning}

proc drc_qdichk3_bridgeSanity {} {
	set vios {}

	# CLK -> NCL
	set d_src []
	foreach cc [get_cells -leaf -filter "NCL_WIRE_TYPE == IN_ENC"] {
		set enc_pin [get_pins -of $cc -filter "REF_PIN_NAME == [get_property NCL_IN_ENC_DATA_PIN $cc]"]

		set d_src_wlist [get_cells -of [get_pins -of [get_nets -segments -of $enc_pin] -filter "IS_LEAF && DIRECTION == OUT"]]
		while {[llength $d_src_wlist] != 0} {
			set mm [lindex $d_src_wlist 0]
			set d_src_wlist [lreplace $d_src_wlist 0 0]

			switch [get_property PRIMITIVE_GROUP $mm] {
				FLOP_LATCH - DMEM - BMEM {
					lappend d_src $mm
				}
				LUT {
					lappend d_src_wlist {*}[list [get_cells -of [get_pins -filter "IS_LEAF && DIRECTION == OUT" -of [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $mm]]]]]
					if {[llength [get_nets -of [get_pins -filter "DIRECTION == OUT" -of $mm]]] == 0} { lappend markers $mm }
				}
			}
		}
	}

	foreach cc $d_src {
		switch [get_property PRIMITIVE_GROUP $cc] {
			FLOP_LATCH {
				set src [get_cells -filter "REF_NAME == VCC || REF_NAME == GND" -of [get_nets -of [get_pins -filter "REF_PIN_NAME == D" -of $cc] -segments]]
				if {[llength $src] != 0} {
					lappend vios [create_drc_violation -name {QDICHK-3} -msg "Bridge register %ELG has constant input." $cc -severity {Critical Warning}]
				}
			}
			DMEM {
				set src [get_cells -filter "REF_NAME == VCC || REF_NAME == GND" -of [get_nets -of [get_pins -filter "REF_PIN_NAME == I" -of $cc] -segments]]
				if {[llength $src] != 0} {
					lappend vios [create_drc_violation -name {QDICHK-3} -msg "Bridge register %ELG has constant input." $cc -severity {Critical Warning}]
				}

			}
			BMEM {
				lappend vios [create_drc_violation -name {QDICHK-3} -msg "Cell %ELG is BRAM." $cc] -severity {Critical Warning}
			}
		}
	}

	# NCL -> CLK
	foreach mm [get_cells -leaf -filter "NCL_WIRE_TYPE == COMP_CLK_NCL2CLK"] {
		set br [get_property PARENT $mm]
		set comp [get_cells $br/comp]
		set nets [get_nets -segments -of [get_pins $br/dri_*]]
		set pins [get_pins -of [get_nets -segments -of [get_pins -of $nets -filter "PARENT_CELL == $comp"]] -filter "PARENT_CELL == $br"]
		foreach pp $pins {
			lappend vios [create_drc_violation -name {QDICHK-3} -msg "Bridge input pin %ELG is constant." $pp -severity {Critical Warning}]
		}
	}

	if {[llength $vios] > 0} {
		return -code error $vios
	} else {
		return {}
	}
}

create_drc_check -name {QDICHK-3} -hiername {Netlist} -desc {QDI bridge sanity} -rule_body drc_qdichk3_bridgeSanity -severity {Critical Warning}

proc drc_qdichk4_bridgeWidth {} {
	set vios {}

	# NCL -> CLK
	foreach mm [get_cells -leaf -filter "NCL_WIRE_TYPE == COMP_CLK_NCL2CLK"] {
		set br [get_property PARENT $mm]
		set pins [get_pins $br/dro*]
		foreach pp $pins {
			set nn [get_nets -segments -of $pp]
			if {[llength $nn] != 0} continue
			if {[llength [get_pins -filter "IS_LEAF" -of $nn]] >= 2} continue
			lappend vios [create_drc_violation -name {QDICHK-4} -msg "Bridge pin %ELG is unused." $pp -severity {Advisory}]
		}
	}

	if {[llength $vios] > 0} {
		return -code error $vios
	} else {
		return {}
	}
}

create_drc_check -name {QDICHK-4} -hiername {Netlist} -desc {QDI bridge width} -rule_body drc_qdichk4_bridgeWidth -severity {Advisory}

add_drc_checks -ruledeck qdi {QDICHK-1 QDICHK-2 QDICHK-3 QDICHK-4}
