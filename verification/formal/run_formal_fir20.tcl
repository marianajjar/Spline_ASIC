# VC Formal block run: fir20_q16_fromx
# Uses harness to force real chip params: WL=16, FL=12, NTAPS=10.
set_fml_appmode FPV
file mkdir formal_reports

read_file -format sverilog -sva -top fir20_formal_harness {
  ./filter4tweny.v
  ./formal_blocks/harness/fir20_formal_harness.sv
  ./formal_blocks/sva/fir20_formal.sv
}

create_clock clk -period 100
create_reset reset -sense high
sim_run -stable
sim_save_reset

check_fv -block

report_fv -list > formal_reports/fir20_results.rpt
report_fv       > formal_reports/fir20_summary.rpt

puts ""
puts "Formal done: fir20_q16_fromx via fir20_formal_harness"
puts "Reports: formal_reports/fir20_results.rpt"

exit
