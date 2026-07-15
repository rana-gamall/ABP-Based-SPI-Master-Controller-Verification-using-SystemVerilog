vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.tb_top -cover +TESTNAME=reg_access_test +SEED=1

add wave *
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_core/PCLK \
sim:/tb_top/u_wrap/u_dut/u_core/cfg_mode \
sim:/tb_top/u_wrap/u_dut/u_core/cfg_lsb_first \
sim:/tb_top/u_wrap/u_dut/u_core/cfg_loopback \
sim:/tb_top/u_wrap/u_dut/u_core/cfg_width \
sim:/tb_top/u_wrap/u_dut/u_core/SCLK \
sim:/tb_top/u_wrap/u_dut/u_core/MOSI \
sim:/tb_top/u_wrap/u_dut/u_core/MISO
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/PCLK \
sim:/tb_top/u_wrap/u_dut/u_regfile/cfg_en \
sim:/tb_top/u_wrap/u_dut/u_regfile/cfg_mstr \
sim:/tb_top/u_wrap/u_dut/u_regfile/cfg_mode \
sim:/tb_top/u_wrap/u_dut/u_regfile/cfg_lsb_first \
sim:/tb_top/u_wrap/u_dut/u_regfile/cfg_loopback \
sim:/tb_top/u_wrap/u_dut/u_regfile/cfg_width \
sim:/tb_top/u_wrap/u_dut/u_regfile/ctrl_en \
sim:/tb_top/u_wrap/u_dut/u_regfile/ctrl_mstr \
sim:/tb_top/u_wrap/u_dut/u_regfile/ctrl_mode \
sim:/tb_top/u_wrap/u_dut/u_regfile/ctrl_lsb_first \
sim:/tb_top/u_wrap/u_dut/u_regfile/ctrl_loopback \
sim:/tb_top/u_wrap/u_dut/u_regfile/ctrl_width
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_core/rx_push_data
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_core/busy
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/PWDATA \
sim:/tb_top/u_wrap/u_dut/u_regfile/PRDATA
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_word \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_push_data
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/busy_in
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_push_data
coverage save tb_top.ucdb -onexit
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_mem
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_mem
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/SS_n
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_wp \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_rp \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_count \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_full_w \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_empty_w
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_wp \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_rp \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_count \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_full_w \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_empty_w
add wave -position insertpoint  \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_empty \
sim:/tb_top/u_wrap/u_dut/u_regfile/tx_pop \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_push_valid \
sim:/tb_top/u_wrap/u_dut/u_regfile/rx_push_data \
sim:/tb_top/u_wrap/u_dut/u_regfile/busy_in \
sim:/tb_top/u_wrap/u_dut/u_regfile/transfer_done_pulse \
sim:/tb_top/u_wrap/u_dut/u_regfile/int_stat
add wave /tb_top/u_wrap/u_dut/u_core/u_core_sva/R3_2_1
add wave /tb_top/u_wrap/u_dut/u_core/u_core_sva/extra_ss_n
add wave -position insertpoint  \
sim:/tb_top/apb/presetn \
sim:/tb_top/apb/psel \
sim:/tb_top/apb/penable \
sim:/tb_top/apb/pwrite \
sim:/tb_top/apb/paddr \
sim:/tb_top/apb/pwdata \
sim:/tb_top/apb/prdata \
sim:/tb_top/apb/pready
add wave /tb_top/u_wrap/u_dut/u_core/u_core_sva/extra_ss_n

run -all


#sanity_test.sv
#reg_access_test.sv
#randomized_reg_access_test.sv
#mode_coverage_test.sv
#width_coverage_test.sv
#randomized_sanity_test.sv
#ral_hw_reset_test.sv
#fifo_stress_test.sv
#interrupt_test.sv
#clk_div_corner_test.sv
#loopback_test.sv
#error_injection_test.sv
#delay_transfer_test.sv