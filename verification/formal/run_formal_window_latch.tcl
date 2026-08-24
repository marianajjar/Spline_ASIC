# VC Formal block run: minaj2_window_latch
set_fml_appmode FPV
file mkdir formal_blocks/formal_reports

read_file -format sverilog -sva -top minaj2_window_latch {
  ./minaj2_window_latch.v
  ./formal_blocks/sva/window_latch_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_blocks/formal_reports/window_latch_results.rpt
report_fv       > formal_blocks/formal_reports/window_latch_summary.rpt

puts ""
puts "Formal done: minaj2_window_latch"
puts "Reports: formal_blocks/formal_reports/window_latch_results.rpt"
exit
