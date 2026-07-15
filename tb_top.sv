// =============================================================================
// tb_top.sv  (SV-only starter scaffold)
// -----------------------------------------------------------------------------
// Plain-SV top-level module. Instantiates the DUT wrapper, the APB master BFM,
// the SPI slave BFM, the scoreboard/coverage collectors, and selects the test
// via +TESTNAME=<name> (or +UVM_TESTNAME=<name> as a fallback so the same
// Makefile works for SV-only and UVM flows).
//
// Contract with the grader:
//   * Every test MUST end with exactly one "[TEST_PASSED] <name>" or
//     "[TEST_FAILED] <name> errors=<n>" line. The stub below satisfies that
//     for the sanity_test example.
// =============================================================================





`timescale 1ns/1ps
`include "env/ref_model.sv"
`include "env/coverage.sv"
`include "env/coverage_spi_core.sv"
`include "env/coverage2_regfile.sv"
`include "sequences/stim_lib.sv"
`include "tests/sanity_test.sv"
`include "tests/reg_access_test.sv"
`include "tests/randomized_reg_access_test.sv"
`include "tests/mode_coverage_test.sv"
`include "tests/randomized_width_coverage_test.sv"
`include "tests/width_coverage_test.sv"
`include "tests/fifo_stress_test.sv"
`include "tests/interrupt_test.sv"
`include "tests/clk_div_corner_test.sv"
`include "tests/loopback_test.sv"
`include "tests/randomized_sanity_test.sv"
`include "tests/error_injection_test.sv"
`include "tests/delay_transfer_test.sv"
`include "tests/ral_hw_reset_test.sv"

module tb_top;

    // ----------------- Clock and reset --------------------------------------
    bit PCLK = 0;
    always #5 PCLK = ~PCLK;   // 100 MHz

    bit PRESETn;

    // ----------------- Interfaces -------------------------------------------
    apb_if apb (.pclk(PCLK), .presetn(PRESETn));
    spi_if spi (.pclk(PCLK));
