
// =============================================================================
// delay_transfer_test.sv
// =============================================================================

`ifndef DELAY_TRANSFER_TEST_SV
`define DELAY_TRANSFER_TEST_SV

class delay_transfer_test;

    // ------------------------------------------------------------------
    //  run_case  (two words pre-loaded)
    //   Pushes two TX words so tx_empty=0 when the first transfer
    //   finishes. 
    // ------------------------------------------------------------------
    static task automatic run_case(
            input string       label,
            input bit [7:0]    delay_val,
            input bit [15:0]   clk_div_val,
            output int unsigned gap_pclks,
            ref   spi_ref_model ref_model,
            ref   core_coverage_col coverage);

        bit [31:0]   rd;
        time         t_enter, t_exit;
        bit          entered_s_gap;
        int unsigned expected_pclks;
        int unsigned half_period;

        half_period    = clk_div_val + 1;
        expected_pclks = delay_val * half_period;   // DELAY x (DIV+1) PCLK

        tb_top.u_apb_bfm.apb_write(APB_DELAY, {24'b0, delay_val});

        // push both words BEFORE asserting SS so tx_empty=0 
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00A1); // word 0

        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00B2); // word 1
        ref_model.assert_ss();

        // watch the core state
        entered_s_gap  = 1'b0;
        gap_pclks = 0;
        fork
            begin : watch_gap
            
                @(posedge tb_top.PCLK iff
                    (tb_top.u_wrap.u_dut.u_core.state == 2'd3)); // S_GAP = 2'd3
                t_enter  = $time;
                entered_s_gap = 1'b1;
                @(posedge tb_top.PCLK iff
                    (tb_top.u_wrap.u_dut.u_core.state != 2'd3));
                t_exit    = $time;
                gap_pclks = (t_exit - t_enter) / 10; // 10 ns per PCLK at 100 MHz
            end
            begin : watch_timeout
                repeat (10000) @(posedge tb_top.PCLK);
            end
        join_any
        disable fork;

        ref_model.wait_not_busy_TX_empty(ref_model,"delay_transfer_test");
        ref_model.deassert_ss();

        // verify RX words (loopback = 1)
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        ref_model.check_reg({label, " RX word0"}, 32'h0000_00A1, rd);

        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        ref_model.check_reg({label, " RX word1"}, 32'h0000_00B2, rd);

        // scoreboard: gap presence AND duration
        if (delay_val == 8'h0) begin
            if (entered_s_gap) begin
                $display("[SCOREBOARD_ERROR] %s: S_GAP entered with DELAY=0", label);
                ref_model.error_count++;
            end else
                $display("[INFO] %s: delay=0 S_GAP did not enter", label);
        end else begin

            if (!entered_s_gap) begin
                $display("[SCOREBOARD_ERROR] %s: S_GAP did not enter for DELAY=%0d",
                         label, delay_val);
                ref_model.error_count++;
            end else if (gap_pclks != expected_pclks) begin
                $display("[SCOREBOARD_ERROR] %s: S_GAP duration wrong. delay=%0d div=%0d expected=%0d actual=%0d",
                         label, delay_val, clk_div_val, expected_pclks, gap_pclks);
                ref_model.error_count++;
            end else
                $display("[INFO] %s: delay=%0d div=%0d gap_pclks=%0d expected=%0d",
                         label, delay_val, clk_div_val, gap_pclks, expected_pclks);
        end
        coverage.sample_R21(delay_val);

    endtask

    // ------------------------------------------------------------------
    //   run_case_one_word  (one word only)
    //   Pushes ONE TX word so tx_empty=1 when the transfer finishes.
    //   Even with DELAY>0 the core must go to S_IDLE, not S_GAP.
    // ------------------------------------------------------------------
    static task automatic run_case_one_word(
            input string       label,
            input bit [7:0]    delay_val,
            input bit [15:0]   clk_div_val,
            ref   spi_ref_model ref_model,
            ref   core_coverage_col coverage);

        bit [31:0] rd;
        bit        entered_s_gap;

        tb_top.u_apb_bfm.apb_write(APB_DELAY, {24'b0, delay_val});

        // only ONE word — tx_empty = 1 
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00A1);
        ref_model.assert_ss();

        // watch S_GAP — it must never fire
        entered_s_gap = 1'b0;
        fork
            begin : watch_gap
                @(posedge tb_top.PCLK iff
                    (tb_top.u_wrap.u_dut.u_core.state == 2'd3)); // S_GAP
                entered_s_gap = 1'b1;
            end
            begin : watch_timeout
                repeat (10000) @(posedge tb_top.PCLK);
            end
        join_any
        disable fork;

        ref_model.wait_not_busy_TX_empty(ref_model,"delay_transfer_test");
        ref_model.deassert_ss();

        // verify RX word
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        ref_model.check_reg({label, " RX word0"}, 32'h0000_00A1, rd);

        // S_GAP must NOT have been entered (tx_empty=1)
        if (entered_s_gap) begin
            $display("[SCOREBOARD_ERROR] %s: S_GAP entered with tx_empty=1, delay=%0d",
                     label, delay_val);
            ref_model.error_count++;
        end else
            $display("[INFO] %s: delay=%0d tx_empty=1 S_GAP correctly absent: OK",
                     label, delay_val);
    endtask


    static task run(ref spi_ref_model    ref_model,
                    ref core_coverage_col coverage);
        bit [7:0]    delay_val;
        bit [15:0]   clk_div_val;
        int unsigned gap_pclks;

        $display("[INFO] delay_transfer_test: starting");

        clk_div_val = 16'h0005; // change here to try different dividers

        // 8-bit, MODE=0, loopback, master
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); // EN|MSTR|LOOPBACK
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, clk_div_val);


        // CASE A: DELAY=0, two words queued
        $display("[INFO] delay_transfer_test: ---- CASE A: DELAY=0, two words ----");
        run_case("CASE_A", 8'h00, clk_div_val, gap_pclks, ref_model, coverage);

        // CASE B: DELAY=1, two words queued
        $display("[INFO] delay_transfer_test: ---- CASE B: DELAY=1, two words ----");
        run_case("CASE_B", 8'h01, clk_div_val, gap_pclks, ref_model, coverage);

        // CASE C: DELAY=128, two words queued
        $display("[INFO] delay_transfer_test: ---- CASE C: DELAY=128, two words ----");
        run_case("CASE_C", 8'h80, clk_div_val, gap_pclks, ref_model, coverage);

        // CASE D: DELAY=4, one word only
        $display("[INFO] delay_transfer_test: ---- CASE D: DELAY=4, one word only ----");
        run_case_one_word("CASE_D", 8'h04, clk_div_val, ref_model, coverage);

        // CASE E: DELAY=0, two words queued
        $display("[INFO] delay_transfer_test: ---- CASE E: DELAY cleared back to 0 ----");
        run_case("CASE_E", 8'h00, clk_div_val, gap_pclks, ref_model, coverage);

        // CASE E: DELAY random values, two words queued
        repeat(10)begin 
            delay_val =$urandom_range(1,128);
            $display("[INFO] delay_transfer_test: ---- CASE : %0d DELAY cleared back to 0 ----", delay_val);
            run_case("CASE_E", delay_val, clk_div_val, gap_pclks, ref_model, coverage);
        end
        ref_model.deassert_ss();

        tb_top.u_apb_bfm.apb_write(APB_DELAY, 32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_CTRL,  32'h0000_0000);

        $display("[INFO] delay_transfer_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask

endclass

`endif // DELAY_TRANSFER_TEST_SV