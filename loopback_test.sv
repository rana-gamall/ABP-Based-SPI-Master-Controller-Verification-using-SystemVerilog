// =============================================================================
// loopback_test.sv
// =============================================================================

`ifndef LOOPBACK_TEST_SV
`define LOOPBACK_TEST_SV

class loopback_test;

    static task automatic run_case(ref spi_ref_model     ref_model,
                  ref core_coverage_col  regfile_coverage,
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

    static task run(ref spi_ref_model    ref_model,
                    ref core_coverage_col coverage);
        int mode;
        int bit_order;
        int width;
        bit [31:0] ctrl_word;
        bit [31:0] tx_word;
        bit [31:0] rx_word;
        bit [31:0] expected;
        int TEST_no = 0;
        $display("[INFO] loopback_test: starting");

        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0001);
        tb_top.u_apb_bfm.apb_write(APB_DELAY,   32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,  32'h0000_0000);
        repeat (100) begin
            for (mode = 0; mode < 4; mode++) begin
                for (bit_order = 0; bit_order < 2; bit_order++) begin
                    for (width = 0; width < 3; width++) begin
                        TEST_no++;
                        ctrl_word = 32'h0;
                        ctrl_word[0]   = 1'b1;            // EN
                        ctrl_word[1]   = 1'b1;            // MSTR
                        ctrl_word[3:2] = mode[1:0];
                        ctrl_word[4]   = bit_order[0];
                        ctrl_word[5]   = 1'b1;            // LOOPBACK ON
                        ctrl_word[7:6] = width[1:0];
                        tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);

                        tb_top.bfm_mode    = mode[1:0];
                        tb_top.bfm_pattern = 32'hDEAD_DEAD;
                        tb_top.bfm_width   = width[1:0];        
                        tb_top.bfm_lsb_first = bit_order[0];         

                        tx_word = $urandom;
                        
                        run_case(ref_model, coverage, width, TEST_no, tx_word);

                        if(expected !== rx_word && rx_word == tb_top.bfm_pattern ) begin
                            $display("[SCOREBOARD_ERROR] loopback_test: mode=%0d bit_order=%0d width=%0d tx=0x%08h rx=0x%08h expected=0x%08h Miso pattern=0x%02h",
                                     mode, bit_order, width, tx_word, rx_word, expected, tb_top.bfm_pattern);
                        end else begin
                        $display("[INFO] loopback_test passed: mode=%0d bit_order=%0d width=%0d tx=0x%08h rx=0x%08h expected=0x%08h Miso pattern=0x%02h",
                                 mode, bit_order, width, tx_word, rx_word, expected, tb_top.bfm_pattern);
                        end
                        coverage.sample_R19(ctrl_word[5],width,tb_top.u_spi_bfm.spi.cb_slave.mosi,tb_top.u_spi_bfm.spi.cb_slave.miso,tb_top.u_wrap.u_dut.u_core.miso_eff,rx_word);
                    end
                end
            end
        end

        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0000);

        $display("[INFO] loopback_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // LOOPBACK_TEST_SV
