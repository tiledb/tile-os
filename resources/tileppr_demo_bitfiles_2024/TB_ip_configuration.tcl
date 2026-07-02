###############################################
# TCL script to configure the PPr Demonstrators
# for the test beam of November 2022
# Fernando Carrió Argos
# University of Valencia - CSIC
# 01/11/2022
###############################################

#set my_hw_target "localhost:3121/xilinx_tcf/Digilent/210249B070BB" 
set my_hw_target "localhost:3121/xilinx_tcf/Digilent/210249B06D58"
set my_device "xc7vx415t"
proc init { } {
    catch close_hw_manager
    catch open_hw_manager
#    catch {close_hw_server}
#    catch {connect_hw_server -url localhost:3121}
    catch {connect_hw_server -url localhost:3121}
}

proc config_ip { } {
    run_state_hw_jtag reset
    run_state_hw_jtag idle
    #c7a90032 xc0 = 192, xa8 = 168         
    set ip_addr c0a80003
#    set ip_addr c0a80002
    set mac_addr 020ddba11512
#    set mac_addr 020ddba11511

    scan_ir_hw_jtag 12 -tdi 23
    scan_dr_hw_jtag 81 -tdi [concat $ip_addr$mac_addr]
    puts "Configured!"
}

init
set my_targets [get_hw_targets]
puts "$my_targets"
foreach target $my_targets {
    if { $target == $my_hw_target } {
            puts "My target found: $my_hw_target!!!"
	    catch {open_hw_target $target -jtag_mode true}
	    set my_hw_devices [get_hw_devices]
	    puts "HW devices: $my_hw_devices"
	    foreach device $my_hw_devices {
	        if {[string first $my_device $device] != -1} {
	        puts "My target found: $my_device!!!"
	    
                config_ip 
                close_hw_target $target
                }
	    }
    }
}
#catch close_hw_manager
