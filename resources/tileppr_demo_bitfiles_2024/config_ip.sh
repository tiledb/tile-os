#!/bin/bash

# Save current value
ORIG_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"

# Add Vivado libraries
export LD_LIBRARY_PATH="/tools/Xilinx/Vivado_Lab/2022.2/lib/lnx64.o/SuSE:$LD_LIBRARY_PATH"

source /tools/Xilinx/Vivado_Lab/2022.2/settings64.sh
vivado_lab -mode batch -source TB_ip_configuration.tcl

# --------------------------------------------------
# Restore original value
# --------------------------------------------------
export LD_LIBRARY_PATH="$ORIG_LD_LIBRARY_PATH"



