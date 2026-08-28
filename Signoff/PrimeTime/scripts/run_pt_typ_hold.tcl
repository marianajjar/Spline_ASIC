set corner "125C_typ_15_OCV"
# enable signal integrity ( cross talk ) analysis
set si_enable_analysis true
# define search path for lib/db files
set search_path "/data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lplvt_220a/ /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tpdn65lpnv2od3_200a/"
# define link libraries
set link_path "tcbn65lplvttc.db tcbn65lphvttc.db tcbn65lptc.db tpdn65lpnv2od3tc.db"
# read gate level netlist
read_verilog ../datain/top_post_layout.v
# link design
link -ver > ../logfile/link_hold_${corner}.log
# read SDC
source ../datain/top.sdc > ../report/read_sdc_hold_${corner}.rpt
# run check timing
check_timing -ver > ../report/check_timing_hold_${corner}.rpt
# read extraction file
read_parasitics -format SPEF -verbose ../datain/top_fast.SPEF > ../report/read_parasitics_hold_${corner}.rpt
# define 15% OCV , skip this stage for setup check
set_timing_derate -data -late 1.15
set_timing_derate -clock -late 1.15
set_timing_derate -clock -early 0.85
set_timing_derate -data -early 0.85
# Propagate clocks
set_propagated_clock [get_clock *]
# update timing information
update_timing -full
# generate timing report for hold – min delay
report_timing -delay_type min -max_paths 30 -path full_clock -derate -nosplit > ../report/HOLD_${corner}_TIMING
exit
