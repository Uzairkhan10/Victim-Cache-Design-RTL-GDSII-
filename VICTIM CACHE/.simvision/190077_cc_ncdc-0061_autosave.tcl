
# XM-Sim Command File
# TOOL:	xmsim(64)	23.09-s006
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
set vcd_compact_mode 0
set vhdl_forgen_loopindex_enum_pos 0
set tcl_sigval_prefix {#}
alias . run
alias indago verisium
alias quit exit
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_victim_cache.clk tb_victim_cache.evict_ack tb_victim_cache.evict_dirty tb_victim_cache.evict_line tb_victim_cache.evict_tag tb_victim_cache.evict_valid tb_victim_cache.mem_delay tb_victim_cache.mem_req tb_victim_cache.mem_req_tag tb_victim_cache.mem_req_wdata tb_victim_cache.mem_req_write tb_victim_cache.mem_resp_valid tb_victim_cache.probe_hit tb_victim_cache.probe_line tb_victim_cache.probe_ready tb_victim_cache.probe_tag tb_victim_cache.probe_valid tb_victim_cache.rst_n tb_victim_cache.DUT.capture_victim tb_victim_cache.DUT.clk tb_victim_cache.DUT.data_read_data tb_victim_cache.DUT.data_read_en tb_victim_cache.DUT.data_read_way tb_victim_cache.DUT.data_write_data tb_victim_cache.DUT.data_write_en tb_victim_cache.DUT.data_write_way tb_victim_cache.DUT.evict_ack tb_victim_cache.DUT.evict_dirty tb_victim_cache.DUT.evict_dirty_r tb_victim_cache.DUT.evict_line tb_victim_cache.DUT.evict_line_r tb_victim_cache.DUT.evict_pending tb_victim_cache.DUT.evict_tag tb_victim_cache.DUT.evict_tag_r tb_victim_cache.DUT.evict_valid tb_victim_cache.DUT.mem_req tb_victim_cache.DUT.mem_req_tag tb_victim_cache.DUT.mem_req_wdata tb_victim_cache.DUT.mem_req_write tb_victim_cache.DUT.mem_resp_valid tb_victim_cache.DUT.next_state tb_victim_cache.DUT.probe_hit tb_victim_cache.DUT.probe_hit_reg tb_victim_cache.DUT.probe_line tb_victim_cache.DUT.probe_line_reg tb_victim_cache.DUT.probe_ready tb_victim_cache.DUT.probe_ready_reg tb_victim_cache.DUT.probe_tag tb_victim_cache.DUT.probe_valid tb_victim_cache.DUT.repl_ptr tb_victim_cache.DUT.repl_ptr_advance tb_victim_cache.DUT.rst_n tb_victim_cache.DUT.state tb_victim_cache.DUT.tag_dirty_in tb_victim_cache.DUT.tag_dirty_read tb_victim_cache.DUT.tag_hit tb_victim_cache.DUT.tag_hit_way tb_victim_cache.DUT.tag_in tb_victim_cache.DUT.tag_invalidate_en tb_victim_cache.DUT.tag_read_data tb_victim_cache.DUT.tag_read_en tb_victim_cache.DUT.tag_read_way tb_victim_cache.DUT.tag_valid_read tb_victim_cache.DUT.tag_way_index tb_victim_cache.DUT.tag_write_en tb_victim_cache.DUT.victim_data_r tb_victim_cache.DUT.victim_tag_r

simvision -input /home/cc/Downloads/PROJECT/rtl/.simvision/190077_cc_ncdc-0061_autosave.tcl.svcf
