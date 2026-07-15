// =============================================================================
// spi_slave_bfm.sv
// -----------------------------------------------------------------------------
// - Supports SPI 4 modes, widths 8/16/32, and MSB/LSB-first.
// =============================================================================

`ifndef SPI_SLAVE_BFM_SV
`define SPI_SLAVE_BFM_SV
`timescale 1ns/1ps

module spi_slave_bfm (
    spi_if.slave  spi,
    input  logic  [1:0]  mode,        // {CPOL, CPHA}
    input  logic  [1:0]  width_mode,   // 00=8b, 01=16b, 10=32b, 11 treated as 32b
    input  logic         lsb_first,   // 1=LSB-first, 0=MSB-first
    input  logic  [31:0] miso_word    // word driven on MISO
);

    logic        sclk_prev;
    logic        ss_active_prev;
 
    logic [1:0]  latched_mode;
    logic [1:0]  latched_width_mode;
    logic        latched_lsb_first;
    logic [31:0] latched_masked_word;
 
    logic [5:0]  bits_driven;
    logic [5:0]  bits_sampled;
 
    wire ss_active = (spi.ss_n != 4'hF);
 
    initial begin
        spi.cb_slave.miso  <= 1'b0;
        sclk_prev          = 1'b0;
        ss_active_prev      = 1'b0;
        latched_mode       = 2'b00;
        latched_width_mode = 2'b00;
        latched_lsb_first  = 1'b0;
        latched_masked_word  = 32'h0;
        bits_driven        = 0;
        bits_sampled       = 0;
    end
    always @(posedge spi.pclk) begin : miso_driver
        logic        cpol;
        logic        cpha;
        logic        is_leading_edge;
        logic        is_trailing_edge;
        logic        is_sample_edge;
        logic        is_launch_edge;
        int unsigned nbits;
        int unsigned bit_index;
        logic [31:0] masked_word;
 
        case (width_mode)
            2'b00:   nbits = 8;
            2'b01:   nbits = 16;
            default: nbits = 32;
        endcase
 
        case (width_mode)
            2'b00:   masked_word = miso_word & 32'h0000_00FF;
            2'b01:   masked_word = miso_word & 32'h0000_FFFF;
            default: masked_word = miso_word;
        endcase
 
        if (!ss_active) begin
            ss_active_prev      <= 1'b0;
            sclk_prev          <= spi.sclk;
            bits_driven        <= 0;
            bits_sampled       <= 0;
            latched_mode       <= mode;
            latched_width_mode <= width_mode;
            latched_lsb_first  <= lsb_first;
            latched_masked_word  <= masked_word;
 
            if (mode[0] == 1'b0) begin
                bit_index = lsb_first ? 0 : (nbits - 1);
                spi.cb_slave.miso <= masked_word[bit_index];
            end else begin
                spi.cb_slave.miso <= 1'b0;
            end
        end
 
        else if (!ss_active_prev) begin
            ss_active_prev      <= 1'b1;
            sclk_prev          <= spi.sclk;
            bits_sampled       <= 0;
            latched_mode       <= mode;
            latched_width_mode <= width_mode;
            latched_lsb_first  <= lsb_first;
            latched_masked_word  <= masked_word;
 
            if (mode[0] == 1'b0) begin
                bit_index = lsb_first ? 0 : (nbits - 1);
                spi.cb_slave.miso <= masked_word[bit_index];
                bits_driven <= 1;
            end else begin
                spi.cb_slave.miso <= 1'b0;
                bits_driven <= 0;
            end
        end
 
        else begin
            case (latched_width_mode)
                2'b00:   nbits = 8;
                2'b01:   nbits = 16;
                default: nbits = 32;
            endcase
 
            cpol = latched_mode[1];
            cpha = latched_mode[0];
 
            is_leading_edge  = (sclk_prev == cpol)  && (spi.sclk == ~cpol);
            is_trailing_edge = (sclk_prev == ~cpol) && (spi.sclk == cpol);
 
            // CPHA=0: sample on leading, launch on trailing. 
            // CPHA=1: sample on trailing, launch on leading.
            if (cpha == 1'b0)
                is_sample_edge = is_leading_edge;
            else
                is_sample_edge = is_trailing_edge;
 
            is_launch_edge = (sclk_prev != spi.sclk) && !is_sample_edge; // Any edge that isn't a sample edge is a launch edge.
 
            if (is_launch_edge && (bits_driven < nbits)) begin
                bit_index = latched_lsb_first ? bits_driven : (nbits - 1 - bits_driven);
                spi.cb_slave.miso <= latched_masked_word[bit_index];
                bits_driven <= bits_driven + 1;
            end
 
            if (is_sample_edge) begin
                if (bits_sampled == (nbits - 1)) begin
                    bits_sampled <= 0;
 
                    if (latched_mode[0] == 1'b0) begin
                        bit_index = latched_lsb_first ? 0 : (nbits - 1);
                        spi.cb_slave.miso <= latched_masked_word[bit_index];
                        bits_driven <= 1;
                    end else begin
                        bits_driven <= 0;
                    end
                end else begin
                    bits_sampled <= bits_sampled + 1;
                end
            end
 
            sclk_prev <= spi.sclk;
        end

    end

endmodule
 
`endif // SPI_SLAVE_BFM_SV