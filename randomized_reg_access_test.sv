// =============================================================================
// randomized_reg_access_test.sv 
// -----------------------------------------------------------------------------
// Randomized companion to reg_access_test. It keeps the directed register-map
// checks in reg_access_test.sv and adds a separate, seeded random stimulus file
// so APB register accesses can be exercised in a more varied order.
// =============================================================================

`ifndef RANDOMIZED_REG_ACCESS_TEST_SV
`define RANDOMIZED_REG_ACCESS_TEST_SV

class randomized_reg_access_test;
    static task automatic check_sample( input string     name, 
                                        input bit [7:0] addr,
                                        input bit [31:0] expected,
                                        input bit [31:0] observed,
                                        ref spi_ref_model ref_model,
                                        ref regfile_coverage_col regfile_coverage);
        ref_model.check_reg(name, expected, observed);
        regfile_coverage.sample_reg_rw(addr, 0, 1);
    endtask
    static task automatic apply_txn(input apb_reg_read_write_txn t,
                                    ref spi_ref_model ref_model,
                                    ref regfile_coverage_col regfile_coverage);
        bit [31:0] observed;
        bit [31:0] expected_ctrl;
        bit [31:0] expected_ss;
        bit [31:0] expected_status;

        case (t.addr)
            APB_CTRL: begin
                if (t.write_read) begin
                    expected_ctrl = 32'h0;
                    expected_ctrl[0]   = 1'b1;// EN must always be 1 when writing CTRL
                    expected_ctrl[1]   = 1'b1;// MSTR must always be 1 when writing CTRL
                    expected_ctrl[3:2] = t.data[3:2];// MODE
                    expected_ctrl[4]   = t.data[4];// LSB_FIRST
                    expected_ctrl[5]   = t.data[5];// LOOPBACK
                    expected_ctrl[7:6] = t.data[7:6];// WIDTH                    
                    tb_top.u_apb_bfm.apb_write(APB_CTRL, expected_ctrl);
                    tb_top.u_apb_bfm.apb_read(APB_CTRL, observed);
                    ref_model.check_reg("random CTRL", expected_ctrl, observed);
                end else begin
                    tb_top.u_apb_bfm.apb_read(APB_CTRL, observed);
                    ref_model.check_reg("random CTRL", 32'h0000_00AB, observed);
                end
            end

            APB_CLK_DIV: begin
                if(t.write_read) begin
                    tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, {16'h0, t.clk_div});
                    tb_top.u_apb_bfm.apb_read(APB_CLK_DIV, observed);
                    ref_model.check_reg("random CLK_DIV", {16'h0, t.clk_div}, observed);
                end
                else  begin
                    tb_top.u_apb_bfm.apb_read(APB_CLK_DIV, observed);
                    ref_model.check_reg("random CLK_DIV", 32'h0000_00AB, observed);
                end

            end
            APB_SS_CTRL: begin
                if(t.write_read) begin
                    expected_ss = {24'h0, t.ss_val, t.ss_en};
                    // make sure at least one slave is enabled to avoid any transaction errors.
                    if(expected_ss[3:0] == 4'b0000) begin
                        expected_ss[0] = 1; 
                        expected_ss[4] = 0; 
                    end
                    else if(expected_ss[7:4] == 4'b1111) begin
                        expected_ss = 0;
                        expected_ss[0] = 1;
                        expected_ss[4] = 0;
                    end
                    else if(expected_ss[3] && expected_ss[7]||expected_ss[2]&&expected_ss[6]||expected_ss[1]&&expected_ss[5] || expected_ss[0] && expected_ss[4]) begin
                        expected_ss = 0;
                        expected_ss[0] = 1;
                        expected_ss[4] = 0;
                    end
                    
                    tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, expected_ss);
                    tb_top.u_apb_bfm.apb_read(APB_SS_CTRL, observed);
                    ref_model.check_reg("random SS_CTRL", expected_ss, observed);
                end
                else begin
                    tb_top.u_apb_bfm.apb_read(APB_SS_CTRL, observed);
                    ref_model.check_reg("random SS_CTRL", 32'h0000_00AB, observed);
                end
            end
            APB_INT_EN: begin
                if(t.write_read) begin
                    tb_top.u_apb_bfm.apb_write(APB_INT_EN, {27'h0, t.int_en});
                    tb_top.u_apb_bfm.apb_read(APB_INT_EN, observed);
                    ref_model.check_reg("random INT_EN", {27'h0, t.int_en}, observed);
                end
                else begin
                    tb_top.u_apb_bfm.apb_read(APB_INT_EN, observed);
                    ref_model.check_reg("random INT_EN", 32'h0000_000B, observed);
                end

            end

            APB_DELAY: begin
                if(t.write_read) begin
                    tb_top.u_apb_bfm.apb_write(APB_DELAY, {24'h0, t.delay});
                    tb_top.u_apb_bfm.apb_read(APB_DELAY, observed);
                    ref_model.check_reg("random DELAY", {24'h0, t.delay}, observed);
                end
                else begin
                    tb_top.u_apb_bfm.apb_read(APB_DELAY, observed);
                    ref_model.check_reg("random DELAY", 32'h0000_00AB, observed);
                end

            end
            APB_STATUS: begin
                    /////////////////////////////////////////////////////////////////////////////////////////////////
                    // STATUS is read-only and tested in the directed test
                    /////////////////////////////////////////////////////////////////////////////////////////////////
            end
            APB_TX_DATA: begin
                    /////////////////////////////////////////////////////////////////////////////////////////////////
                    // TX_DATA is write-only and tested in the directed test
                    /////////////////////////////////////////////////////////////////////////////////////////////////
            end
            APB_RX_DATA: begin
                    /////////////////////////////////////////////////////////////////////////////////////////////////
                    // RX_DATA is read-only and tested in the directed test
                    /////////////////////////////////////////////////////////////////////////////////////////////////
            end
            APB_INT_STAT: begin
                    /////////////////////////////////////////////////////////////////////////////////////////////////
                    // INT_STAT is read/write with W1C bits and tested in the directed test
                    /////////////////////////////////////////////////////////////////////////////////////////////////
            end
            default: begin
                tb_top.u_apb_bfm.apb_read(APB_STATUS, expected_status);
                if (expected_status !== 32'h0000_0014) begin
                    $display("[SCOREBOARD_ERROR] STATUS changed unexpectedly during randomized reg access: 0x%08h", expected_status);
                    ref_model.error_count++;
                end
            end
        endcase
        // Sample coverage for the register file access type (read vs write) for each register.
        if(t.write_read) begin
            regfile_coverage.sample_reg_rw(t.addr, 1, 0);
        end
        else begin
            regfile_coverage.sample_reg_rw(t.addr, 0, 1);
        end
    endtask

    static task run(ref spi_ref_model     ref_model,
                    ref regfile_coverage_col  regfile_coverage);
        apb_reg_read_write_txn    t;
        int            seed;
        bit [31:0] ctrl_word;
        bit [31:0] statues_word;
        bit [31:0] rx_data_word;
        bit [31:0] tx_data_word;
        bit [31:0] clk_div_word;
        bit [31:0] ss_ctrl_word;
        bit [31:0] int_en_word;
        bit [31:0] int_stat_word;
        bit [31:0] delay_word;
        $display("[INFO] randomized_reg_access_test: starting");

        tb_top.bfm_mode    = 2'b00;            // CPOL=0 CPHA=0
        tb_top.bfm_width   = 2'b00;            // 8-bit
        tb_top.bfm_lsb_first = 1'b0;           // MSB-first
        tb_top.bfm_pattern = 32'h0000_00A5;    // Miso pattern

        t = new();
        if ($value$plusargs("SEED=%d", seed))
            t.srandom(seed);

        // A small seeded burst of random register accesses gives you a nice
        // mix of control, divider, chip-select, interrupt-enable, and delay
        // traffic without depending on SPI transfers.
        repeat(10000)begin
            if (!t.randomize() with {
                    clk_div   inside {[1:32]};
                    delay     inside {[0:31]};
                    int_en    inside {[0:31]};
                }) begin

                $display("[SCOREBOARD_ERROR] randomized_reg_access_test randomization failed");
                ref_model.error_count++;
                return;
            end
            if(!t.write_read)begin
                tb_top.u_apb_bfm.apb_write(t.addr, 32'h0000_00AB); // Set a known pattern on the bus for read transactions to observe.
            end
            
            $display("[INFO] randomized_reg_access_test: %s", t.sprint());
            apply_txn(t, ref_model, regfile_coverage);
        end
        // Explicit W1C smoke check at the end.
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'h0000_001F);
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, t.data);
        if (t.data !== 32'h0000_0000) begin
            $display("[SCOREBOARD_ERROR] INT_STAT W1C did not clear as expected, observed=0x%08h", t.data);
            ref_model.error_count++;
        end
        tb_top.PRESETn = 0;
        @(posedge tb_top.PCLK);
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

        $display("[INFO] randomized_reg_access_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask

endclass

`endif // RANDOMIZED_REG_ACCESS_TEST_SV