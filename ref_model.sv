// =============================================================================
// ref_model.sv 
// =============================================================================

`ifndef SPI_REF_MODEL_SV
`define SPI_REF_MODEL_SV

class spi_ref_model;

    // Running error count. tb_top reads this to emit the final
    // [TEST_PASSED]/[TEST_FAILED] line.
    int error_count = 0;

    // Minimal predictor state. Only the pieces the sanity_test exercises
    // are modelled; students should fill in the rest.
    bit [7:0]  pred_rx_byte;
    bit [7:0]  pred_tx_byte;
    bit [31:0] pred_tx;
    bit [31:0] pred_rx;

    function new();
        error_count  = 0;
        pred_rx_byte = 8'h0;
        pred_tx_byte = 8'h0;
        pred_tx = 32'h0;
        pred_rx = 32'h0;
    endfunction

    // Predict the result of a loopback OR of an externally-fed MISO byte.
    // For the scaffold we simply echo the byte we expect the slave BFM to
    // return. Real submissions should model the full SPI pipeline.
    task predict_single_byte(input bit [7:0] tx_byte,
                             input bit [7:0] miso_pattern,
                             input bit       loopback);
        pred_tx_byte = tx_byte;
        pred_rx_byte = loopback ? tx_byte : miso_pattern;
    endtask

    task check_rx(input bit [31:0] observed);
        bit [7:0] obs = observed[7:0];
        if (obs !== pred_rx_byte) begin
            $display("[SCOREBOARD_ERROR] RX byte mismatch: predicted=0x%02h observed=0x%02h",
                     pred_rx_byte, obs);
            error_count++;
        end
    endtask

    // Predict the result of a loopback OR of an externally-fed MISO pattern for a whole transaction.
    task predict_whole_transaction(input bit [31:0] tx,
                             input bit [31:0] miso_pattern,
                             input bit       loopback);
        pred_tx = tx;
        pred_rx = loopback ? tx : miso_pattern;
    endtask

    // Check the whole observed RX word against the prediction.
    task check_rx_whole_transaction(input bit [31:0] observed);
        bit [31:0] obs = observed[31:0];
        if (obs !== pred_rx) begin
            $display("[SCOREBOARD_ERROR] RX mismatch: predicted=0x%08h observed=0x%08h",
                     pred_rx, obs);
            error_count++;
        end
    endtask
    
    // Check an observed register value against an expected value, and increment the error count if they mismatch.
    task check_reg(input string name,
                   input bit [31:0] expected,
                   input bit [31:0] observed);
        if (observed !== expected) begin
            $display("[SCOREBOARD_ERROR] %s mismatch: expected=0x%08h observed=0x%08h",
                     name, expected, observed);
            error_count++;
        end
    endtask

    // Wait for the BUSY bit to clear and the TX FIFO to be empty, with a timeout. Increment the error count on timeout.
    static task automatic wait_not_busy_TX_empty(ref spi_ref_model ref_model, input string name);
        bit [31:0] status;
        repeat (6000) begin
            tb_top.u_apb_bfm.apb_read(APB_STATUS, status);
            if (status[0] == 1'b0 && status[2] == 1'b1) return;
        end
        $display("[SCOREBOARD_ERROR] %s: timeout waiting for BUSY clear", name);
        ref_model.error_count++;
    endtask

    // Assert and deassert the slave select.
    static task automatic assert_ss();
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
    endtask
    static task automatic deassert_ss();
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0000);
    endtask
    // Wait for a transaction to complete, defined as BUSY clear and TX FIFO empty, with the slave select asserted.
    static task automatic wait_for_complete_transaction (ref spi_ref_model ref_model, input string name);
            assert_ss();
            wait_not_busy_TX_empty(ref_model, name);
            deassert_ss();
    endtask
    
    //Choose porper mask for the width of the transaction.
    static function automatic bit [31:0] mask_for_width(input bit [1:0] width);
        case (width)
            2'b00: mask_for_width = 32'h0000_00FF;
            2'b01: mask_for_width = 32'h0000_FFFF;
            2'b10: mask_for_width = 32'hFFFF_FFFF;
            default: mask_for_width = 32'hFFFF_FFFF; // illegal width should be caught by constraints, but just in case...
        endcase
    endfunction

    // Display the details of a transaction, including the transmitted word, the expected received word, and the observed received word.
    static task automatic display_info(input bit [31:0] tx_word, input bit [31:0] expected, input bit [31:0] rx_word);
        $display("-----------------------------------------------------------------------------------");
        $display("[tx] tx_word=0x%08h",  tx_word);
        $display("[rx] expected=0x%08h", expected);
        $display("[rx] rx_word=0x%08h",  rx_word);
        $display("-----------------------------------------------------------------------------------");
    endtask
endclass

`endif // SPI_REF_MODEL_SV
