# VC Formal block run: word_history3
set_fml_appmode FPV
file mkdir formal_blocks/formal_reports

read_file -format sverilog -sva -top word_history3 {
  ./spi_register.v
  ./formal_blocks/sva/word_history3_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_blocks/formal_reports/word_history3_results.rpt
report_fv       > formal_blocks/formal_reports/word_history3_summary.rpt

puts ""
puts "Formal done: word_history3"
puts "Reports: formal_blocks/formal_reports/word_history3_results.rpt"
exit
