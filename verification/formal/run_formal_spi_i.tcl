# VC Formal block run: spi_i_master
set_fml_appmode FPV
file mkdir formal_blocks/formal_reports

read_file -format sverilog -sva -top spi_i_master {
  ./spi_i.v
  ./formal_blocks/sva/spi_i_master_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_blocks/formal_reports/spi_i_results.rpt
report_fv       > formal_blocks/formal_reports/spi_i_summary.rpt

puts ""
puts "Formal done: spi_i_master"
puts "Reports: formal_blocks/formal_reports/spi_i_results.rpt"
exit
