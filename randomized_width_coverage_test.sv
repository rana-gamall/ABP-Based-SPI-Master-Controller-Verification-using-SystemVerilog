// =============================================================================
// width_coverage_test.sv
// -----------------------------------------------------------------------------
// Directed test that exercises transfer widths (8/16/32), boundary values
// and alignment behaviour. Uses loopback so the test is self-contained.
// =============================================================================

`ifndef RANDOMIZED_WIDTH_COVERAGE_TEST_SV
`define RANDOMIZED_WIDTH_COVERAGE_TEST_SV


class randomized_width_coverage_test;

    static task automatic run_case(ref spi_ref_model     ref_model,
                  ref regfile_coverage_col  regfile_coverage,
                  input bit [1:0]                 width,
                  int                       i,
                  bit [31:0]                tx_word);
        bit [31:0] rx_word;
        int expected;
        $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, width, tx_word);

        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
        ref_model.wait_for_complete_transaction(ref_model,"width_coverage_test");
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rx_word);

        expected = tx_word & ref_model.mask_for_width(width);
        ref_model.check_reg($sformatf("width_%0d all_zero", width==2'b00 ? 8:(width==2'b01 ? 16:32)),
                           expected, rx_word);

        ref_model.display_info(tx_word, expected, rx_word);
    endtask

    static task run(ref spi_ref_model     ref_model,
                    ref core_coverage_col  core_coverage,
                    ref regfile_coverage_col  regfile_coverage);
        bit [31:0] ctrl_word;
        bit [31:0] tx_word;
        bit [31:0] rx_word;
        bit [31:0] int_stat_word;

        bit [1:0] widths[3];
        int i;
        int expected;
        bit expected_tx_first_index;
        bit expected_rx_first_index;
        apb_width_txn t;
        int seed;
        int Test_no = 0;

        $display("[INFO] randomized_width_coverage_test: starting");

        t=new();

        if ($value$plusargs("SEED=%d", seed))
        t.srandom(seed);
        // Enable master and loopback; other fields changed per-case.
        repeat(1000)begin
            Test_no++;
            if (!t.randomize() with {
                    width     inside{[0:2]};
                    clk_div   inside {[1:32]};
                    delay     inside {[0:31]};
                    int_en    inside {[0:31]};
                }) begin

                $display("[SCOREBOARD_ERROR] randomized_reg_access_test randomization failed");
                ref_model.error_count++;
                return;
            end
            tb_top.bfm_mode        = t.mode;
            tb_top.bfm_pattern     = 32'hDEAD_DEAD;
            tb_top.bfm_width       = t.width;
            tb_top.bfm_lsb_first   = t.lsb_first;

            ctrl_word      = 32'h0;
            ctrl_word[0]   = 1'b1; // EN
            ctrl_word[1]   = 1'b1; // MSTR
            ctrl_word[3:2] = t.mode;
            ctrl_word[4]   = t.lsb_first; //lsb_first
            ctrl_word[5]   = 1; // LOOPBACK
            ctrl_word[7:6] = t.width;
            tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);
            tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, {16'h0, t.clk_div});
            tb_top.u_apb_bfm.apb_write(APB_INT_EN, {27'h0, t.int_en});

            tx_word = t.data;
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", Test_no, t.mode, t.lsb_first, t.width, tx_word);
            run_case(ref_model, regfile_coverage, t.width, Test_no, tx_word);

            case (t.width)
                2'b00: expected_tx_first_index = t.lsb_first ? tx_word[0] : tx_word[7];
                2'b01: expected_tx_first_index = t.lsb_first ? tx_word[0] : tx_word[15];
                2'b10: expected_tx_first_index = t.lsb_first ? tx_word[0] : tx_word[31];
                default: expected_tx_first_index = 0;
            endcase
            case (t.width)
                2'b00: expected_rx_first_index = t.lsb_first ? tx_word[0] : tx_word[7];
                2'b01: expected_rx_first_index = t.lsb_first ? tx_word[0] : tx_word[15];
                2'b10: expected_rx_first_index = t.lsb_first ? tx_word[0] : tx_word[31];
                default: expected_rx_first_index = 0;
            endcase

            //Sample Coverage
            regfile_coverage.sample_bit_order(t.lsb_first,t.width,tx_word,rx_word,expected_tx_first_index,expected_rx_first_index);
            tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat_word);
            core_coverage.sample_R7(t.width, int_stat_word[4]);//INT_STAT layout: [0] RX_FULL, [1] RX_EMPTY, [2] TX_FULL, [3] TX_EMPTY, [4] TRANSFER_DONE
        end

        $display("[INFO] randomized_width_coverage_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // WIDTH_COVERAGE_TEST_SV
