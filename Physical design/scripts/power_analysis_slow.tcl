# Power analysis - slow corner
#set your period
set period "1.04167"
# Slow Corner
# Static Analysis
#set you own top_slow.SPEF file
spefIn ../dataout/eco/top_slow.SPEF -rc_corner SlowRC
set_power_analysis_mode -reset
set_power_analysis_mode -method static -corner rc_slow -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true
set_power_output_dir -reset
set_power_output_dir ./power_signoff
set_default_switching_activity -reset
#update to your parameters
set_default_switching_activity -input_activity 0.2 -period $period -seq_activity 0.2
read_activity_file -reset
set_power -reset
set_dynamic_power_simulation -reset
report_power -rail_analysis_format VS -outfile ./power_signoff/slowRC/top.rpt

