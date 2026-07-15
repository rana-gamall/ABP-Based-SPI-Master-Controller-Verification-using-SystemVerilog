// =============================================================================
// clk_div_corner_test.sv
// =============================================================================

`ifndef CLK_DIV_CORNER_TEST_SV
`define CLK_DIV_CORNER_TEST_SV

// DIV corner values: 0, 1, small (4), large (1023, 1024)
// half_period = DIV + 1 PCLK cycles
// SCLK period = 2*(DIV+1) PCLK cycles
// 8-bit xfer  = 16*(DIV+1) PCLK cycles
// RX == TX  (The test runs in loopback)
// Drive MOSI on the correct SCLK edge
// Sample MISO on the correct SCLK edge
// Shift in all 8 bits completely before asserting done
// timeout_polls = ((16 * (div_val + 1)) + 1) / 3 + 1;
// SCLK stops early or runs too fast :some bits get missed → RX ≠ TX,,Or BUSY clears too early → RX is garbage

class clk_div_corner_test;

    static task automatic wait_not_busy(
            input  int unsigned  max_polls,
            input  bit [15:0]    div_val, 
            output int unsigned  cycles,
            ref   core_coverage_col core_coverage,
            ref    spi_ref_model ref_model);

        bit [31:0] status;
        cycles=0;
        repeat (max_polls) begin
            tb_top.u_apb_bfm.apb_read(APB_STATUS, status);//17
            cycles++; //cycle 1 count 3,6,9,12,15,6>>>18pclk
            if (status[0] == 1'b0)begin
                $display("[IMP] cycles=%0d", cycles);
                $display("[DEBUG] wait_not_busy: poll %0d/%0d ,stat_0=%0d", cycles, max_polls, status[0]);
                return;
            end   
            core_coverage.sample_sclk_div(.div(div_val), .is_busy(status[0]) );
            @(posedge tb_top.PCLK);
        end
        if(status[0] != 1'b0)begin
            $display("[IMP] cycles=%0d", cycles);
            $display("[SCOREBOARD_ERROR] wait_not_busy: timeout - DUT still BUSY");
            ref_model.error_count++;
        end

    endtask

    static task automatic run_case(
            input  string        label,
            input  bit [15:0]    div_val,
            input  bit [7:0]     tx_byte,
            output int unsigned  unmatched_counter,
            ref   core_coverage_col core_coverage, 
            ref    spi_ref_model ref_model);

        bit [31:0] rd;
        int unsigned timeout_polls;
        int unsigned busy_cycles=0;
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, {16'h0000, div_val});
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, {24'h00_0000, tx_byte});

        ref_model.assert_ss();
        //16400
        // 8-bit transfer = 16*(DIV+1) PCLK cycles
        // each poll ≈ 3 PCLK cycles
        timeout_polls = ((16 * (div_val + 1)) + 1) / 3 + 1; 
        
        wait_not_busy(timeout_polls, div_val, busy_cycles, core_coverage, ref_model);
        if (busy_cycles !=timeout_polls) begin
            $display("[INFO] %s: BUSY cleared after %0d polls (timeout=%0d polls)",
                    label, busy_cycles, timeout_polls);
                    unmatched_counter++;
                    ref_model.error_count++;
        end
        ref_model.deassert_ss();

        // Verify RX (loopback: RX must match TX)
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);

        if (rd[7:0] !== tx_byte) begin
            $display("[SCOREBOARD_ERROR] %s: RX mismatch: expected=0x%02h got=0x%02h",
                     label, tx_byte, rd[7:0]);
            ref_model.error_count++;
        end

    endtask

    static task run(ref spi_ref_model    ref_model,
                    ref core_coverage_col core_coverage);
        int div_val;
        int counter = 0;
        int unmatched_counter = 0;
        $display("[INFO] clk_div_corner_test: starting");

        // One-time config: 8-bit, mode 0, loopback, master, no delay
        tb_top.u_apb_bfm.apb_write(APB_CTRL,  32'h0000_0023);
        tb_top.u_apb_bfm.apb_write(APB_DELAY, 32'h0000_0000);

        // DIV = 0  →  fastest
        $display("[INFO] clk_div_corner_test: ---- DIV = 0 ----");
        run_case("DIV_0", 16'h0000, 8'hA0, unmatched_counter, core_coverage, ref_model);

        // DIV = 1
        $display("[INFO] clk_div_corner_test: ---- DIV = 1 ----");
        run_case("DIV_1", 16'h0001, 8'hB1, unmatched_counter, core_coverage, ref_model);

        // DIV = 2  →  small value
        $display("[INFO] clk_div_corner_test: ---- DIV = 2 ----");
        run_case("DIV_2", 16'h0002, 8'hC2, unmatched_counter, core_coverage, ref_model);

        // DIV = 3  →  small value
        $display("[INFO] clk_div_corner_test: ---- DIV = 3 ----");
        run_case("DIV_3", 16'h0003, 8'hC3, unmatched_counter, core_coverage, ref_model);

        // DIV = 255  →  small value
        $display("[INFO] clk_div_corner_test: ---- DIV = 255 ----");
        run_case("DIV_255", 16'h00FF, 8'hC4,unmatched_counter, core_coverage, ref_model);

        // DIV = 1024  →  large corner
        $display("[INFO] clk_div_corner_test: ---- DIV = 1024 ----");
        run_case("DIV_1024", 16'h0400, 8'hE4, unmatched_counter, core_coverage, ref_model);

        // DIV = 65535  →  
        $display("[INFO] clk_div_corner_test: ---- DIV = 65535  ----");
        run_case("DIV_65535", 16'hFFFF, 8'hF5, unmatched_counter, core_coverage, ref_model);
        
        repeat (50)begin 
            counter++;
            $display("[INFO] clk_div_corner_test: random iteration %0d", counter);
            div_val = $urandom_range(0, 2048);
            $display("[INFO] clk_div_corner_test: ---- DIV = %0d  ----", div_val);
            run_case($sformatf("DIV_%0d", div_val), div_val, 8'hAA, unmatched_counter, core_coverage, ref_model);
        end

        //check busy cycles vs timeout_polls for all cases, report if any mismatches
        if(unmatched_counter != 0) begin
            $display("[SCOREBOARD_ERROR] clk_div_corner_test: unmatched_counter=%0d, some BUSY clear polls did not match expected timeout_polls", unmatched_counter);
            ref_model.error_count++;
        end
        else 
            $display("[INFO] clk_div_corner_test: all BUSY clear polls matched expected timeout_polls, unmatched_counter=%0d", unmatched_counter);
 
        tb_top.u_apb_bfm.apb_write(APB_CTRL,  32'h0000_0000);
 
        $display("[INFO] clk_div_corner_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask
 

endclass

`endif // CLK_DIV_CORNER_TEST_SV