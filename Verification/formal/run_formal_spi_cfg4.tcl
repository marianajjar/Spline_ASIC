# VC Formal block run: spi_cfg4_nomode
set_fml_appmode FPV
file mkdir formal_blocks/formal_reports

read_file -format sverilog -sva -top spi_cfg4_nomode {
  ./spi_cfg4_nomode.v
  ./formal_blocks/sva/spi_cfg4_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_blocks/formal_reports/spi_cfg4_results.rpt
report_fv       > formal_blocks/formal_reports/spi_cfg4_summary.rpt

puts ""
puts "Formal done: spi_cfg4_nomode"
puts "Reports: formal_blocks/formal_reports/spi_cfg4_results.rpt"
exit
