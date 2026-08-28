set corner "0C_fast_15_OCV"
# enable signal integrity ( cross talk ) analysis
set si_enable_analysis true
# define search path for lib/db files
set search_path "/data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lplvt_220a/ /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tpdn65lpnv2od3_200a/"
# define link libraries
set link_path "tcbn65lplvtbc.db tcbn65lphvtbc.db tcbn65lpbc.db tpdn65lpnv2od3bc.db"
# read gate level netlist
read_verilog ../datain/top_post_layout.v
# link design
link -ver > ../logfile/link_setup_${corner}.log
# read SDC
source ../datain/top.sdc > ../report/read_sdc_setup_${corner}.rpt
# run check timing
check_timing -ver > ../report/check_timing_setup_${corner}.rpt
# read extraction file
read_parasitics -format SPEF -verbose ../datain/top_fast.SPEF > ../report/read_parasitics_setup_${corner}.rpt
# Propagate clocks
set_propagated_clock [get_clock *]
# update timing information
update_timing -full
# generate timing report for hold – min delay
report_timing -delay_type max -max_paths 30 -path full_clock -derate -nosplit > ../report/SETUP_${corner}_TIMING
exit
