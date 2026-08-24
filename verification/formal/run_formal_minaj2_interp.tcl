# VC Formal block run: minaj2_interp_3samp_internalSlope
set_fml_appmode FPV
file mkdir formal_blocks/formal_reports

read_file -format sverilog -sva -top minaj2_interp_3samp_internalSlope {
  ./spline.v
  ./formal_blocks/sva/minaj2_interp_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_blocks/formal_reports/minaj2_interp_results.rpt
report_fv       > formal_blocks/formal_reports/minaj2_interp_summary.rpt

puts ""
puts "Formal done: minaj2_interp_3samp_internalSlope"
puts "Reports: formal_blocks/formal_reports/minaj2_interp_results.rpt"
exit
