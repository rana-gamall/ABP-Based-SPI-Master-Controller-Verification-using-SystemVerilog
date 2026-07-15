// =============================================================================
// interrupt_test.sv
// =============================================================================

`ifndef INTERRUPT_TEST_SV
`define INTERRUPT_TEST_SV

class interrupt_test;
    static task automatic check_int_bit(input string name,
                                        input bit [31:0] int_stat,
                                        input int unsigned bit_pos,
                                        input bit expected,
                                        ref spi_ref_model ref_model);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        if (int_stat[bit_pos] !== expected) begin
            $display("[SCOREBOARD_ERROR] %s: INT_STAT[%0d] expected=%0b observed=%0b (INT_STAT=0x%08h)",
                     name, bit_pos, expected, int_stat[bit_pos], int_stat);
            ref_model.error_count++;
        end else begin
            $display("[INFO] %s: OK (INT_STAT=0x%08h)", name, int_stat);
        end
    endtask

    static task automatic expect_irq(input bit expected,
                                     input string name,
                                     ref spi_ref_model ref_model);
        @(posedge tb_top.PCLK);
        if (tb_top.u_wrap.u_dut.u_regfile.IRQ !== expected) begin
            $display("[SCOREBOARD_ERROR] interrupt_test %s: IRQ expected=%0b observed=%0b",
                     name, expected, tb_top.u_wrap.u_dut.u_regfile.IRQ);
            ref_model.error_count++;
        end
        else begin
            $display("[INFO] %s: OK (IRQ=%0b)", name, tb_top.u_wrap.u_dut.u_regfile.IRQ);
        end
    endtask

    static task run(ref spi_ref_model    ref_model,
                    ref regfile_coverage_col regfile_coverage);
        bit [31:0] rd;
        int i;
        bit [31:0] int_stat;
        bit [31:0] int_state_before;
        $display("[INFO] interrupt_test: starting");

        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); // EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0002);
        tb_top.u_apb_bfm.apb_write(APB_DELAY,   32'h0000_0000);

        ///////////////////////////////////////////////////////////////////////////////////////////
        // 1) TX_EMPTY + TRANSFER_DONE events with mask/IRQ/W1C checks.
        ///////////////////////////////////////////////////////////////////////////////////////////
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
        
        // Queue one transfer to trigger the events.
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA,  32'h0000_0055);
        ref_model.wait_for_complete_transaction(ref_model, "interrupt_test");
        // Check events are set and IRQ is low when masked.
        check_int_bit("TX_EMPTY set", int_stat, 0, 1'b1, ref_model);
        check_int_bit("TRANSFER_DONE set", int_stat, 4, 1'b1, ref_model);
        expect_irq(1'b0, "masked irq low", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], MASKED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        
        // Unmask and check IRQ goes high.
        tb_top.u_apb_bfm.apb_write(APB_INT_EN, 32'h0000_0011);
        expect_irq(1'b1, "irq high after unmask", ref_model);
        
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], ASSERTED, 5'b10001,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        int_state_before = int_stat;

        // Check events stay stable after disabling with EN=0 (events should not clear until W1C write).
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0022); // EN = 0|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); // EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        if(int_stat != int_state_before) begin
            $display("[SCOREBOARD_ERROR] Events changed after EN=0, expected INT_STAT=0x%08h observed=0x%08h",
                     int_state_before, int_stat);
            ref_model.error_count++;
        end else begin
            $display("[INFO] Events stable after EN=0 (INT_STAT=0x%08h)", int_stat);
        end

        // Clear events with W1C write and check they clear and IRQ goes low.
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_0011);
        check_int_bit("TX_EMPTY W1C", int_stat, 0, 1'b0, ref_model);
        check_int_bit("TRANSFER_DONE W1C", int_stat, 4, 1'b0, ref_model);
        expect_irq(1'b0, "irq low after clear", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], W1C_CLEARED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        regfile_coverage.sample_R17(1, APB_INT_STAT, 32'h0000_0011, int_state_before, int_stat);

        //////////////////////////////////////////////////////////////////////////////
        // 2) TX_OVF event.
        //////////////////////////////////////////////////////////////////////////////
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
        
        // Queue 8 transfers to fill the TX FIFO and make sure TX_OVF is not triggered yet.
        for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_write(APB_TX_DATA, i);
        check_int_bit("TX_OVF not set yet", int_stat, 2, 1'b0, ref_model);

        // Queue one more transfer to trigger TX_OVF.
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hABCD_EF01);
        check_int_bit("TX_OVF set", int_stat, 2, 1'b1, ref_model);
        expect_irq(1'b0, "masked irq low", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], MASKED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);

        // Unmask and check IRQ goes high.
        tb_top.u_apb_bfm.apb_write(APB_INT_EN, 32'h0000_0004);
        expect_irq(1'b1, "irq high on TX_OVF unmask", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], ASSERTED, 5'b00100,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        int_state_before = int_stat;

        // Check events stay stable after disabling with EN=0 (events should not clear until W1C write).
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0022); // EN = 0|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); // EN|MSTR|LOOPBACK|8-bit

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        if(int_stat != int_state_before) begin
            $display("[SCOREBOARD_ERROR] Events changed after EN=0, expected INT_STAT=0x%08h observed=0x%08h",
                     int_state_before, int_stat);
            ref_model.error_count++;
        end else begin
            $display("[INFO] Events stable after EN=0 (INT_STAT=0x%08h)", int_stat);
        end

        // Clear with W1C and check.
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_0004);
        check_int_bit("TX_OVF cleared", int_stat, 2, 1'b0, ref_model);
        expect_irq(1'b0, "irq low after clear", ref_model);

        regfile_coverage.sample_R17(1, APB_INT_STAT, 32'h0000_0004, int_state_before, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], W1C_CLEARED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);

        // Drain the FIFO to clear TX_FULL and make sure no extra events were triggered.
        ref_model.wait_for_complete_transaction(ref_model, "interrupt_test");
        for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        check_int_bit("TX_OVF cleared after drain", int_stat, 2, 1'b0, ref_model);

        /////////////////////////////////////////////////////////////////////////////////////
        // 3) RX_FULL + RX_OVF events.
        /////////////////////////////////////////////////////////////////////////////////////
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
        // Queue 8 transfers to fill the RX FIFO and trigger RX_FULL.
        for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_0080 + i);
        ref_model.wait_for_complete_transaction(ref_model, "interrupt_test");

        // Check RX_FULL is set but RX_OVF is not set yet.
        check_int_bit("RX_FULL set", int_stat, 1, 1'b1, ref_model);
        regfile_coverage.sample_interrupt(int_stat[4:0], MASKED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        check_int_bit("RX_OVF not set yet", int_stat, 3, 1'b0, ref_model);

        // Queue one more transfer to trigger RX_OVF.
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hDEAD_C0DE);
        ref_model.wait_for_complete_transaction(ref_model, "interrupt_test");

        // Check RX_OVF is set but IRQ is still low when masked.
        check_int_bit("RX_OVF set", int_stat, 3, 1'b1, ref_model);
        expect_irq(1'b0, "masked irq low", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], MASKED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        int_state_before = int_stat;

        // Unmask and check IRQ goes high.
        tb_top.u_apb_bfm.apb_write(APB_INT_EN, 32'h0000_000A);
        expect_irq(1'b1, "irq high on RX_FULL/RX_OVF unmask", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], ASSERTED, 5'b01010,tb_top.u_wrap.u_dut.u_regfile.IRQ);

        // Check events stay stable after disabling with EN=0 (events should not clear until W1C write).
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0022); // EN = 0|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); // EN|MSTR|LOOPBACK|8-bit
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        if(int_stat != int_state_before) begin
            $display("[SCOREBOARD_ERROR] Events changed after EN=0, expected INT_STAT=0x%08h observed=0x%08h",
                     int_state_before, int_stat);
            ref_model.error_count++;
        end else begin
            $display("[INFO] Events stable after EN=0 (INT_STAT=0x%08h)", int_stat);
        end

        // Clear with W1C and check.
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_000A);
        check_int_bit("RX_FULL W1C", int_stat, 1, 1'b0, ref_model);
        check_int_bit("RX_OVF W1C", int_stat, 3, 1'b0, ref_model);
        expect_irq(1'b0, "irq low after RX clear", ref_model);

        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        regfile_coverage.sample_interrupt(int_stat[4:0], W1C_CLEARED, 5'b00000,tb_top.u_wrap.u_dut.u_regfile.IRQ);
        regfile_coverage.sample_R17(1, APB_INT_STAT, 32'h0000_000A, int_state_before, int_stat);

        // Drain the FIFO and check no extra events were triggered.
        for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        check_int_bit("RX_FULL cleared after drain", int_stat, 1, 1'b0, ref_model);
        check_int_bit("RX_OVF cleared after drain", int_stat, 3, 1'b0, ref_model);

    // =========================================================================
    // R18 RACE f2 — INT_STAT[3] (RX_OVF) W1C vs rx_push_valid && rx_full_w
    // =========================================================================
    $display("[INFO] interrupt_test: ---- RACE r18_f2: RX_OVF W1C vs rx_push_valid+rx_full ----");

    tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0008);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
    tb_top.u_apb_bfm.apb_write(APB_CLK_DIV,  32'h0000_0002);

    // Fill RX FIFO to exactly 8
    for (i = 0; i < 8; i++) begin
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_0010 + i);
        ref_model.wait_for_complete_transaction(ref_model, "interrupt_test");
    end
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

    // Queue 9th word and start transfer
    tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00FF);
    ref_model.assert_ss();

    begin : race_f2_align
        bit done;
        done = 0;
        repeat(200) begin
            if (!done &&
                tb_top.u_wrap.u_dut.u_core.state      == 2'd2 && // S_FINISH
                tb_top.u_wrap.u_dut.u_core.sclk_cnt   ==
                    (tb_top.u_wrap.u_dut.u_core.half_period - 17'd2))
            begin
                // Next posedge: sclk_cnt==half_period-1 → done_pulse=1
                // Drive SETUP this posedge so ACCESS is the next posedge
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.paddr   <= APB_INT_STAT;
                tb_top.u_apb_bfm.apb.cb_master.pwdata  <= 32'h0000_0008;
                done = 1;
            end else if (done &&
                     tb_top.u_wrap.u_dut.u_core.sclk_cnt ==
                    (tb_top.u_wrap.u_dut.u_core.half_period - 17'd1))
            begin
                // This is the done_pulse cycle — drive ACCESS (PENABLE=1)
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b1;
                @(posedge tb_top.PCLK); // hold for PREADY
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b0;
                break;
            end
            @(posedge tb_top.PCLK);
        end
    end

    tb_top.u_apb_bfm.apb_read(APB_INT_STAT, rd);
    if (rd[3] !== 1'b1) begin
        $display("[SCOREBOARD_ERROR] race_r18_f2: RX_OVF bit cleared despite race");
        ref_model.error_count++;
    end else
        $display("[INFO] race_r18_f2: RX_OVF race OK, bit stayed 1");

    ref_model.wait_not_busy_TX_empty(ref_model, "interrupt_test");
    ref_model.deassert_ss();
    for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

    // =========================================================================
    // R18 RACE f3 — INT_STAT[1] (RX_FULL) W1C vs rx_push_valid && rx_count==7
    // =========================================================================
    $display("[INFO] interrupt_test: ---- RACE r18_f3: RX_FULL W1C vs 8th rx_push ----");

    tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0002);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
    tb_top.u_apb_bfm.apb_write(APB_CLK_DIV,  32'h0000_0002);

    // Fill RX FIFO to exactly 7
    for (i = 0; i < 7; i++) begin
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00A0 + i);
        ref_model.wait_for_complete_transaction(ref_model, "interrupt_test");
    end
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

    tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00A7);
    ref_model.assert_ss();

    begin : race_f3_align
        bit done;
        done = 0;
        repeat(200) begin
            if (!done &&
                tb_top.u_wrap.u_dut.u_core.state    == 2'd2 &&
                tb_top.u_wrap.u_dut.u_core.sclk_cnt ==
                    (tb_top.u_wrap.u_dut.u_core.half_period - 17'd2))
            begin
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.paddr   <= APB_INT_STAT;
                tb_top.u_apb_bfm.apb.cb_master.pwdata  <= 32'h0000_0002;
                done = 1;
            end else if (done &&
                tb_top.u_wrap.u_dut.u_core.sclk_cnt ==
                    (tb_top.u_wrap.u_dut.u_core.half_period - 17'd1))
            begin
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b1;
                @(posedge tb_top.PCLK);
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b0;
                break;
            end
            @(posedge tb_top.PCLK);
        end
    end

    tb_top.u_apb_bfm.apb_read(APB_INT_STAT, rd);
    if (rd[1] !== 1'b1) begin
        $display("[SCOREBOARD_ERROR] race_r18_f3: RX_FULL bit cleared despite race");
        ref_model.error_count++;
    end else
        $display("[INFO] race_r18_f3: RX_FULL race OK, bit stayed 1");

    ref_model.wait_not_busy_TX_empty(ref_model, "interrupt_test");
    ref_model.deassert_ss();
    for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

    // =========================================================================
    // R18 RACE f4 — INT_STAT[0] (TX_EMPTY) W1C vs tx_pop && tx_count==1
    // =========================================================================
    $display("[INFO] interrupt_test: ---- RACE r18_f4: TX_EMPTY W1C vs last tx_pop ---- at time %0t", $time);

    tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0001);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
    tb_top.u_apb_bfm.apb_write(APB_CLK_DIV,  32'h0000_0002);

    // Load exactly ONE word
    tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00FF);
    ref_model.assert_ss();

    begin : race_f4_align

        repeat(50) begin
            if (tb_top.u_wrap.u_dut.u_core.state    == 2'd0 &&   // S_IDLE
                !tb_top.u_wrap.u_dut.u_regfile.tx_empty          &&
                tb_top.u_wrap.u_dut.u_core.ss_n_drive != 4'hF)
            begin
                // Posedge T-2: drive SETUP → RTL sees PSEL=1,PENABLE=0 at T-1
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.paddr   <= APB_INT_STAT;
                tb_top.u_apb_bfm.apb.cb_master.pwdata  <= 32'h0000_0001;
                // Advance to T-1 and drive ACCESS → RTL sees PENABLE=1 at T
               @(posedge tb_top.PCLK);
                
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b1;
                // Advance to T (tx_pop cycle, PREADY=1) and release bus
                @(posedge tb_top.PCLK);
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b0;
                break;
            end
            @(posedge tb_top.PCLK);
        end
    end

    tb_top.u_apb_bfm.apb_read(APB_INT_STAT, rd);
    if (rd[0] !== 1'b1) begin
        $display("[SCOREBOARD_ERROR] race_r18_f4: TX_EMPTY bit cleared despite race");
        ref_model.error_count++;
    end else
        $display("[INFO] race_r18_f4: TX_EMPTY race OK, bit stayed 1");

    ref_model.wait_not_busy_TX_empty(ref_model, "interrupt_test");
    ref_model.deassert_ss();
    tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

    // =========================================================================
    // R18 RACE f5 — INT_STAT[4] (TRANSFER_DONE) W1C vs transfer_done_pulse
    // =========================================================================
    $display("[INFO] interrupt_test: ---- RACE r18_f5: TRANSFER_DONE W1C vs transfer_done_pulse ----");

    tb_top.u_apb_bfm.apb_write(APB_INT_EN,   32'h0000_0010);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
    tb_top.u_apb_bfm.apb_write(APB_CLK_DIV,  32'h0000_0002);

    tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00C3);
    ref_model.assert_ss();

    begin : race_f5_align
        bit done;
        done = 0;
        repeat(200) begin
            if (!done &&
                tb_top.u_wrap.u_dut.u_core.state    == 2'd2 &&
                tb_top.u_wrap.u_dut.u_core.sclk_cnt ==
                    (tb_top.u_wrap.u_dut.u_core.half_period - 17'd2))
            begin
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b1;
                tb_top.u_apb_bfm.apb.cb_master.paddr   <= APB_INT_STAT;
                tb_top.u_apb_bfm.apb.cb_master.pwdata  <= 32'h0000_0010;
                done = 1;
            end else if (done &&
                tb_top.u_wrap.u_dut.u_core.sclk_cnt ==
                    (tb_top.u_wrap.u_dut.u_core.half_period - 17'd1))
            begin
                // done_pulse fires this posedge — drive ACCESS
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b1;
                @(posedge tb_top.PCLK);
                tb_top.u_apb_bfm.apb.cb_master.psel    <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.penable <= 1'b0;
                tb_top.u_apb_bfm.apb.cb_master.pwrite  <= 1'b0;
                break;
            end
            @(posedge tb_top.PCLK);
        end
    end

    tb_top.u_apb_bfm.apb_read(APB_INT_STAT, rd);
    if (rd[4] !== 1'b1) begin
        $display("[SCOREBOARD_ERROR] race_r18_f5: TRANSFER_DONE bit cleared despite race");
        ref_model.error_count++;
    end else
        $display("[INFO] race_r18_f5: TRANSFER_DONE race OK, bit stayed 1");

    ref_model.wait_not_busy_TX_empty(ref_model, "interrupt_test");
    ref_model.deassert_ss();
    tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
    tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);

    /////////////////////////////////////////////////////////////////////////////////////
    // Check irq and int stat are low after the reset 
    /////////////////////////////////////////////////////////////////////////////////////
    tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023); //  EN|MSTR|LOOPBACK|8-bit
    tb_top.u_wrap.u_dut.u_regfile.int_stat = 32'h0000_000A; //force irq to check if it is masked or not
    tb_top.PRESETn = 0;
    @(posedge tb_top.PCLK);
    tb_top.PRESETn = 1;
    tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
    if(int_stat != 32'h0000_0000)begin
        $display("[SCOREBOARD_ERROR] interrupt_test: INT_STAT not cleared after reset, observed=0x%08h", int_stat);
        ref_model.error_count++;
    end else
        $display("[INFO] interrupt_test: INT_STAT cleared after reset");
    expect_irq(1'b0, "irq low after RX clear", ref_model);

    tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0000);
    $display("[INFO] interrupt_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // INTERRUPT_TEST_SV