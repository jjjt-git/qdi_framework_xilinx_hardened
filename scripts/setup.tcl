set dir [file dirname [file normalize [info script]]]

# add scripts
add_files -fileset utils_1 -norecurse $dir/set_constraints.tcl
add_files -fileset utils_1 -norecurse $dir/set_hardmask.tcl

# apply scripts to appropriate hooks
set_property STEPS.INIT_DESIGN.TCL.POST [ get_files $dir/set_constraints.tcl -of [get_fileset utils_1] ] [current_run]
set_property STEPS.PLACE_DESIGN.TCL.POST [ get_files $dir/set_hardmask.tcl -of [get_fileset utils_1] ] [current_run]

# enable optional phases required for hitting some constraints
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
