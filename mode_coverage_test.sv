// =============================================================================
// mode_coverage_test.sv  
// -----------------------------------------------------------------------------
// Directed coverage test for the four SPI modes, both bit orders, and the
// three supported transfer widths. 
// =============================================================================

`ifndef MODE_COVERAGE_TEST_SV
`define MODE_COVERAGE_TEST_SV

class mode_coverage_test;

    static task automatic run_case(input bit [1:0] mode,
                                   input bit       lsb_first,
                                   input bit [1:0] width,
                                   input bit [31:0] tx_word,
                                   ref spi_ref_model ref_model,
                                   ref core_coverage_col coverage);
        bit [31:0] ctrl_word;
        bit [31:0] rx_word;
        bit [31:0] expected;
        bit [31:0] status;

        ctrl_word = 32'h0;
        ctrl_word[0]   = 1'b1;
        ctrl_word[1]   = 1'b1;
        ctrl_word[3:2] = mode;
        ctrl_word[4]   = lsb_first;
        ctrl_word[5]   = 1'b1;    
        ctrl_word[7:6] = width;

        
        tb_top.bfm_mode    = mode;
        tb_top.bfm_pattern = 8'hA5;
        tb_top.bfm_width   = width;          
        tb_top.bfm_lsb_first = lsb_first;        

        tb_top.u_apb_bfm.apb_write(APB_CTRL,    ctrl_word);
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA,   tx_word);
        
        ref_model.wait_for_complete_transaction(ref_model, "mode_coverage_test");
            
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rx_word);
        expected = tx_word & ref_model.mask_for_width(width);
        ref_model.check_reg($sformatf("mode=%0d lsb=%0b width=%0d", mode, lsb_first, width),
                            expected, rx_word);
        if( (rx_word == tb_top.bfm_pattern) && (rx_word != expected) ) begin
            $display("[SCOREBOARD_ERROR] Loopback failed to override MISO with MOSI for mode=%0d lsb=%0b width=%0d",
            mode, lsb_first, width);
            ref_model.error_count++;
        end
        $display("-----------------------------------------------------------------------------------");
        $display("[tx] tx_word=0x%08h",  tx_word);
        $display("[rx] expected=0x%08h", expected);
        $display("[rx] rx_word=0x%08h",  rx_word);
        $display("-----------------------------------------------------------------------------------");

        coverage.sample_R4_R5(.mode(mode), .sclk(tb_top.spi.sclk), .busy_in(status[0]));
    endtask

    static task run(ref spi_ref_model     ref_model,
                    ref core_coverage_col  coverage);
        int mode;
        int bit_order;
        int width;
        int TEST_NO;
        int iteration_no;
        bit [31:0] tx_word;

        $display("[INFO] mode_coverage_test: starting");
        // Iterate through all combinations of the mode, bit order, and width fields in CTRL.
        iteration_no = 1;
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0001);
        tb_top.u_apb_bfm.apb_write(APB_DELAY,    32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0000);

        repeat (100)begin
        $display("[INFO] mode_coverage_test: ======================================= iterations=%0d =======================================", iteration_no);
            TEST_NO = 1;// The tx_word is just some easily recognizable pseudo-random data for each case.
            for (mode = 0; mode < 4; mode++) begin
                for (bit_order = 0; bit_order < 2; bit_order++) begin
                    for (width = 0; width < 3; width++) begin
                        tx_word = $urandom();
                        $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h",
                                TEST_NO, mode, bit_order, width, tx_word);
                        run_case(mode[1:0], bit_order[0], width[1:0], tx_word,
                                ref_model, coverage);
                        TEST_NO++;
                    end
                end
            end
            iteration_no++;
        end
        $display("[INFO] mode_coverage_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask

endclass

`endif // MODE_COVERAGE_TEST_SV