// Local signals used only by the slave BFM
    logic [1:0]  bfm_mode      = 2'b00;
    logic [1:0]  bfm_width     = 2'b00;
    logic        bfm_lsb_first = 1'b0;
    logic [31:0] bfm_pattern = 32'h0000_00A5;   // default pattern (8-bit A5)

    // ----------------- DUT wrapper -----------------------------------------
    dut_wrapper u_wrap (.apb(apb), .spi(spi));

    // ----------------- BFMs -------------------------------------------------
    apb_master_bfm u_apb_bfm (.apb(apb.master));
    spi_slave_bfm  u_spi_bfm (.spi(spi.slave), .mode(bfm_mode),
                              .width_mode(bfm_width), .lsb_first(bfm_lsb_first),
                              .miso_word(bfm_pattern));

    // ----------------- Predictor / Scoreboard / Coverage --------------------
    spi_ref_model    u_ref   = new();
    spi_coverage_col u_cov   = new();
    core_coverage_col u_cov_core = new();
    regfile_coverage_col u_cov_regfile = new();
    // ----------------- SVA bind ---------------------------------------------
    // Bind by *instance path* relative to tb_top: u_wrap is the dut_wrapper
    // instance, u_dut is the spi_master instance inside it, u_regfile is the
    // apb_regfile instance inside spi_master. The bind injects spi_sva into
    // the u_regfile instance with port hookups read from the same scope.
 bind u_wrap.u_dut.u_regfile spi_sva u_spi_sva (
    .PCLK      (PCLK),
    .PRESETn   (PRESETn),

    .ctrl_en   (u_wrap.u_dut.u_regfile.ctrl_en),
    .int_stat  (u_wrap.u_dut.u_regfile.int_stat),
    .IRQ       (u_wrap.u_dut.u_regfile.IRQ),

    .SS_n      (u_wrap.u_dut.u_regfile.SS_n),
    .ss_en     (u_wrap.u_dut.u_regfile.ss_en),
    .ss_val    (u_wrap.u_dut.u_regfile.ss_val),

    // ===== Added signals =====
    .ctrl_mstr      (u_wrap.u_dut.u_regfile.ctrl_mstr),
    .ctrl_mode      (u_wrap.u_dut.u_regfile.ctrl_mode),
    .ctrl_lsb_first (u_wrap.u_dut.u_regfile.ctrl_lsb_first),
    .ctrl_loopback  (u_wrap.u_dut.u_regfile.ctrl_loopback),
    .ctrl_width     (u_wrap.u_dut.u_regfile.ctrl_width),
    .clk_div        (u_wrap.u_dut.u_regfile.clk_div),
    .delay_cfg      (u_wrap.u_dut.u_regfile.delay_cfg),

    .int_en         (u_wrap.u_dut.u_regfile.int_en),
    .transfer_done_pulse (u_wrap.u_dut.u_regfile.transfer_done_pulse),
    .tx_pop              (u_wrap.u_dut.u_regfile.tx_pop),
    .rx_empty_w     (u_wrap.u_dut.u_regfile.rx_empty_w),
    .rx_full_w      (u_wrap.u_dut.u_regfile.rx_full_w),
    .tx_empty_w     (u_wrap.u_dut.u_regfile.tx_empty_w),
    .tx_empty       (u_wrap.u_dut.u_regfile.tx_empty),
    .tx_full_w      (u_wrap.u_dut.u_regfile.tx_full_w),

    .tx_count       (u_wrap.u_dut.u_regfile.tx_count),
    .rx_count       (u_wrap.u_dut.u_regfile.rx_count),

    .busy_in        (u_wrap.u_dut.u_regfile.busy_in),

    // APB
    .PSLVERR        (u_wrap.u_dut.u_regfile.PSLVERR),
    .PREADY         (u_wrap.u_dut.u_regfile.PREADY),
    .PSEL           (u_wrap.u_dut.u_regfile.PSEL),
    .PENABLE        (u_wrap.u_dut.u_regfile.PENABLE),
    .PWRITE         (u_wrap.u_dut.u_regfile.PWRITE),
    .PADDR          (u_wrap.u_dut.u_regfile.PADDR),
    .PWDATA         (u_wrap.u_dut.u_regfile.PWDATA),
    .PRDATA         (u_wrap.u_dut.u_regfile.PRDATA),

    .apb_access     (u_wrap.u_dut.u_regfile.apb_access),
    .apb_read       (u_wrap.u_dut.u_regfile.apb_read),
    .apb_write      (u_wrap.u_dut.u_regfile.apb_write),

    // FIFO events
    .tx_push_dropped (u_wrap.u_dut.u_regfile.tx_push_dropped),
    .rx_push_valid   (u_wrap.u_dut.u_regfile.rx_push_valid)

   

);

