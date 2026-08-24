# VC Formal block run: sample_shift_ntaps_Q
set_fml_appmode FPV
file mkdir formal_blocks/formal_reports

read_file -format sverilog -sva -top sample_shift_ntaps_Q {
  ./shift_30_Q.v
  ./formal_blocks/sva/sample_shift_Q_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_blocks/formal_reports/sample_shift_Q_results.rpt
report_fv       > formal_blocks/formal_reports/sample_shift_Q_summary.rpt

puts ""
puts "Formal done: sample_shift_ntaps_Q"
puts "Reports: formal_blocks/formal_reports/sample_shift_Q_results.rpt"
exit
