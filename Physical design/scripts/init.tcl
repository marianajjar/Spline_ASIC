set init_design_uniquify 1
setDesignMode -process 65
setMultiCpuUsage -local 64

# --- ADDED: latch handling and timing defaults ---
set ::TimeLib::tsgMarkCellLatchConstructFlag 1
set conf_in_tran_delay {120.0ps}
set delaycal_input_transition_delay {120ps}
set defHierChar {/}
set floorplan_default_site {core}

set init_abstract_view abstract
set init_assign_buffer 1
set init_gnd_net VSS
set init_import_mode { -keepEmptyModule 0 -treatUndefinedCellAsBbox 0}
set init_io_file ../datain/top.io
set init_layout_view layout
set init_lef_file {/data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/lef/tcbn65lplvt_200a/lef/tcbn65lplvt_9lmT2.lef /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/lef/tcbn65lphvt_200a/lef/tcbn65lphvt_9lmT2.lef /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/lef/tpdn65lpnv2od3_140b/mt_2/9lm/lef/antenna_9lm.lef /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/lef/tpdn65lpnv2od3_140b/mt_2/9lm/lef/tpdn65lpnv2od3_9lm.lef /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/lef/tcbn65lp_200a/lef/tcbn65lp_9lmT2.lef}
set init_mmmc_file {../datain/MMMC.view}
set init_oa_search_lib {}
set init_original_verilog_files ../datain/top.v
set init_pwr_net VDD
set init_top_cell top
set init_verilog ../datain/top.v
get_message -id GLOBAL-100 -suppress
get_message -id GLOBAL-100 -suppress
set latch_time_borrow_mode max_borrow

init_design
