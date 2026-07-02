###############################################
# TCL script to configure the PPr Demonstrators
# for the test beam of November 2022
# Fernando Carrió Argos
# University of Valencia - CSIC
# 01/11/2022
###############################################
proc init { } {
    catch close_hw_manager
    catch open_hw_manager
    catch {connect_hw_server -url localhost:3121}

}

proc config_ip {nbr} {
    run_state_hw_jtag reset
    run_state_hw_jtag idle
    switch $nbr {
        3 {
            set ip_addr c7a90032
            set mac_addr 020ddba11510
            scan_ir_hw_jtag 12 -tdi 23
            scan_dr_hw_jtag 81 -tdi [concat $ip_addr$mac_addr]
            puts "This is a Long Barrel"
        }
        default {
            puts "Invalid configuration"
        }
    }
}

init
set my_targets [get_hw_targets]
foreach target $my_targets {
    catch {open_hw_target $target -jtag_mode true}
    set nbr [llength [get_hw_devices]]
    config_ip $nbr
    close_hw_target $target
}
catch close_hw_manager
