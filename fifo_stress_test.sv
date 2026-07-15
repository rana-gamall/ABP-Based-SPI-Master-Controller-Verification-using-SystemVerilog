// =============================================================================
// fifo_stress_test.sv
// =============================================================================

`ifndef FIFO_STRESS_TEST_SV
`define FIFO_STRESS_TEST_SV

class fifo_stress_test;
    
    static task automatic check_status_bit(input string name,
                                           input bit[31:0]status,
                                           input int unsigned bit_pos,
                                           input bit expected,
                                           ref spi_ref_model ref_model);
        if (status[bit_pos] !== expected) begin
            $display("[SCOREBOARD_ERROR] %s: STATUS[%0d] expected=%0b observed=%0b (STATUS=0x%08h)",
                     name, bit_pos, expected, status[bit_pos], status);
            ref_model.error_count++;
        end else begin
            $display("[INFO] %s: OK (STATUS=0x%08h)", name, status);
        end
    endtask

    static task automatic check_int_bit(input string name,
                                        input bit[31:0]int_stat,    
                                        input int unsigned bit_pos,
                                        input bit expected,
                                        ref spi_ref_model ref_model);
        if (int_stat[bit_pos] !== expected) begin
            $display("[SCOREBOARD_ERROR] %s: INT_STAT[%0d] expected=%0b observed=%0b (INT_STAT=0x%08h)",
                     name, bit_pos, expected, int_stat[bit_pos], int_stat);
            ref_model.error_count++;
        end else begin
            $display("[INFO] %s: OK (INT_STAT=0x%08h)", name, int_stat);
        end
    endtask

    static task run(ref spi_ref_model    ref_model,
                    ref regfile_coverage_col regfile_coverage);
        bit [31:0] rd;
        bit [31:0] tx_word;
        int i;
        bit [31:0] status;
        bit [31:0] int_stat;
        bit [31:0] int_state_before;
        bit [31:0] interrupt_word_before;
        bit [31:0] interrupt_word_after;
        $display("[INFO] fifo_stress_test: starting");

        // Mode 0, MSB-first, 8-bit, loopback ON so RX ordering is deterministic.
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023);// EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0002);
        tb_top.u_apb_bfm.apb_write(APB_DELAY,   32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,  32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);// Clear any pending interrupts.


        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // TEST 1: fill TX FIFO to depth and trigger overflow on the 9th write.
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        for (i = 1; i <= 9; i++) begin
            tx_word = 32'h0000_0000 + i;
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
            tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
            tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);

            if(i < 8) begin
                check_status_bit($sformatf("TEST1 TX_FULL after write %0d", i),status, 1, 1'b0, ref_model);
                check_status_bit($sformatf("TEST1 TX_OVF not latched yet after write %0d in STATUS", i), status, 5, 1'b0, ref_model);
                check_int_bit($sformatf("TEST1 TX_OVF not latched yet after write %0d in INT_STAT", i), int_stat, 2, 1'b0, ref_model);
            end
            else if(i == 8) begin
                check_status_bit("TEST1 TX_FULL after 8th write", status, 1, 1'b1, ref_model);
                check_status_bit("TEST1 TX_OVF not latched yet after 8th write in STATUS", status, 5, 1'b0, ref_model);
                check_int_bit("TEST1 TX_OVF not latched yet after 8th write in INT_STAT", int_stat, 2, 1'b0, ref_model);
            end
            else if(i == 9) begin
                check_status_bit("TEST1 TX_FULL after 9th write", status, 1, 1'b1, ref_model);
                check_status_bit("TEST1 TX_OVF latched after 9th write in STATUS", status, 5, 1'b1, ref_model);
                check_int_bit("TEST1 TX_OVF latched after 9th write in INT_STAT", int_stat, 2, 1'b1, ref_model);
            end

            if(i < 8) begin
                regfile_coverage.sample_fifo_status(i, 0, status[1], status[3]); // Sample coverage for TX FIFO level after each write.
                regfile_coverage.sample_r9_tx_push(1, APB_TX_DATA,status[1], 1); // Sample coverage for R9 TX push after each write.)
            end else if(i == 8) begin
                regfile_coverage.sample_fifo_status(8, 0,status[1], status[3]); // Sample coverage for TX FIFO level at full.
            end
                regfile_coverage.sample_rx_tx_overflow(1, status[1], status[5], 0, status[3], status[6]);

        end
        
        int_state_before = int_stat;
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_0004);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        check_int_bit("TEST1 TX_OVF cleared by W1C",int_stat, 2, 1'b0, ref_model);
        regfile_coverage.sample_R17(1, APB_INT_STAT, 32'h0000_0004, int_state_before, int_stat);

        // Drain the eight queued transfers.
        ref_model.wait_for_complete_transaction(ref_model, "fifo_stress_test");
        for(i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);

        tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
        check_status_bit("TEST1 TX_FULL cleared after drain", status, 1, 1'b0, ref_model);
        check_status_bit("TEST1 TX_EMPTY after draining 8 words", status, 2, 1'b1, ref_model);

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // TEST 2: test that RX_FULL and RX_OVF can be set by overfilling the RX FIFO, and that the interrupt is triggered on unmask.
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

        for (i = 1; i <= 9; i++) begin
            tx_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
            ref_model.wait_for_complete_transaction(ref_model, "fifo_stress_test");
            tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
            tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
            if(i < 8) begin
                check_status_bit($sformatf("TEST2 RX_FULL after write %0d", i), status, 3 , 1'b0, ref_model);
                check_status_bit($sformatf("TEST2 RX_OVF after write %0d", i), status, 6 , 1'b0, ref_model);
                check_int_bit($sformatf("TEST2 RX_FULL after write %0d in INT_STAT", i), int_stat, 1, 1'b0, ref_model);
                check_int_bit($sformatf("TEST2 RX_OVF after write %0d in INT_STAT", i), int_stat, 3, 1'b0, ref_model);
            end
            else if(i == 8) begin
                check_status_bit("TEST2 RX_FULL after 8th write", status, 3 , 1'b1, ref_model);
                check_status_bit("TEST2 RX_OVF not latched yet after 8th write in STATUS", status, 6 , 1'b0, ref_model);
                check_int_bit("TEST2 RX_FULL after 8th write in INT_STAT", int_stat, 1, 1'b1, ref_model);
                check_int_bit("TEST2 RX_OVF not latched yet after 8th write in INT_STAT", int_stat, 3, 1'b0, ref_model);
            end
            else if(i == 9) begin
                check_status_bit("TEST2 RX_FULL after 9th write", status, 3 , 1'b1, ref_model);
                check_status_bit("TEST2 RX_OVF latched after 9th write in STATUS", status, 6 , 1'b1, ref_model);
                check_int_bit("TEST2 RX_FULL after 9th write in INT_STAT", int_stat, 1, 1'b1, ref_model);
                check_int_bit("TEST2 RX_OVF latched after 9th write in INT_STAT", int_stat, 3, 1'b1, ref_model);
            end
            if(i < 8) begin
                regfile_coverage.sample_fifo_status(0,i , status[1], status[3]); // Sample coverage for TX FIFO level after each write.
            end else if(i == 8) begin
                regfile_coverage.sample_fifo_status(0,8 , status[1], status[3]); // Sample coverage for TX FIFO level at full.
            end
                regfile_coverage.sample_rx_tx_overflow(0, status[1], status[5], 1, status[3], status[6]);
        end
        for (i = 1; i <= 9; i++) begin
            tx_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
        end

        //test when ctrl en equal zero, all fifo flags are reset
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0022);// EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
        check_status_bit("after disabling EN, TX_FULL should clear", status, 1, 1'b0, ref_model);
        check_status_bit("after disabling EN, TX_EMPTY should clear", status, 2, 1'b1, ref_model);
        check_status_bit("after disabling EN, RX_FULL should clear", status, 3, 1'b0, ref_model);
        check_status_bit("after disabling EN, RX_EMPTY should clear", status, 4, 1'b1, ref_model);
        check_status_bit("after disabling EN, TX_OVF should not clear, cleared via INT_STAT ", status, 5, 1'b1, ref_model);
        check_status_bit("after disabling EN, RX_OVF should not clear, cleared via INT_STAT ", status, 6, 1'b1, ref_model);
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023);// EN|MSTR|LOOPBACK|8-bit

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

        for (i = 1; i <= 9; i++) begin
            tx_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
            ref_model.wait_for_complete_transaction(ref_model, "fifo_stress_test");
            tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
            tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
            if(i < 8) begin
                check_status_bit($sformatf("TEST2 RX_FULL after write %0d", i), status, 3 , 1'b0, ref_model);
                check_status_bit($sformatf("TEST2 RX_OVF after write %0d", i), status, 6 , 1'b0, ref_model);
                check_int_bit($sformatf("TEST2 RX_FULL after write %0d in INT_STAT", i), int_stat, 1, 1'b0, ref_model);
                check_int_bit($sformatf("TEST2 RX_OVF after write %0d in INT_STAT", i), int_stat, 3, 1'b0, ref_model);
            end
            else if(i == 8) begin
                check_status_bit("TEST2 RX_FULL after 8th write", status, 3 , 1'b1, ref_model);
                check_status_bit("TEST2 RX_OVF not latched yet after 8th write in STATUS", status, 6 , 1'b0, ref_model);
                check_int_bit("TEST2 RX_FULL after 8th write in INT_STAT", int_stat, 1, 1'b1, ref_model);
                check_int_bit("TEST2 RX_OVF not latched yet after 8th write in INT_STAT", int_stat, 3, 1'b0, ref_model);
            end
            else if(i == 9) begin
                check_status_bit("TEST2 RX_FULL after 9th write", status, 3 , 1'b1, ref_model);
                check_status_bit("TEST2 RX_OVF latched after 9th write in STATUS", status, 6 , 1'b1, ref_model);
                check_int_bit("TEST2 RX_FULL after 9th write in INT_STAT", int_stat, 1, 1'b1, ref_model);
                check_int_bit("TEST2 RX_OVF latched after 9th write in INT_STAT", int_stat, 3, 1'b1, ref_model);
            end
            if(i < 8) begin
                regfile_coverage.sample_fifo_status(0,i , status[1], status[3]); // Sample coverage for TX FIFO level after each write.
            end else if(i == 8) begin
                regfile_coverage.sample_fifo_status(0,8 , status[1], status[3]); // Sample coverage for TX FIFO level at full.
            end
                regfile_coverage.sample_rx_tx_overflow(0, status[1], status[5], 1, status[3], status[6]);
        end
        for (i = 1; i <= 9; i++) begin
            tx_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
        end
    
        //test when ctrl en equal zero, all fifo flags are reset
        tb_top.PRESETn = 0;
        @(posedge tb_top.PCLK);
        tb_top.PRESETn = 1;

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, interrupt_word_after);
        tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
        check_status_bit("after disabling EN, BUSY should clear", status, 0, 1'b0, ref_model);
        check_status_bit("after disabling EN, TX_FULL should clear", status, 1, 1'b0, ref_model);
        check_status_bit("after disabling EN, TX_EMPTY should clear", status, 2, 1'b1, ref_model);
        check_status_bit("after disabling EN, RX_FULL should clear", status, 3, 1'b0, ref_model);
        check_status_bit("after disabling EN, RX_EMPTY should clear", status, 4, 1'b1, ref_model);
        check_status_bit("after disabling EN, TX_OVF should clear", status, 5, 1'b0, ref_model);
        check_status_bit("after disabling EN, RX_OVF should clear", status, 6, 1'b0, ref_model);

        check_int_bit("after disabling EN, INT_STAT should be unchanged", interrupt_word_after, 0, 0, ref_model);
        check_int_bit("after disabling EN, INT_STAT should be unchanged", interrupt_word_after, 1, 0, ref_model);
        check_int_bit("after disabling EN, INT_STAT should be unchanged", interrupt_word_after, 2, 0, ref_model);
        check_int_bit("after disabling EN, INT_STAT should be unchanged", interrupt_word_after, 3, 0, ref_model);
        check_int_bit("after disabling EN, INT_STAT should be unchanged", interrupt_word_after, 4, 0, ref_model);


        //test that when we write 0 to the int_stat it will not clear the interrupt 
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); //  EN|MSTR|LOOPBACK|8-bit
        tb_top.u_wrap.u_dut.u_regfile.int_stat = 32'h0000_000A; //force irq to check if it is masked or not
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, interrupt_word_before);

        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_0000);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, interrupt_word_after);

        check_int_bit("after writing zeros, INT_STAT should be unchanged", interrupt_word_after, 0, interrupt_word_before[0], ref_model);
        check_int_bit("after writing zeros, INT_STAT should be unchanged", interrupt_word_after, 1, interrupt_word_before[1], ref_model);
        check_int_bit("after writing zeros, INT_STAT should be unchanged", interrupt_word_after, 2, interrupt_word_before[2], ref_model);
        check_int_bit("after writing zeros, INT_STAT should be unchanged", interrupt_word_after, 3, interrupt_word_before[3], ref_model);
        check_int_bit("after writing zeros, INT_STAT should be unchanged", interrupt_word_after, 4, interrupt_word_before[4], ref_model);

        int_state_before = int_stat;
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_000A);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        check_int_bit("TEST2 RX_OVF cleared by W1C", int_stat, 3, 1'b0, ref_model);
        regfile_coverage.sample_R17(3, APB_INT_STAT, 32'h0000_000A, int_state_before, int_stat);
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // TEST 3: fill the RX FIFO and read back the data, checking that the loopback data matches what was sent.
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023);//  EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
        for (i = 0; i < 8; i++) begin
            tx_word = 32'h0000_0000 + (i + 10);
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_word);
        end

        ref_model.wait_for_complete_transaction(ref_model, "fifo_stress_test");
   
        for (i = 0; i < 8; i++) begin
            tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
            tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
            ref_model.check_reg($sformatf("TEST3 RX word %0d", i),
                                32'h0000_0000 + (i + 10), rd);
            regfile_coverage.sample_r10_rx_pop(1, APB_RX_DATA,status[4], 1); // Sample coverage for R10 RX pop after each read.)
        end


        // Check that an extra read beyond the FIFO depth returns 0 and does not set RX_OVF or change RX_EMPTY status.
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        if(rd !== 32'h0000_0000) begin
            $display("[SCOREBOARD_ERROR] TEST3 extra read beyond FIFO depth expected=0x00000000 observed=0x%08h", rd);
            ref_model.error_count++;
        end else begin
            $display("[INFO] TEST3 extra read beyond FIFO depth returned 0 as expected");
        end
        tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
        check_status_bit("TEST3 RX_EMPTY after popping all 8 words", status, 4, 1'b1, ref_model);
        check_status_bit("TEST3 RX_OVF after popping all 8 words and extra read not set", status, 6, 1'b0, ref_model);
        check_int_bit("TEST3 RX_OVF after popping all 8 words and extra read not set in INT_STAT", int_stat, 3, 1'b0, ref_model);


        ///////////////////////////////////////////////////////////////////////////////////////////////
        // TEST 4: repeat TEST 3 but with a read of the RX_DATA register that samples the ACCESS phase signals to cover the R15 sampling point in the regfile.
        ///////////////////////////////////////////////////////////////////////////////////////////////
        $display("[INFO] cg_r15_test: starting");
 
        // ------------------------------------------------------------------
        // Setup: enable DUT, clear all interrupt status
        // ------------------------------------------------------------------
        tb_top.u_apb_bfm.apb_write(APB_CTRL,     32'h0000_0023); // EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT,  32'hFFFF_FFFF); // clear all sticky
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,    32'h0000_0000); // mask all IRQs
 
        // ------------------------------------------------------------------
        // Drain any residual RX entries (up to depth 8)
        // ------------------------------------------------------------------
        repeat(8) tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);

 
        // ------------------------------------------------------------------
        // APB read of RX_DATA with ACCESS-phase sampling
        //
        // BFM apb_read drives:
        //   posedge N  : PSEL=1, PENABLE=0  (SETUP)
        //   posedge N+1: PSEL=1, PENABLE=1  (ACCESS) ← sample here
        //   posedge N+2: PSEL=0             (release)
        //
        // Thread B polls posedge until it sees the ACCESS condition, then
        // calls sample_cg_r15 with the live signal values at that posedge.
        // ------------------------------------------------------------------
        begin : cg_r15_sample_block
            bit sampled;
            sampled = 0;
 
            fork
                // Thread A: drive the APB read normally
                begin
                    tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
                end
 
                // Thread B: monitor for the ACCESS phase and sample
                begin : monitor
                    repeat(10) begin
                        @(posedge tb_top.PCLK);
                        if (!sampled                          &&
                            tb_top.apb.psel                   &&
                            tb_top.apb.penable                &&
                            !tb_top.apb.pwrite                &&
                            tb_top.apb.paddr == APB_RX_DATA[7:0])
                        begin
                            regfile_coverage.sample_cg_r15(
                                tb_top.apb.psel,
                                tb_top.apb.penable,
                                tb_top.apb.pwrite,
                                tb_top.apb.paddr[7:0],
                                tb_top.u_wrap.u_dut.u_regfile.rx_empty_w,
                                tb_top.apb.prdata,
                                tb_top.u_wrap.u_dut.u_regfile.int_stat[4:0]
                            );
                            sampled = 1;
                            $display("[INFO] cg_r15_test: sampled OK (paddr=0x%02h rx_empty=%0b prdata=0x%08h int_stat[3]=%0b)",
                                tb_top.apb.paddr,
                                tb_top.u_wrap.u_dut.u_regfile.rx_empty_w,
                                tb_top.apb.prdata,
                                tb_top.u_wrap.u_dut.u_regfile.int_stat[3]);
                        end
                    end
                end
            join
 
            if (!sampled) begin
                $display("[SCOREBOARD_ERROR] cg_r15_test: ACCESS phase not detected, coverage not sampled");
                ref_model.error_count++;
            end
        end
 

        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0000);

        $display("[INFO] fifo_stress_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // FIFO_STRESS_TEST_SV