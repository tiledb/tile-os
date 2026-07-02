###############################################
# TCL script to configure the PPr Demonstrators
# Fernando Carrió Argos
# Modified by Eduardo Valdes to:
#   1. Program Spartan-6
#   2. Program Virtex-7
#   3. Configure IP/MAC through JTAG
###############################################

set my_hw_target "localhost:3121/xilinx_tcf/Digilent/210249B070BB"
#set my_hw_target "localhost:3121/xilinx_tcf/Digilent/210249B06D58"

set my_sp_device "xc6slx16"
set my_ku_device "xc7vx415t"

set spartan_bitfile "picogbtx_LPMODE_OFF.bit"
set ku_bitfile "top18062024_GTH.bit"

proc init {} {
    catch {close_hw_manager}
    catch {open_hw_manager}
    catch {connect_hw_server -url localhost:3121}
}

proc find_device_by_prefix {prefix} {

    foreach dev [get_hw_devices] {
        if {[string match "${prefix}_*" $dev]} {
            return $dev
        }
    }

    error "No device found matching prefix: $prefix"
}

proc program_devices {spartan_bitfile ku_bitfile} {

    global my_sp_device
    global my_ku_device

    set sp_dev [find_device_by_prefix $my_sp_device]
    set ku_dev [find_device_by_prefix $my_ku_device]

    puts "Found Spartan-6 device: $sp_dev"
    puts "Found Virtex-7 device: $ku_dev"

    puts "Programming Spartan-6..."

    set_property PROBES.FILE {} [get_hw_devices $sp_dev]
    set_property FULL_PROBES.FILE {} [get_hw_devices $sp_dev]
    set_property PROGRAM.FILE $spartan_bitfile [get_hw_devices $sp_dev]

    program_hw_devices [get_hw_devices $sp_dev]

    refresh_hw_device [lindex [get_hw_devices $sp_dev] 0]

    puts "Programming Virtex-7..."

    set_property PROBES.FILE {} [get_hw_devices $ku_dev]
    set_property FULL_PROBES.FILE {} [get_hw_devices $ku_dev]
    set_property PROGRAM.FILE $ku_bitfile [get_hw_devices $ku_dev]

    program_hw_devices [get_hw_devices $ku_dev]

    refresh_hw_device [lindex [get_hw_devices $ku_dev] 0]

    puts "Programming completed."
}
proc config_ip {} {

    puts "Configuring IP/MAC..."

    run_state_hw_jtag reset
    run_state_hw_jtag idle

    # 192.168.0.2
    set ip_addr c0a80002

    # MAC address
    set mac_addr 020ddba11511

    scan_ir_hw_jtag 12 -tdi 23
    scan_dr_hw_jtag 81 -tdi [concat $ip_addr$mac_addr]

    puts "Configured!"
}

init

set my_targets [get_hw_targets]

puts "Available targets:"
puts "$my_targets"

foreach target $my_targets {

    if {$target == $my_hw_target} {

        puts "Found target: $target"

        #################################################
        # STEP 1: PROGRAM DEVICES
        #################################################

        open_hw_target $target

        set my_hw_devices [get_hw_devices]
        puts "HW devices: $my_hw_devices"

        program_devices $spartan_bitfile $ku_bitfile

        close_hw_target $target

        #################################################
        # STEP 2: CONFIGURE IP THROUGH JTAG
        #################################################

        open_hw_target $target -jtag_mode true

        config_ip

        close_hw_target $target

        puts "Done."
    }
}

#catch {close_hw_manager}

