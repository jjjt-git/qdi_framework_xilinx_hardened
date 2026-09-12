# allow comb loop on NCL gates
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -of_objects [get_pins -of_objects [get_cells -hierarchical {NCL_GATE*}]]]

## break timing loop on feedback path
#set_disable_timing [get_cells -hierarchical {NCL_GATE_FB0}] -from I0 -to O
#set_disable_timing [get_cells -hierarchical {NCL_GATE_FB1}] -from I1 -to O
#set_disable_timing [get_cells -hierarchical {NCL_GATE_FB2}] -from I2 -to O
#set_disable_timing [get_cells -hierarchical {NCL_GATE_FB3}] -from I3 -to O
#set_disable_timing [get_cells -hierarchical {NCL_GATE_FB4}] -from I4 -to O
#set_disable_timing [get_cells -hierarchical {NCL_GATE_FB5}] -from I5 -to O
#
#set_disable_timing [get_cells -hierarchical {NCL_GATE_MERGED?_FB0}] -from I0 -to O
#
## break timing loop on data/ack path
## set_disable_timing [get_cells -hierarchical {*NCL_REG_DIN*}]
#
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB0}] -filter "REF_PIN_NAME=~I0"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB0}] -filter "REF_PIN_NAME=~O"]
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB1}] -filter "REF_PIN_NAME=~I1"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB1}] -filter "REF_PIN_NAME=~O"]
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB2}] -filter "REF_PIN_NAME=~I2"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB2}] -filter "REF_PIN_NAME=~O"]
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB3}] -filter "REF_PIN_NAME=~I3"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB3}] -filter "REF_PIN_NAME=~O"]
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB4}] -filter "REF_PIN_NAME=~I4"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB4}] -filter "REF_PIN_NAME=~O"]
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB5}] -filter "REF_PIN_NAME=~I5"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB5}] -filter "REF_PIN_NAME=~O"]
#
#set_max_delay 1.2 -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_MERGED?_FB0}] -filter "REF_PIN_NAME=~I0"] -from [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_MERGED?_FB0}] -filter "REF_PIN_NAME=~O"]
#
## organize feedback paths into group
#group_path -name NCL_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB0}] -filter "REF_PIN_NAME=~I0"]
#group_path -name NCL_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB1}] -filter "REF_PIN_NAME=~I1"]
#group_path -name NCL_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB2}] -filter "REF_PIN_NAME=~I2"]
#group_path -name NCL_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB3}] -filter "REF_PIN_NAME=~I3"]
#group_path -name NCL_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB4}] -filter "REF_PIN_NAME=~I4"]
#group_path -name NCL_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_FB5}] -filter "REF_PIN_NAME=~I5"]
#
#group_path -name NCL_MERGED_FEEDBACK -to [get_pins -of_objects [get_cells -hierarchical {NCL_GATE_MERGED?_FB0}] -filter "REF_PIN_NAME=~I0"]
#
## prevent timing-analysis through NCL-logic
#set_false_path -through [get_cells -hierarchical {CLK2NCL_ki}]
#set_false_path -through [get_cells -hierarchical {data_input_markers*.NCL2CLK_in_*}]
#
#create_property -type enum -enum_values {ACK STD} -default_value STD NCL_WIRE_TYPE net
#
#set_property NCL_WIRE_TYPE ACK [get_nets -segments -of [get_pins -of [get_cells -leaf -filter "NCL_WIRE_TYPE == ACK"] -filter "DIRECTION == OUT"]]
