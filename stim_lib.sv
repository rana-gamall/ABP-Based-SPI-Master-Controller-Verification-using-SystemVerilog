// =============================================================================
// stim_lib.sv  (SV-only starter scaffold)
// =============================================================================

`ifndef SPI_STIM_LIB_SV
`define SPI_STIM_LIB_SV
localparam [7:0] APB_CTRL_add     = 8'h00;
localparam [7:0] APB_STATUS__add   = 8'h04;
localparam [7:0] APB_TX_DATA_add  = 8'h08;
localparam [7:0] APB_RX_DATA_add  = 8'h0C;
localparam [7:0] APB_CLK_DIV_add  = 8'h10;
localparam [7:0] APB_SS_CTRL_add  = 8'h14;
localparam [7:0] APB_INT_EN_add   = 8'h18;
localparam [7:0] APB_INT_STAT_add = 8'h1C;
localparam [7:0] APB_DELAY_add    = 8'h20;
class spi_txn;
    rand bit [1:0]  mode;       // {CPOL, CPHA}
    rand bit        lsb_first;
    rand bit [1:0]  width;      // 00=8, 01=16, 10=32
    rand bit [15:0] clk_div;
    rand bit [7:0]  delay_cfg;
    rand bit [31:0] tx_data;
    rand bit        loopback;

    constraint c_width_legal  { width inside {[0:2]}; }
    constraint c_clk_div_sane { clk_div inside {[0:2048]}; }
    constraint c_delay_sane   { delay_cfg inside {[0:31]}; }

    function string sprint();
        return $sformatf("mode=%0d lsb=%0b width=%0d div=%0d delay=%0d tx=0x%08h lb=%0b",
                         mode, lsb_first, width, clk_div, delay_cfg, tx_data, loopback);
    endfunction
endclass

class apb_reg_txn;
    rand bit [2:0]  op;// 0=read, 1=write, 2=write_ss_ctrl, 3=read_status, 4=read_ctrl
    rand bit [31:0] data;
    rand bit [15:0] clk_div;
    rand bit [7:0]  delay;
    rand bit [3:0]  ss_en;
    rand bit [3:0]  ss_val;
    rand bit [4:0]  int_en;
    rand bit [7:0]  ctrl_bits;

    constraint c_op        { op inside {[0:4]}; }//
    constraint c_clk_div   { clk_div inside {[0:2048]}; }
    constraint c_delay_cfg { delay inside {[0:31]}; }
    constraint c_int_en    { int_en inside {[0:31]}; }

    function string sprint();
        return $sformatf("op=%0d data=0x%08h clk_div=%0d delay=%0d ss_en=0x%1h ss_val=0x%1h int_en=0x%02h ctrl=0x%02h",
                         op, data, clk_div, delay, ss_en, ss_val, int_en, ctrl_bits);
    endfunction
endclass

class apb_reg_read_write_txn;
    rand bit [7:0]  addr;
    rand bit [31:0] data;
    rand bit [15:0] clk_div;
    rand bit [7:0]  delay;
    rand bit [3:0]  ss_en;
    rand bit [3:0]  ss_val;
    rand bit [4:0]  int_en;
    rand bit [7:0]  ctrl_bits;
    rand bit       write_read; // 0=read, 1=write

    constraint c_addr      { addr inside {APB_CTRL_add, APB_STATUS__add, APB_TX_DATA_add, APB_RX_DATA_add, APB_CLK_DIV_add, APB_SS_CTRL_add, APB_INT_EN_add, APB_INT_STAT_add, APB_DELAY_add}; }
    constraint c_clk_div   { clk_div inside {[0:2048]}; }
    constraint c_delay_cfg { delay inside {[0:31]}; }
    constraint c_int_en    { int_en inside {[0:31]}; }
    
    function string sprint();
        return $sformatf("addr=0x%02h data=0x%08h clk_div=%0d delay=%0d ss_en=0x%1h ss_val=0x%1h int_en=0x%02h ctrl=0x%02h write_read=%b",
                         addr, data, clk_div, delay, ss_en, ss_val, int_en, ctrl_bits, write_read);
    endfunction
endclass 

class apb_width_txn;
    rand bit [1:0]  mode;       // {CPOL, CPHA}
    rand bit [2:0] width;
    rand bit [31:0] data;
    rand bit loopback;
    rand bit [15:0] clk_div;
    rand bit [7:0]  delay;
    rand bit [3:0]  ss_en;
    rand bit lsb_first;
    rand bit [31:0] miso_pattern;
    rand bit [4:0]  int_en;
    constraint c_width_legal  { width inside {[0:2]}; }
    constraint c_clk_div   { clk_div inside {[0:2048]}; }
    constraint c_delay_cfg { delay inside {[0:31]}; }
    constraint c_int_en    { int_en inside {[0:31]}; }

endclass
`endif // SPI_STIM_LIB_SV
