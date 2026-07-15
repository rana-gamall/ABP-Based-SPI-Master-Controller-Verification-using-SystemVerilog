// =============================================================================
// randomized_sanity_test.sv 
// =============================================================================

`ifndef RANDOMIZED_SANITY_TEST_SV
`define RANDOMIZED_SANITY_TEST_SV

class randomized_sanity_test;



    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage);

        spi_txn   t;
        bit [31:0] ctrl_word;
        bit [31:0] rd;
        int        seed;

        $display("[INFO] randomized_sanity_test: starting");

        // Step 1 - instantiate the transaction
        t = new();

        // Optional: re-seed 
        if ($value$plusargs("SEED=%d", seed))
        t.srandom(seed);

        // Step 2 - randomize with inline constraints. 
        repeat(1000)begin
            if (!t.randomize() with {
                    clk_div   inside {[1:32]};
                }) begin
                $display("[SCOREBOARD_ERROR] spi_txn randomization failed");
                ref_model.error_count++;
                return;
            end

            // Step 3 - print the randomised transaction. 
            $display("[INFO] randomized_sanity_test: %s", t.sprint());

            // Keep the slave BFM's inputs in sync with the (pinned) random mode.
            tb_top.bfm_mode    = t.mode;
            tb_top.bfm_pattern = 32'hDEAD_C0DE;  
            tb_top.bfm_lsb_first = t.lsb_first;
            tb_top.bfm_width = t.width;
            // Step 4 - drive the randomised fields through the APB BFM. CTRL
            // bit layout (from the spec / Register Map):
            //   [0] EN, [1] MSTR, [3:2] MODE, [4] LSB_FIRST, [5] LOOPBACK,
            //   [7:6] WIDTH (00=8b, 01=16b, 10=32b)
            ctrl_word = 32'h0;
            ctrl_word[0]   = 1'b1;          // EN
            ctrl_word[1]   = 1'b1;          // MSTR
            ctrl_word[3:2] = t.mode;
            ctrl_word[4]   = t.lsb_first;
            ctrl_word[5]   = t.loopback;
            ctrl_word[7:6] = t.width;

            tb_top.u_apb_bfm.apb_write(8'h00, ctrl_word);                 // CTRL
            tb_top.u_apb_bfm.apb_write(8'h10, {16'h0, t.clk_div});        // CLK_DIV
            tb_top.u_apb_bfm.apb_write(8'h20, {24'h0, t.delay_cfg});      // DELAY
            tb_top.u_apb_bfm.apb_write(8'h18, 32'h0000_000F);             // INT_EN // enable all interrupts for coverage visibility

            // Step 5 - tell the predictor what to expect BEFORE pushing TX.
            ref_model.predict_whole_transaction(.tx(t.tx_data & ref_model.mask_for_width(t.width)),
                                        .miso_pattern(tb_top.bfm_pattern & ref_model.mask_for_width(t.width)),
                                        .loopback(t.loopback));

            // Step 6 - sample functional coverage with the same fields we just
            // drove.
            coverage.sample_config(.mode(t.mode),
                                .lsb_first(t.lsb_first),
                                .width(t.width),
                                .loopback(t.loopback));

            // Step 7 - push TX and assert SS lane 0.
            // SS_CTRL layout (see Register Map): [3:0]=ss_en, [7:4]=ss_val.
            // SS_n[i] = ~ss_en[i] | ss_val[i], so to assert lane 0 LOW we need
            // ss_en[0]=1 AND ss_val[0]=0  ->  SS_CTRL=0x01.
            tb_top.u_apb_bfm.apb_write(8'h08, t.tx_data & ref_model.mask_for_width(t.width));                 // TX_DATA
            ref_model.assert_ss();
            // Step 8 - busy-poll STATUS.BUSY until the transfer drains.
            ref_model.wait_not_busy_TX_empty(ref_model, "randomized_sanity_test");

            // Step 9 - read RX_DATA and let the scoreboard check it.
            tb_top.u_apb_bfm.apb_read(8'h0C, rd);                         // RX_DATA
            ref_model.check_rx_whole_transaction(rd);
            // Cleanup: deassert SS so the next test starts from a clean state.
            ref_model.deassert_ss();
        end


        $display("[INFO] randomized_sanity_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask

endclass

`endif // RANDOMIZED_SANITY_TEST_SV
