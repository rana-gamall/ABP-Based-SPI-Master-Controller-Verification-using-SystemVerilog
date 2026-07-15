// SPI Core Coverage 
// It covers R4, R5, R7, R8, R19, R21, and R24.

`ifndef CORE_COVERAGE_COL_SV
`define CORE_COVERAGE_COL_SV

typedef enum logic [1:0] {
    ASSERTED    = 2'd0,
    W1C_CLEARED = 2'd1,
    MASKED      = 2'd2
} int_event_e;

typedef enum logic [1:0] {
    S_IDLE   = 2'd0,
    S_SHIFT  = 2'd1,
    S_FINISH = 2'd2,
    S_GAP    = 2'd3
} xfer_state_e;

class core_coverage_col;

    // R4, R5
    bit [1:0] cfg_mode;
    bit       SCLK;
    bit       busy;
    bit       is_sample_edge;
    bit       is_launch_edge;

    // R7
    bit [1:0] width_cfg;
    bit       transfer_done_pulse;

    // R8, R24
    bit [15:0] div_value;
    real sclk_ratio;

    // R19
    bit        cfg_loopback;
    bit        MOSI;
    bit        MISO;
    bit        miso_eff;
    bit [31:0] rx_push_data;

    // R21
    bit [7:0]  cfg_delay;
    bit        tx_empty;
    xfer_state_e state;


/////////////////////////////////////////////////////////////////////////////////
    covergroup cg_spi_mode; // R4, R5
        option.per_instance = 1;

        mode_idle: coverpoint {cfg_mode, SCLK} iff (!busy) {
            bins mode0_idle = {{2'b00, 1'b0}};
            bins mode1_idle = {{2'b01, 1'b0}};
            bins mode2_idle = {{2'b10, 1'b1}};
            bins mode3_idle = {{2'b11, 1'b1}};
        }

    endgroup
//---------------------------------------
    task sample_R4_R5( // R4, R5 
        input bit [1:0] mode,
        input bit       sclk,
        input bit       busy_in
    );
        cfg_mode       = mode;
        SCLK           = sclk;
        busy           = busy_in;
        cg_spi_mode.sample();
    endtask

/////////////////////////////////////////////////////////////////////////////////
    covergroup cg_R7; // R7
        option.per_instance = 1;

        width_at_done: coverpoint width_cfg iff (transfer_done_pulse) {
            bins width_8  = {2'b00};
            bins width_16 = {2'b01};
            bins width_32 = {2'b10};
        }

        done_seen: coverpoint transfer_done_pulse {
            bins done = {1};
        }
    endgroup
//---------------------------------------
    task sample_R7( // R7
        input bit [1:0] width,
        input bit       done_pulse
    );
        width_cfg             = width;
        transfer_done_pulse   = done_pulse;
        cg_R7.sample();
    endtask

/////////////////////////////////////////////////////////////////////////////////
    covergroup cg_sclk_div ; // R8, R24
        option.per_instance = 1;

        cp_div_value: coverpoint div_value iff(busy) {
            bins div_0     = {0};
            bins div_1     = {1};
            bins div_2     = {2};
            bins div_3     = {3};
            bins div_255   = {255};
            bins div_1024  = {1024};
            bins div_max   = {16'hFFFF};
            bins div_rand  = {[4:254], [256:1023], [1025:65534]};
        }
    endgroup
//---------------------------------------
    task sample_sclk_div( // R8, R24
        input [15:0] div,
        input bit    is_busy
    );
        div_value = div;
        busy = is_busy;

        cg_sclk_div.sample();
    endtask

/////////////////////////////////////////////////////////////////////////////////
    covergroup cg_R19; // R19
        option.per_instance = 1;
        cp_loopback: coverpoint cfg_loopback {
            bins on = {1};
        }

        cp_width: coverpoint width_cfg iff (cfg_loopback) { 
            bins width_8  = {2'b00};
            bins width_16 = {2'b01};
            bins width_32 = {2'b10};
        }

        cp_miso_diff: coverpoint (MISO != MOSI) iff (cfg_loopback) {
            bins diff = {1};
        }

        cp_rx_correct: coverpoint (miso_eff == MOSI) iff (cfg_loopback) {
            bins ok = {1};
        }

        cross_r19: cross cp_loopback, cp_width, cp_miso_diff, cp_rx_correct {
            bins valid_case = binsof(cp_loopback.on) &&
                              binsof(cp_miso_diff.diff) &&
                              binsof(cp_rx_correct.ok);
        }
    endgroup
//---------------------------------------
    task sample_R19( // R19
        input bit        loopback,
        input bit [1:0]  width,
        input bit        mosi_in,
        input bit        miso_in,
        input bit        miso_eff_in,
        input bit [31:0] rx_data
    );
        cfg_loopback = loopback;
        width_cfg    = width;
        MOSI         = mosi_in;
        MISO         = miso_in;
        miso_eff     = miso_eff_in;
        rx_push_data = rx_data;
        cg_R19.sample();
    endtask

/////////////////////////////////////////////////////////////////////////////////
    covergroup cg_R21; // R21
        option.per_instance = 1;

        cp_delay: coverpoint cfg_delay { 
            bins delay_zero  = {0};
            bins delay_one   = {1};
            bins delay_small = {[2:127]};
            bins delay_large = {[128:255]};
        }

    endgroup
//---------------------------------------
        task sample_R21( // R21
        input bit [7:0] delay
    );
        cfg_delay = delay;
        cg_R21.sample();
    endtask

/////////////////////////////////////////////////////////////////////////////////
    function new();
        cg_spi_mode  = new();
        cg_R7        = new();
        cg_sclk_div  = new();
        cg_R21       = new();
        cg_R19       = new();
    endfunction

endclass
`endif