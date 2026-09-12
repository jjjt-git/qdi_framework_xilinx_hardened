#write_checkpoint -force /tmp/checkpoint.dcp

set route_work ""

set simple_gates [get_cells -hierarchical NCL_GATE_SIMPLE*]
set latch_rst_gates [get_cells -hierarchical NCL_GATE_EXTRST*]
#open_checkpoint /tmp/checkpoint.dcp
#set gate [lindex [get_cells -hierarchical NCL_GATE_SIMPLE*] 0]
#set gate [lindex [get_cells -hierarchical NCL_GATE_EXTRST*] 0]

foreach gate $simple_gates {
	set loc [get_property NAME [get_property LOC $gate]]
	
	set opin [get_pins -of $gate -filter "REF_PIN_NAME == O"]
	set ipin [get_pins -of [get_nets -of $opin] -filter "PARENT_CELL == $gate && REF_PIN_NAME != O"]
	
	if {[llength $ipin] == 0} {
		continue
	}
	
	lappend route_work $ipin
	
	set_property IS_BEL_FIXED true $gate
	
	set net [get_nets -of $ipin]
	
	set fb  [get_property REF_PIN_NAME $ipin]
	
	set bel [string index [get_property BEL $gate] 7]
	set pos [string index [get_property BEL $gate] 8]
	
	switch $pos {
		6 {
			switch $bel {
				A - D {
					set_property LOCK_PINS "${fb}:A5" $gate
				}
				B - C {
					set_property LOCK_PINS "${fb}:A4" $gate
				}
			}
		}
		5 {
			switch $bel {
				A - D {
					set_property LOCK_PINS "${fb}:A2" $gate
				}
				B - C {
					set_property LOCK_PINS "${fb}:A1" $gate
				}
			}
		}
	}
}

#write_checkpoint -force /tmp/checkpoint_post_simple.dcp

foreach gate $latch_rst_gates {
	set rst_gate [get_cells -of [get_nets -of [get_pins -of $gate -filter "REF_PIN_NAME == O"]] -filter "PRIMITIVE_GROUP == FLOP_LATCH"]

	set loc [get_property NAME [get_property LOC $gate]]
	
	set opin [get_pins -of $rst_gate -filter "REF_PIN_NAME == Q"]
	set ipin [get_pins -of [get_nets -of $opin] -filter "PARENT_CELL == $gate"]
	
	if {[llength $ipin] == 0} {
		continue
	}
	
	lappend route_work $ipin
	
	set_property IS_BEL_FIXED true $gate
	set_property IS_BEL_FIXED true $rst_gate
	
	set fb [get_property REF_PIN_NAME $ipin]	
	set net [get_nets -of $ipin]
	
	set bel [string index [get_property BEL $gate] 7]
	set rst_bel [string index [get_property BEL $rst_gate] 7]
	
	if {$bel != $rst_bel} {
		puts "$gate and $rst_gate placed into seperate BELs. This will impact the design's speed."
	}
	
	switch $bel {
		A - D {
			set_property LOCK_PINS "${fb}:A3" $gate
		}
		B - C {
			set_property LOCK_PINS "${fb}:A2" $gate
		}
	}
}

#write_checkpoint -force /tmp/checkpoint_post_latch_rst.dcp
