// =============================================================================
// width_coverage_test.sv
// -----------------------------------------------------------------------------
// Directed test that exercises transfer widths (8/16/32), boundary values
// and alignment behaviour. Uses loopback so the test is self-contained.
// =============================================================================

`ifndef WIDTH_COVERAGE_TEST_SV
`define WIDTH_COVERAGE_TEST_SV


class width_coverage_test;

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
                    ref regfile_coverage_col  regfile_coverage);
        bit [31:0] ctrl_word;
        bit [31:0] tx_word;
        bit [31:0] rx_word;
        bit [1:0] widths[3];
        int i;
        int expected;
        $display("[INFO] width_coverage_test: starting");

        widths[0] = 2'b00; // 8
        widths[1] = 2'b01; // 16
        widths[2] = 2'b10; // 32

        // Keep slave BFM in sync; use loopback so MOSI->MISO is returned.
        tb_top.bfm_mode    = 2'b00;
        tb_top.bfm_width   = 2'b00;            // 8-bit
        tb_top.bfm_lsb_first = 1'b0;           // MSB-first
        tb_top.bfm_pattern = 8'h5A;

        // Use a small clock divide for speed
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0002);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN, 32'h0000_0000);
        
        for (i = 0; i < 3; i++) begin
            // Enable master and loopback; other fields changed per-case.
            ctrl_word = 32'h0;
            ctrl_word[0] = 1'b1; // EN
            ctrl_word[1] = 1'b1; // MSTR
            ctrl_word[5] = 1'b1; // LOOPBACK
            ctrl_word[7:6] = widths[i];
            tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);

            //-------------------------------------------------------------------------------
            // TEST 1: test Min vales for each width (0x00, 0x0000, 0x00000000)
            //-------------------------------------------------------------------------------
            tx_word = 32'h0000_0000;//--> min value for all widths
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, widths[i], tx_word);
            run_case(ref_model, regfile_coverage, widths[i], i, tx_word);

            //-------------------------------------------------------------------------------
            // TEST 2: Test LSB and MSB set for each width to check for any alignment issues
            //-------------------------------------------------------------------------------
            tx_word = 32'h0000_0001;
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, widths[i], tx_word);
            run_case(ref_model, regfile_coverage, widths[i], i, tx_word);

            //-------------------------------------------------------------------------------
            // TEST 3: Test max values for each width (0xFF, 0xFFFF, 0xFFFFFFFF)
            //-------------------------------------------------------------------------------
            if(widths[i] == 2'b00)      tx_word = 32'h0000_00FF;//--> max value for 8-bit width 
            else if(widths[i] == 2'b01) tx_word = 32'h0000_FFFF;//--> max value for 16-bit width 
            else                        tx_word = 32'hFFFF_FFFF;//--> max value for 32-bit width 
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, widths[i], tx_word);
            run_case(ref_model, regfile_coverage, widths[i], i, tx_word);

            //-------------------------------------------------------------------------------
            // TEST 4: Test MSB set for each width to check for any alignment issues
            //-------------------------------------------------------------------------------
            if(widths[i] == 2'b00)      tx_word = 32'h0000_0080;//--> MSB Set for 8-bit width 
            else if(widths[i] == 2'b01) tx_word = 32'h0000_8000;//--> MSB Set for 16-bit width 
            else                        tx_word = 32'h8000_0000;//--> MSB Set for 32-bit width 
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, widths[i], tx_word);
            run_case(ref_model, regfile_coverage, widths[i], i, tx_word);

            //-------------------------------------------------------------------------------
            // TEST 5: Test following bit after the MSB set for each width to check for any off-by-one issues
            //-------------------------------------------------------------------------------
            if(widths[i] == 2'b00)      tx_word = 32'h0000_0100;//-->following bit after the MSB for 8-bit width 
            else if(widths[i] == 2'b01) tx_word = 32'h0001_0000;//-->following bit after the MSB for 16-bit width 
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, widths[i], tx_word);
            run_case(ref_model, regfile_coverage, widths[i], i, tx_word);

            //-------------------------------------------------------------------------------
            // TEST 6: Test a random value with alternating bits set to check for any pattern issues
            //-------------------------------------------------------------------------------
            tx_word = 32'hA5A5_A5A5;
            $display("[INFO] Running case %0d: mode=%0d bit_order=%0b width=%0d tx_word=0x%08h", i, 2'b00, 1'b0, widths[i], tx_word);
            run_case(ref_model, regfile_coverage, widths[i], i, tx_word);

        end

        $display("[INFO] width_coverage_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // WIDTH_COVERAGE_TEST_SV
