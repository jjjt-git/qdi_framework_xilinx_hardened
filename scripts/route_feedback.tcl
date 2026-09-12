# get all the individual feedback pins
set ncl_feedback_p0 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB0}] -filter {REF_PIN_NAME=~I0}]
set ncl_feedback_p1 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB1}] -filter {REF_PIN_NAME=~I1}]
set ncl_feedback_p2 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB2}] -filter {REF_PIN_NAME=~I2}]
set ncl_feedback_p3 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB3}] -filter {REF_PIN_NAME=~I3}]
set ncl_feedback_p4 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB4}] -filter {REF_PIN_NAME=~I4}]
set ncl_feedback_p5 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB5}] -filter {REF_PIN_NAME=~I5}]

set ncl_merged_feedback_p0 [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_MERGED?_FB0}] -filter {REF_PIN_NAME=~I0}]

# get all critical ncl outputs (those of feedback-requiring gates)
# route_design with min_delay requires input pins
# therefore, we get the transitive pins
#set ncl_output_pins [get_pins -of_objects [get_nets -of_objects [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB*}] -filter {REF_PIN_NAME=~O}]] -filter {REF_PIN_NAME=~I*}]

# route only feedback pins
route_design -pins [concat $ncl_feedback_p0 $ncl_feedback_p1 $ncl_feedback_p2 $ncl_feedback_p3 $ncl_feedback_p4 $ncl_feedback_p5 $ncl_merged_feedback_p0] -delay

# write checkpoint for validation
#write_checkpoint -force [get_property DIRECTORY [current_run]]/../../feedback_routed.dcp

# route the rest of paths from feedback pins
#route_design -nets $ncl_output -min_delay 1100