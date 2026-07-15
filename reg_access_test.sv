// =============================================================================
// reg_access_test.sv  
// -----------------------------------------------------------------------------
// First foundational verification step after sanity_test: prove the APB
// register map responds correctly to reset reads and basic write/read access.
// This test keeps the scope intentionally narrow so it can become the anchor
// for later mode, width, FIFO, interrupt, and error-injection tests.
// =============================================================================

`ifndef REG_ACCESS_TEST_SV
`define REG_ACCESS_TEST_SV

class reg_access_test;

    static task automatic check_sample( input string     name, 
                                        input bit [7:0] addr,
                                        input bit [31:0] expected,
                                        input bit [31:0] observed,
                                        ref spi_ref_model ref_model,
                                        ref regfile_coverage_col regfile_coverage);
        ref_model.check_reg(name, expected, observed);
        regfile_coverage.sample_reg_rw(addr, 0, 1);
    endtask

    static task automatic write_read_check_sample(input string name,
                                        input bit [7:0] addr,
                                        input bit [31:0] value,
                                        ref spi_ref_model ref_model,
                                        ref regfile_coverage_col regfile_coverage);
        bit [31:0] observed;
        tb_top.u_apb_bfm.apb_write(addr, value);
        tb_top.u_apb_bfm.apb_read(addr, observed);
        ref_model.check_reg(name, value, observed);
        regfile_coverage.sample_reg_rw(addr, 1, 1);
    endtask

    static task run(ref spi_ref_model ref_model,
                    ref regfile_coverage_col  regfile_coverage);
                    bit [31:0] ctrl_word;
                    bit [31:0] statues_word;
                    bit [31:0] rx_data_word;
                    bit [31:0] tx_data_word;
                    bit [31:0] clk_div_word;
                    bit [31:0] ss_ctrl_word;
                    bit [31:0] int_en_word;
                    bit [31:0] int_stat_word;
                    bit [31:0] delay_word;

        $display("[INFO] reg_access_test: starting");

        // Keep the slave BFM aligned with the DUT mode during the test.
        tb_top.bfm_mode    = 2'b00;            // CPOL=0 CPHA=0
        tb_top.bfm_width   = 2'b00;            // 8-bit
        tb_top.bfm_lsb_first = 1'b0;           // MSB-first
        tb_top.bfm_pattern = 32'h0000_00A5;    // Miso pattern


        /////////////////////////////////////////////////////////////////////////////////////////////////////
        //Test 1 - Write/read checks for each register
        /////////////////////////////////////////////////////////////////////////////////////////////////////

        ctrl_word = 32'h0;
        ctrl_word[0]   = 1'b1;      // EN
        ctrl_word[1]   = 1'b1;      // MSTR
        ctrl_word[3:2] = 2'b01;     // MODE = 1
        ctrl_word[4]   = 1'b1;      // LSB-first
        ctrl_word[5]   = 1'b1;      // LOOPBACK
        ctrl_word[7:6] = 2'b10;     // 32-bit transfers

        write_read_check_sample("CTRL rw",    APB_CTRL,    ctrl_word, ref_model, regfile_coverage);
        write_read_check_sample("CLK_DIV rw",  APB_CLK_DIV, 32'h0000_0123, ref_model, regfile_coverage);
        write_read_check_sample("SS_CTRL rw",  APB_SS_CTRL, 32'h0000_00A5, ref_model, regfile_coverage);
        write_read_check_sample("INT_EN rw",   APB_INT_EN,  32'h0000_001F, ref_model, regfile_coverage);
        write_read_check_sample("DELAY rw",    APB_DELAY,   32'h0000_0011, ref_model, regfile_coverage);

        // INT_STAT is W1C. A direct write/read should leave the cleared value
        // visible unless an event is pending.
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_001F);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat_word);
        check_sample("INT_STAT w1c", APB_INT_STAT, 32'h0000_0000, int_stat_word, ref_model, regfile_coverage);


        /////////////////////////////////////////////////////////////////////////////////////////////////////
        //Test 2 - Check Write only /read only  registers behave as expected. --> TX_DATA is write-only and RX_DATA is read-only. 
        /////////////////////////////////////////////////////////////////////////////////////////////////////

        // Write known values to all registers
        // Mode 0, MSB-first, 8-bit, loopback ON so RX ordering is deterministic.
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023);// EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0002);
        tb_top.u_apb_bfm.apb_write(APB_DELAY,   32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,  32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);// Clear any pending interrupts.

        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00AA);

        // Read from the write-only TX_DATA should return 0 per spec.
        tb_top.u_apb_bfm.apb_read(APB_TX_DATA, tx_data_word);
        check_sample("TX_DATA read is 0 (WO)", APB_TX_DATA, 32'h0000_0000, tx_data_word, ref_model, regfile_coverage);
        
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00AA);
        ref_model.wait_for_complete_transaction(ref_model, "reg_access_test");
        // Writing to the read-only RX_DATA should be ignored;
        tb_top.u_apb_bfm.apb_write(APB_RX_DATA, 32'h0000_00DD);
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rx_data_word);
        check_sample("RX_DATA write ignored (RO)", APB_RX_DATA, 32'h0000_00AA, rx_data_word, ref_model, regfile_coverage);
        regfile_coverage.sample_reg_rw(APB_RX_DATA, 0, 1);// write should not have taken effect
        

        /////////////////////////////////////////////////////////////////////////////////////////////////////
        //Test 3 - Check writing in TX_DATA while EN=0 is igonred and does not affect RX_DATA. 
        /////////////////////////////////////////////////////////////////////////////////////////////////////

        tb_top.PRESETn = 0;
        @(posedge tb_top.PCLK);
        tb_top.PRESETn = 1;

        ctrl_word = 32'h0;
        ctrl_word[0]   = 1'b0;      // EN = 0 -> TX_DATA writes should be ignored
        ctrl_word[1]   = 1'b1;      // MSTR
        ctrl_word[3:2] = 2'b01;     // MODE = 1
        ctrl_word[4]   = 1'b1;      // LSB-first
        ctrl_word[5]   = 1'b1;      // LOOPBACK
        ctrl_word[7:6] = 2'b10;     // 32-bit transfers
        tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);

        // Attempt to write TX_DATA while EN=0. 
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hDEAD_C0DE);
        
        // EN = 1 -> TX_DATA writes should now be accepted
        ctrl_word[0]   = 1'b1;      
        tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);

        // Write to TX_DATA should now be accepted since EN=1.
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hC0DE_C0DE);
        ref_model.wait_for_complete_transaction(ref_model, "reg_access_test");
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rx_data_word);
         
        check_sample("Check RX_DATA value after writing to TX_DATA at EN = 0", APB_RX_DATA, 32'hC0DE_C0DE, rx_data_word, ref_model, regfile_coverage);

        /////////////////////////////////////////////////////////////////////////////////////////////////////
        //Test 4 - Check reset values. 
        /////////////////////////////////////////////////////////////////////////////////////////////////////
        // Write known values to all registers
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'hC0DE_C0DE); 
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'hC0DE_C0DE);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN, 32'hC0DE_C0DE);
        tb_top.u_apb_bfm.apb_write(APB_DELAY, 32'h0000_0001);
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0001);
        //writing in TX_DATA to fill the TX FIFO 
        for (int i = 0; i < 8; i++) begin
            tx_data_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_data_word);
        end
        //Wait for the transaction to make sure the RX FIFO is also filled. 
        ref_model.wait_for_complete_transaction(ref_model, "reg_access_test");
        //writing in TX_DATA again to make sure the TX FIFO still has values.  
        for (int i = 0; i < 8; i++) begin
            tx_data_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_data_word);
        end
        tb_top.PRESETn = 0;
        @(posedge tb_top.PCLK);
        tb_top.PRESETn = 1;
        // Reset-value checks for the readable control/status registers.
        tb_top.u_apb_bfm.apb_read(APB_CTRL, ctrl_word);
        check_sample("CTRL reset",     APB_CTRL,     32'h0000_0000, ctrl_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_STATUS, statues_word);
        check_sample("STATUS reset",   APB_STATUS,   32'h0000_0014, statues_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_TX_DATA, tx_data_word);
        check_sample("TX_DATA reset",  APB_TX_DATA,  32'h0000_0000, tx_data_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rx_data_word);
        check_sample("RX_DATA reset",  APB_RX_DATA,  32'h0000_0000, rx_data_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_CLK_DIV, clk_div_word);
        check_sample("CLK_DIV reset",  APB_CLK_DIV,  32'h0000_0000, clk_div_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_SS_CTRL, ss_ctrl_word);
        check_sample("SS_CTRL reset",  APB_SS_CTRL,  32'h0000_0000, ss_ctrl_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_INT_EN, int_en_word);
        check_sample("INT_EN reset",   APB_INT_EN,   32'h0000_0000, int_en_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat_word);
        check_sample("INT_STAT reset", APB_INT_STAT, 32'h0000_0000, int_stat_word, ref_model, regfile_coverage);
        tb_top.u_apb_bfm.apb_read(APB_DELAY, delay_word);
        check_sample("DELAY reset",    APB_DELAY,    32'h0000_0000, delay_word, ref_model, regfile_coverage);
        regfile_coverage.sample_reset_values(ctrl_word, statues_word, tx_data_word, rx_data_word, clk_div_word, ss_ctrl_word, int_en_word, int_stat_word, delay_word);
        
        $display("[INFO] reg_access_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // REG_ACCESS_TEST_SV