bind u_wrap.u_dut.u_core core_sva u_core_sva (
    .PCLK      (PCLK),
    .PRESETn   (PRESETn),

    // ===== Core signals =====
    .cfg_en    (u_wrap.u_dut.u_core.cfg_en),
    .busy      (u_wrap.u_dut.u_core.busy),
    .SCLK      (u_wrap.u_dut.u_core.SCLK),
    .MOSI      (u_wrap.u_dut.u_core.MOSI),
    .MISO      (u_wrap.u_dut.u_core.MISO),
    .cfg_mstr      (u_wrap.u_dut.u_core.cfg_mstr),
    .cfg_mode  (u_wrap.u_dut.u_core.cfg_mode),
    .cpol      (u_wrap.u_dut.u_core.cpol),
    .cpha      (u_wrap.u_dut.u_core.cpha),

    .state     (u_wrap.u_dut.u_core.state),
    .transfer_done_pulse (u_wrap.u_dut.u_core.transfer_done_pulse),

    .tx_empty  (u_wrap.u_dut.u_core.tx_empty),
    .cfg_delay (u_wrap.u_dut.u_core.cfg_delay),

    .xfer_div  (u_wrap.u_dut.u_core.xfer_div),
    .half_period (u_wrap.u_dut.u_core.half_period),
    .sclk_cnt  (u_wrap.u_dut.u_core.sclk_cnt),
    .sclk_phase (u_wrap.u_dut.u_core.sclk_phase),

    .cfg_lsb_first (u_wrap.u_dut.u_core.cfg_lsb_first),
    .cfg_width     (u_wrap.u_dut.u_core.cfg_width),
    .cfg_clk_div   (u_wrap.u_dut.u_core.cfg_clk_div),

    .xfer_mode      (u_wrap.u_dut.u_core.xfer_mode),
    .xfer_lsb_first (u_wrap.u_dut.u_core.xfer_lsb_first),
    .xfer_width     (u_wrap.u_dut.u_core.xfer_width),

    .gap_cnt    (u_wrap.u_dut.u_core.gap_cnt),

    .ss_n_drive (u_wrap.u_dut.u_core.ss_n_drive),

    .cfg_loopback (u_wrap.u_dut.u_core.cfg_loopback),
    .miso_eff     (u_wrap.u_dut.u_core.miso_eff)
);
    // ----------------- Test dispatch ----------------------------------------
    string testname;

    initial begin
        
        PRESETn = 0;
        #50;
        PRESETn = 1;

        if (!$value$plusargs("TESTNAME=%s", testname) &&
            !$value$plusargs("UVM_TESTNAME=%s", testname))
            testname = "width_coverage_test";
            
        $display("[INFO] Starting test: %s", testname);

        case (testname)
            "sanity_test"             : sanity_test::run(u_ref, u_cov);
            "reg_access_test"         : reg_access_test::run(u_ref, u_cov_regfile);
            "randomized_reg_access_test" : randomized_reg_access_test::run(u_ref, u_cov_regfile);
            "mode_coverage_test"      : mode_coverage_test::run(u_ref, u_cov_core);
            "width_coverage_test"     : width_coverage_test::run(u_ref, u_cov_regfile);
            "randomized_width_coverage_test": randomized_width_coverage_test::run(u_ref,u_cov_core, u_cov_regfile);
            "fifo_stress_test"        : fifo_stress_test::run(u_ref, u_cov_regfile);
            "interrupt_test"          : interrupt_test::run(u_ref, u_cov_regfile);
            "clk_div_corner_test"     : clk_div_corner_test::run(u_ref, u_cov_core);
            "loopback_test"           : loopback_test::run(u_ref, u_cov_core);
            "randomized_sanity_test"  : randomized_sanity_test::run(u_ref, u_cov);
            "error_injection_test"    : error_injection_test::run(u_ref, u_cov_regfile);
            "delay_transfer_test"     : delay_transfer_test::run(u_ref, u_cov_core);
            "ral_hw_reset_test"    : begin
                // SV-only scaffold does not implement the RAL bonus.
                // Emit the TEST_SKIPPED line so the grader can award 0 for
                // the RAL bonus without penalising the rest of the rubric.
                $display("[TEST_SKIPPED] ral_hw_reset_test");
                $finish;
            end
            // TODO: add one case arm per required test you implement.
            // The grader expects every test name listed in
            // harness/grading_interface.md Section 3 to print
            // [TEST_PASSED]/[TEST_FAILED] exactly once. Tests should
            // follow the sanity_test signature (predictor + coverage by
            // ref; BFMs reached via tb_top.u_apb_bfm / tb_top.u_spi_bfm).
            // Example:
            //   "reg_access_test"     : reg_access_test::run(u_ref, u_cov);
            //   "mode_coverage_test"  : mode_coverage_test::run(u_ref, u_cov);
            default : begin
                $display("[TEST_FAILED] %s errors=1  (unknown test name)", testname);
                $finish;
            end
        endcase

        // Single PASS line for the dispatcher. Each test::run task is
        // expected to have printed [SCOREBOARD_ERROR] on mismatches and
        // incremented u_ref.error_count; convert that into the final
        // PASS/FAIL line here.
        if (u_ref.error_count == 0)
            $display("[TEST_PASSED] %s", testname);
        else
            $display("[TEST_FAILED] %s errors=%0d", testname, u_ref.error_count);
        $finish;
    end

    // ----------------- Safety timeout ---------------------------------------
    initial begin
        #20_000_000;  // 20 ms worth of sim time
        $display("[TEST_FAILED] %s errors=1  (timeout)", testname);
        $finish;
    end

endmodule