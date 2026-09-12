write_checkpoint -force /tmp/checkpoint.dcp

# manage DRCs to improve readability

create_waiver -type DRC -id {LUTLP-2} -user {Jacob Tilger} -desc {NCL gates require the feedback paths} -objects [get_cells -hierarchical NCL_GATE*] -tags QDI

create_waiver -type METHODOLOGY -id {TIMING-23} -user {Jacob Tilger} -desc {NCL gates require the feedback paths.} -objects [get_pins -hierarchical NCL_GATE*/*] -tags QDI
create_waiver -type METHODOLOGY -id {TIMING-13} -user {Jacob Tilger} -desc {Bridges and ACK require hard timed paths.} -objects [get_pins -filter "DIRECTION == IN" -of [get_cells -leaf -filter "NCL_WIRE_TYPE == IN_ENC"]] -tags QDI

# constants

set fb_required_delay 2.0
set slice_lutnum      4

# finite set helper functions as per https://wiki.tcl-lang.org/page/Manipulating+sets+in+Tcl
proc set_add {seta elem} {
	if {[lsearch -exact $seta $elem] == -1} {
		lappend seta $elem
	}
}

proc set_contains {seta elem} {
	return [expr [lsearch $seta $elem] >= 0]
}

proc set_union {seta setb} {
	set result $seta

	foreach elem $setb {
		if {[lsearch -exact $seta $elem] == -1} {
			lappend result $elem
		}
	}
	return $result
}

proc set_intersection {seta setb} {
	set result {}

	foreach elem $setb {
		if {[lsearch -exact $seta $elem] != -1} {
			lappend result $elem
		}
	}
	return $result
}

proc set_exclusion {seta setb} {
	set result {}

	foreach elem $setb {
		if {[lsearch -exact $seta $elem] == -1} {
			lappend result $elem
		}
	}
	return $result
}

proc set_size {seta} {
	return [llength $seta]
}
# end finite set helper functions

# find all timing objects
set ack [get_cells -leaf -filter "NCL_WIRE_TYPE == ACK"]
set bridge [get_cells -leaf -filter "NCL_WIRE_TYPE == NCL_CLK"]

set inbridge_enc [get_cells -leaf -filter "NCL_WIRE_TYPE == IN_ENC"]

set ncl_gates [get_cells -hierarchical NCL_GATE*]

set comp_clk_NCL2CLK [get_cells -leaf -filter "NCL_WIRE_TYPE == COMP_CLK_NCL2CLK"]

set comp_clk_CLK2NCL [get_cells -leaf -filter "NCL_WIRE_TYPE == COMP_CLK_CLK2NCL"]

set markers {}

# timing constraints
foreach cc $bridge {
	# find appropriate pins
	set mark [get_pins -of [get_cells $cc] -filter "DIRECTION == OUT"]
	set net  [get_nets -of $mark]

	if {[llength $net]} {
		set_false_path -through [get_pins -of $net -filter "!IS_LEAF"]
	}
}
set_property DONT_TOUCH false $bridge

foreach cc $comp_clk_NCL2CLK {
	set bridge [get_property PARENT $cc]

	set ki_clk [get_nets -of [get_pins -filter "DIRECTION == OUT" -of $cc]]
	set ki_net [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $cc]]

	set ki_pin [get_pins -filter "IS_LEAF && DIRECTION == OUT" -of $ki_net]
	set ki_vec_marks [get_cells -leaf -filter "NCL_WIRE_TYPE == COMP_KI_VEC && PARENT == $bridge"]
	set ki_or [get_cells -leaf -of [get_pins -of [get_nets -segments -of $ki_vec_marks] -filter "IS_LEAF && DIRECTION == OUT"] -filter "PARENT == $bridge"]

	set di_mark [get_cells -leaf -filter "NCL_WIRE_TYPE == COMP_DI_REG && PARENT == $bridge"]
	set src_pins [get_pins -filter "IS_LEAF && DIRECTION == OUT" -of [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $ki_or]]]

	set di_trg []
	set di_trg_wlist $di_mark
	while {[llength $di_trg_wlist] != 0} {
		set mm [lindex $di_trg_wlist 0]
		set di_trg_wlist [lreplace $di_trg_wlist 0 0]

		switch [get_property PRIMITIVE_GROUP $mm] {
			FLOP_LATCH - DMEM - BMEM {
				lappend di_trg $mm
			}
			LUT {
				lappend di_trg_wlist {*}[list [get_cells -of [get_pins -filter "IS_LEAF && DIRECTION == OUT" -of [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $mm]]]]]
				if {[llength [get_nets -of [get_pins -filter "DIRECTION == OUT" -of $mm]]] == 0} { lappend markers $mm }
			}
		}
	}

	set_min_delay $fb_required_delay -from $src_pins -to $ki_pin
	set_max_delay [expr $fb_required_delay - 1] -from $src_pins -to $di_trg

	group_path -name "NCL_BRIDGE_KI_CLK" -from $src_pins

	create_clock -period [expr $fb_required_delay * 2] $ki_clk
	
	create_waiver -type METHODOLOGY -id {TIMING-13} -user {Jacob Tilger} -desc {Bridges and ACK require hard timed paths.} -objects $src_pins -tags QDI
	create_waiver -type METHODOLOGY -id {TIMING-3}  -user {Jacob Tilger} -desc {Bridges generate local clocks.} -objects [get_pins $cc/O] -tags QDI
	
	create_waiver -type DRC -id {PDRC-153} -user {Jacob Tilger} -desc {Bridges generate local clocks.} -objects [get_nets -segments -of [get_pins $cc/I]] -tags QDI

	set cdc_sync [get_cells -filter "ASYNC_REG && PARENT == $bridge" -leaf]

	set_false_path -from [get_clocks -of $ki_clk] -to $cdc_sync
	set_false_path -to [get_clocks -of $ki_clk] 

	set_max_delay -datapath_only [get_property PERIOD [get_clocks -of $cdc_sync]] -from $di_trg

	# remove marker
	lappend markers {*}[list $ki_vec_marks]
}

foreach cc $comp_clk_CLK2NCL {
	set bridge [get_property PARENT $cc]

	set ki_clk [get_nets -of [get_pins -filter "DIRECTION == OUT" -of $cc]]
	set ki_src [get_pins -of [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $cc]] -filter "IS_LEAF && DIRECTION == OUT"]

	create_clock -period [expr $fb_required_delay * 2] $ki_clk
	
	create_waiver -type METHODOLOGY -id {TIMING-2}  -user {Jacob Tilger} -desc {Bridges generate local clocks.} -objects [get_pins $cc/O] -tags QDI
	create_waiver -type METHODOLOGY -id {TIMING-14} -user {Jacob Tilger} -desc {CLK2NCL has only a single Gray-CTR on ki-clk and uses a LUT as buffer to preserve clock-network resources.} -objects $cc -tags QDI
	create_waiver -type METHODOLOGY -id {TIMING-13} -user {Jacob Tilger} -desc {CLK2NCL needs forced skew on ki-clk path.} -objects [get_pins $cc/I0] -tags QDI
	
	create_waiver -type DRC -id {PDRC-153}    -user {Jacob Tilger} -desc {Bridges generate local clocks.} -objects [get_nets -segments -of [get_pins $cc/O]] -tags QDI
	create_waiver -type DRC -id {PLHOLDVIO-2} -user {Jacob Tilger} -desc {CLK2NCL has only a single Gray-CTR on ki-clk and uses a LUT as buffer to preserve clock-network resources.} -objects $cc -tags QDI

	set cdc_sync [get_cells -filter "ASYNC_REG && PARENT == $bridge" -leaf]

	set_min_delay -from $ki_src -to [get_pins -filter "DIRECTION == IN" -of $cc] $fb_required_delay

	group_path -name "KI_CLK_FORCE_SKEW" -from $ki_src -to [get_pins -filter "DIRECTION == IN" -of $cc]

	set_false_path -from [get_clocks -of $ki_clk] -to $cdc_sync
	set_false_path -to [get_clocks -of $ki_clk]
}

foreach clk [get_clocks] {
	set clk_name [string map {"/" "_"} [get_property NAME $clk]]

	set edges [get_property WAVEFORM $clk]
	set cperiod [get_property PERIOD $clk]

	# init values (final times are smaller than 1 period)
	set T_rise_rise $cperiod
	set T_rise_fall $cperiod
	set T_fall_rise $cperiod
	set T_fall_fall $cperiod

	set nextrise [expr $cperiod + [lindex $edges 0]]
	set nextfall [expr $cperiod + [lindex $edges 1]]

	while {[llength $edges] >= 4} {
		set rr [expr [lindex $edges 2] - [lindex $edges 0]]
		set rf [expr [lindex $edges 1] - [lindex $edges 0]]
		set fr [expr [lindex $edges 2] - [lindex $edges 1]]
		set ff [expr [lindex $edges 3] - [lindex $edges 1]]

		if {$rr < $T_rise_rise} { set T_rise_rise $rr }
		if {$rf < $T_rise_fall} { set T_rise_fall $rf }
		if {$fr < $T_fall_rise} { set T_fall_rise $fr }
		if {$ff < $T_fall_fall} { set T_fall_fall $ff }

		set edges [lreplace $edges 0 1]
	}

	set rr [expr $nextrise         - [lindex $edges 0]]
	set rf [expr [lindex $edges 1] - [lindex $edges 0]]
	set fr [expr $nextrise         - [lindex $edges 1]]
	set ff [expr $nextfall         - [lindex $edges 1]]

	if {$rr < $T_rise_rise} { set T_rise_rise $rr }
	if {$rf < $T_rise_fall} { set T_rise_fall $rf }
	if {$fr < $T_fall_rise} { set T_fall_rise $fr }
	if {$ff < $T_fall_fall} { set T_fall_fall $ff }

	set clock_desc(rr,$clk_name) $T_rise_rise
	set clock_desc(rf,$clk_name) $T_rise_fall
	set clock_desc(fr,$clk_name) $T_fall_rise
	set clock_desc(ff,$clk_name) $T_fall_fall
}

# encoders
foreach cc $inbridge_enc {
	set bridge [get_property PARENT $cc]

	set val_pin [get_pins -of $cc -filter "REF_PIN_NAME == [get_property NCL_IN_ENC_VALID_PIN $cc]"]
	set dat_pin [get_pins -of $cc -filter "REF_PIN_NAME == [get_property NCL_IN_ENC_DATA_PIN $cc]"]
	if {[get_property NCL_IN_ENC_KI_PIN $cc] != "none"} {
		set ki_pin [get_pins -of $cc -filter "REF_PIN_NAME == [get_property NCL_IN_ENC_KI_PIN $cc]"]
	} else {
		set ki_pin ""
	}

	set edge_conf [get_property NCL_IN_ENC_DATA2VALID_EDGES $cc]

	set opin [get_pins -filter "DIRECTION == OUT" -of $cc]

	set d_src []
	set d_src_wlist [get_cells -of [get_pins -of [get_nets -segments -of $dat_pin] -filter "IS_LEAF && DIRECTION == OUT"]]
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

	if {[llength $d_src] != 0} {
		set val_src [get_cells -filter "NCL_IN_ENC_REG == clk_valid && PARENT == $bridge" -leaf]

		set clk [get_clocks -of $d_src]
		set clk_name [string map {"/" "_"} [get_property NAME $clk]]

		set Treq $clock_desc($edge_conf,$clk_name)

		set_max_delay -datapath_only -from $d_src -to $dat_pin $Treq

		group_path -name "NCL_IN_ENC_CLK_DAT" -from $d_src -to $dat_pin
	}

	if {[llength $ki_pin] != 0} {
		set ki_src [get_pins -of [get_nets -segments -of $ki_pin] -filter "DIRECTION == OUT && IS_LEAF"]

		set_max_delay -from $ki_src -to $ki_pin $fb_required_delay

		group_path -name "NCL_IN_ENC_KI" -from $ki_src -to $ki_pin
	}

	set_false_path -through $opin
}

foreach cc $ack {
	# find appropriate pins
	set mark [get_pins -of [get_cells $cc] -filter "DIRECTION == IN"]
	set net  [get_nets -segments -of $mark]

	set ack_src [get_pins -of $net -filter "IS_LEAF && DIRECTION == OUT"]

	set pc [get_cells -of $ack_src]
	set pfb [get_pins -of $net -filter "PARENT_CELL == $pc && DIRECTION == IN"]

	set ack_snk [get_pins -of $pc -filter "NAME != $pfb && DIRECTION == IN"]

	# add constraints

	set_min_delay $fb_required_delay -from $ack_src -to $ack_snk
	
	create_waiver -type METHODOLOGY -id {TIMING-13} -user {Jacob Tilger} -desc {Bridges and ACK require hard timed paths.} -objects [get_pins -of $pc] -tags QDI

	group_path -name "NCL_ACK_FB" -from $ack_src -to $ack_snk

	# remove marker
	lappend markers $cc
}
# end timing constraints

# find all isofork objects

set isoforks [get_cells -hierarchical QDI_ISOFORK]

# isofork constraints
set isofork_id 0
create_property -type string QDI_ISOFORK_GRPS  pin
create_property -type bool   QDI_ISOFORK       pin
create_property -type bool   QDI_ISOFORK_COLOC cell

set_property DONT_TOUCH false $isoforks

set isofork_lut []

# initial marking
foreach cc $isoforks {
	set trgs [get_pins -filter "IS_LEAF && DIRECTION == IN" -of [get_nets -segments -of [get_pins -filter "REF_PIN_NAME == O" -of $cc]]]

	foreach tt $trgs {
		set grp [get_property QDI_ISOFORK_GRPS $tt]
		set grp [set_add $grp $isofork_id]
		set_property QDI_ISOFORK_GRPS  $grp  $tt
	}
	
	set_property QDI_ISOFORK       true  $trgs
	set_property QDI_ISOFORK_COLOC false [get_cells -of $trgs]

	lappend isofork_lut [get_cells -of $trgs]

	incr isofork_id
}

# merge groups
while 1 {
	set fin true
	for {set ii 0} {$ii < $isofork_id} {incr ii} {
		for {set jj [expr $ii + 1]} {$jj < $isofork_id} {incr jj} {
			set prim [lindex $isofork_lut $ii]
			set sec  [lindex $isofork_lut $jj]

			if {[set_size [set_intersection $prim $sec]] != 0} { # merge
				lset isofork_lut $ii [set_union $prim $sec]
				lset isofork_lut $jj {}
				set fin false
			}
		}
	}
	if {$fin} break
}

# cluster groups
foreach isoset $isofork_lut {
	if {[llength $isoset] == 0} continue
	# sort after input number asc
	set l6 {}
	set l5 {}
	set l4 {}
	set l3 {}
	set l2 {}
	set l1 {}
	foreach id $isoset {
		set cc [get_cells $id]
		switch [get_property REF_NAME $cc] {
			LUT6 {
				lappend l6 $id
			}
			LUT5 {
				lappend l5 $id
			}
			LUT4 {
				lappend l4 $id
			}
			LUT3 {
				lappend l3 $id
			}
			LUT2 {
				lappend l2 $id
			}
			default {
				lappend l1 $id
			}
		}
	}
	set isoset [concat $l6 $l5 $l4 $l3 $l2 $l1]

	# co-locate cells
	for {set ii 0} {$ii < [llength $isoset]} {incr ii} {
		set id [lindex $isoset $ii]
		set cur [get_cells $id]
		if {[get_property HLUTNM $cur] != ""} continue
		set cur_pins [get_pins -filter "DIRECTION == OUT && IS_LEAF" -of [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $cur]]]

		set score 0
		set selected {}
		for {set jj [expr $ii + 1]} {$jj < [llength $isoset]} {incr jj} {
			set cand [get_cells [lindex $isoset $jj]]
			if {[get_property HLUTNM $cand] != ""} continue
			set cand_pins [get_pins -filter "DIRECTION == OUT && IS_LEAF" -of [get_nets -segments -of [get_pins -filter "DIRECTION == IN" -of $cand]]]

			if {[set_size [set_union [get_cells -of $cur_pins] [get_cells -of $cand_pins]]] > 5} continue
			set l_score [set_size [set_intersection [get_cells -of $cur_pins] [get_cells -of $cand_pins]]]]

			if {$score > $l_score} continue

			set score $l_score
			set selected $cand
		}
		if {$score == 0} continue

		set_property LUTNM $id $cur
		set_property LUTNM $id $selected

		set_property QDI_ISOFORK_COLOC true $selected
	}

	# cluster cells
	set slice 0
	set slice_ctr 0
	set id [lindex $isoset 0]
	set rlocs {}

	foreach cc $isoset {
		set cc [get_cells $cc]
		if {[get_property QDI_ISOFORK_COLOC $cc]} continue

		lappend rlocs [get_property NAME $cc]
		lappend rlocs "X${slice}Y0"

		incr slice_ctr
		if {$slice_ctr == $slice_lutnum} {
			set slice_ctr 0
			incr slice
		}
	}

	if {$slice_ctr == 1 && $slice == 0} continue

	create_macro $id
	update_macro $id $rlocs
}
# end isofork constraints

set_property DONT_TOUCH false $markers
remove_cell $markers