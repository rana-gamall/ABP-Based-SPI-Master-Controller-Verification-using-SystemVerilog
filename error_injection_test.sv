
// =============================================================================
// error_injection_test.sv
// =============================================================================

`ifndef ERROR_INJECTION_TEST_SV
`define ERROR_INJECTION_TEST_SV

class error_injection_test;

    // ha check status
    static task automatic check_status_bit(
            input string       name,
            input int unsigned bit_pos,
            input bit          expected_val,
            ref   spi_ref_model ref_model,
            ref   regfile_coverage_col coverage);
        bit [31:0] status;
        tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
        if (status[bit_pos] !== expected_val) begin
            $display("[SCOREBOARD_ERROR] %s: STATUS[%0d] expected=%0b observed=%0b  (STATUS=0x%08h)",
                     name, bit_pos, expected_val, status[bit_pos], status);
            ref_model.error_count++;
        end else
            $display("[INFO] %s: OK  (STATUS=0x%08h)", name, status);
    endtask

    // Check int stat.
    static task automatic check_int_stat_bit(
            input string       name,
            input int unsigned bit_pos,
            input bit          expected_val,
            ref   spi_ref_model ref_model,
            ref   regfile_coverage_col coverage);
        bit [31:0] int_stat;
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, int_stat);
        if (int_stat[bit_pos] !== expected_val) begin
            $display("[SCOREBOARD_ERROR] %s: INT_STAT[%0d] expected=%0b observed=%0b  (INT_STAT=0x%08h)",
                     name, bit_pos, expected_val, int_stat[bit_pos], int_stat);
            ref_model.error_count++;
        end else
            $display("[INFO] %s: OK  (INT_STAT=0x%08h)", name, int_stat);
        coverage.sample_cg_r15(tb_top.u_apb_bfm.apb.cb_master.psel,
                               tb_top.u_apb_bfm.apb.cb_master.penable, 
                               tb_top.u_apb_bfm.apb.cb_master.pwrite,
                               tb_top.u_apb_bfm.apb.cb_master.paddr,
                               tb_top.u_wrap.u_dut.u_regfile.rx_empty_w,
                               tb_top.u_apb_bfm.apb.cb_master.prdata,int_stat);
    endtask

    static task run(ref spi_ref_model    ref_model,
                    ref regfile_coverage_col coverage);
        int i;
        int j;
        int k;

        bit [31:0] rd;
        bit [31:0] ctrl_word;
        bit [7:0] bad_addrs [6];

        bit [31:0] tx_data;
        bit [31:0] rx_data;

        bit [7:0] rand_addr;
        
        tb_top.bfm_mode    = 2'b00;   // CPOL=0 CPHA=0
        tb_top.bfm_lsb_first = 1'b0; // MSB-first
        tb_top.bfm_width = 2'b00;    // 8-bit
        tb_top.bfm_pattern = 8'hA5;
        
        $display("[INFO] error_injection_test: starting");

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // SECTION 1 - TX write when FIFO full
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        $display("[INFO] error_injection_test: ---- SECTION 1: TX write when full ----");

        // Enable: EN | MSTR | MODE=0 | 8-bit | no loopback
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0003); // EN, MSTR ,8bits
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0004);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF); // clear 

        // Fill FIFO  (FIFO_DEPTH = 8)   
        for (i = 0; i < 8; i++) tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0 + i);
        
        // STATUS[1] = TX_FULL must be set
        check_status_bit("S1 TX_FULL after 8 pushes", 1, 1'b1, ref_model, coverage);

        // 9th write -> overflow
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h1234_5678);

        // Verify overflow flags
        check_status_bit  ("S1 STATUS  TX_OVF (bit 5) set", 5, 1'b1, ref_model, coverage);
        check_int_stat_bit("S1 INT_STAT TX_OVF (bit 2) set", 2, 1'b1, ref_model, coverage);

        // W1C clear INT_STAT[2]
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_0004);
        check_int_stat_bit("S1 INT_STAT TX_OVF cleared by W1C", 2, 1'b0, ref_model, coverage); //int_stat[2]=0

        // Wait until TX empty
        ref_model.wait_for_complete_transaction(ref_model, "error_injection_test");

        // TX_FULL must clear after drain
        check_status_bit("S1 TX_FULL cleared after drain", 1, 1'b0, ref_model, coverage);

        //Clear all interrupts before next section
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF); // clear 

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // SECTION 2 - RX read when FIFO empty
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        $display("[INFO] error_injection_test: ---- SECTION 2: RX read when empty ----");

            for (j = 0; j < 8; j++) begin
                tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
                if (rd[4] == 1'b1) break; // RX_EMPTY set -> done
                tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd); //else : RX FIFO pop 
            end
        

        check_status_bit("S2 RX_EMPTY set before empty read", 4, 1'b1, ref_model, coverage);

        // The empty read
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);

        if (rd !== 32'h0000_0000) begin
            $display("[SCOREBOARD_ERROR] S2 RX empty-read returned 0x%08h, expected 0x00000000", rd);
            ref_model.error_count++;
        end else
            $display("[INFO] S2 RX empty-read returned 0x00000000: OK");

        check_int_stat_bit("S2 INT_STAT RX_OVF NOT set after empty read", 3, 1'b0, ref_model, coverage);
        check_status_bit  ("S2 RX_EMPTY still asserted after empty read",  4, 1'b1, ref_model, coverage);

        //Clear all interrupts before next section
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);//clear state

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // SECTION 3 - Illegal width encoding (CTRL[7:6] = 2'b11)
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        $display("[INFO] error_injection_test: ---- SECTION 3: illegal width encoding 2'b11 ----");

        // Program CTRL: EN | MSTR | MODE=0 | LOOPBACK | WIDTH=2'b11 (illegal)
        ctrl_word      = 32'h0;
        ctrl_word[0]   = 1'b1;   // EN
        ctrl_word[1]   = 1'b1;   // MSTR
        ctrl_word[3:2] = 2'b00;  // MODE 0
        ctrl_word[4]   = 1'b0;   // MSB-first
        ctrl_word[5]   = 1'b1;   // LOOPBACK
        ctrl_word[7:6] = 2'b11;  // ILLEGAL / reserved
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    ctrl_word);

        // CTRL must store 2'b11 without masking "apb"
        tb_top.u_apb_bfm.apb_read(APB_CTRL, rd);

        // Run a loopback transfer with the illegal width    
        tx_data = 32'hC0DE_C0DE;
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_data);
        ref_model.wait_for_complete_transaction(ref_model, "error_injection_test");
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rx_data); //reading 11>>>10 "32bits"
       
        // DUT default -> 32-bit; loopback -> RX must equal full TX word
        ref_model.check_reg("S3 illegal-width loopback: RX == full 32-bit TX word", tx_data, rx_data);
      

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // SECTION 4 - Reserved APB offset access (read0--write ignored)
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        $display("[INFO] error_injection_test: ---- SECTION 4: reserved APB offsets ----");

        // Write known values to two registers we can check after the bad writes
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0003); // EN | MSTR
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0005);

       //Directed Values 
        bad_addrs[0] = 8'h24;
        bad_addrs[1] = 8'h28;
        bad_addrs[2] = 8'h3C;
        bad_addrs[3] = 8'h40;
        bad_addrs[4] = 8'h80;
        bad_addrs[5] = 8'hFF;

        for (k = 0; k < 6; k++) begin
            tb_top.u_apb_bfm.apb_write(bad_addrs[k], 32'hDEAD_C0DE);
            tb_top.u_apb_bfm.apb_read (bad_addrs[k], rd);
            if (rd !== 32'h0000_0000) begin
                $display("[SCOREBOARD_ERROR] S4 reserved addr 0x%02h read=0x%08h, expected 0x00000000",
                         bad_addrs[k], rd);
                ref_model.error_count++;
            end else
                $display("[INFO] S4 reserved addr 0x%02h -> 0x00000000: OK", bad_addrs[k]);
        end
        //Random Values
        repeat(100)begin
                rand_addr = $urandom_range(8'h24, 8'hFF);
                tb_top.u_apb_bfm.apb_write(rand_addr, 32'hDEAD_C0DE);
                tb_top.u_apb_bfm.apb_read (rand_addr, rd);
                if (rd !== 32'h0000_0000) begin
                    $display("[SCOREBOARD_ERROR] S4 reserved addr 0x%02h read=0x%08h, expected 0x00000000",
                            rand_addr, rd);
                    ref_model.error_count++;
                end else
                    $display("[INFO] S4 reserved addr 0x%02h -> 0x00000000: OK", rand_addr);
        end
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0000); // disable DUT
    
        $display("[INFO] error_injection_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask

endclass

`endif // ERROR_INJECTION_TEST_SV
