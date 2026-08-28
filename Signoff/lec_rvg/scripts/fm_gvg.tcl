# fm_gvg.tcl  -- Gate vs Gate LEC in Formality

# Top module name
set DESIGN_NAME top

# Where to search for Verilog files
set search_path "../datain ."

# -------------------------------------------------------
# 1. Read standard-cell library as Verilog (-lib)
#    You already created the symlink ../datain/tcbn65lplvt.v
# -------------------------------------------------------
read_verilog -container reference      -lib /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/verilog/tcbn65lplvt_200a/tcbn65lplvt.v
read_verilog -container implementation -lib /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/verilog/tcbn65lplvt_200a/tcbn65lplvt.v

# -------------------------------------------------------
# 2. Read GOLDEN netlist (DC)
# -------------------------------------------------------
read_verilog -container reference ../datain/top.v
set_top -reference $DESIGN_NAME

# -------------------------------------------------------
# 3. Read REVISED netlist (post-layout)
# -------------------------------------------------------
read_verilog -container implementation ../datain/top_post_layout.v
set_top -implementation $DESIGN_NAME

# -------------------------------------------------------
# 4. Match and verify
# -------------------------------------------------------
match
verify

# Reports
file mkdir ../logfile
report_verification   -summary  > ../logfile/fm_summary.rpt
report_failing_points -all      > ../logfile/fm_failing_points.rpt

exit
