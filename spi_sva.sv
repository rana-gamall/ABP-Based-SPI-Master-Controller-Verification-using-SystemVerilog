// =============================================================================
// spi_sva.sv  (SV-only starter scaffold)
// =============================================================================

`ifndef SPI_SVA_SV
`define SPI_SVA_SV
`timescale 1ns/1ps

module spi_sva (
    input wire        PCLK,
    input wire        PRESETn,
    input wire        ctrl_en,
    input wire [4:0]  int_stat,
    input wire        IRQ,
    input wire [3:0]  SS_n,
    input wire [3:0]  ss_en,
    input wire [3:0]  ss_val,

    // ===== Added signals =====
    input wire        ctrl_mstr,
    input wire [1:0]  ctrl_mode,
    input wire        ctrl_lsb_first,
    input wire        ctrl_loopback,
    input wire [1:0]  ctrl_width,
    input wire [15:0] clk_div,
    input wire [7:0]  delay_cfg,

    input wire [4:0]  int_en,

    input wire        rx_empty_w,
    input wire        rx_full_w,
    input wire        tx_empty_w,
    input wire        tx_empty,
    input wire        tx_full_w,

    input wire [3:0]  tx_count,
    input wire [3:0]  rx_count,

    input wire        busy_in,

    input wire        PSLVERR,
    input wire        PREADY,
    input wire        PSEL,
    input wire        PENABLE,
    input wire        PWRITE,
    input wire        apb_access,
    input wire        apb_read,
    input wire        apb_write,
    input wire [7:0]  PADDR,
    input wire [31:0] PWDATA,
    input wire [31:0] PRDATA,
    input  wire       tx_pop,    
    input  wire       transfer_done_pulse,
    input wire        tx_push_dropped,
    input wire        rx_push_valid
    

  );
   localparam integer FIFO_DEPTH = 8;
   localparam  integer IRQ_TX_OVF  = 2; 
   localparam  integer IRQ_RX_OVF =3 ; 
//R2 All registers return their specified reset values after PRESETn asserts.
    always_comb begin
        if (!PRESETn)begin 
            R2: assert final ( ctrl_en == 1'b0 &&
            ctrl_mstr   == 1'b0&&
            ctrl_mode     == 2'b00&&
            ctrl_lsb_first == 1'b0&&
            ctrl_loopback  == 1'b0&&
            ctrl_width    == 2'b00&&
            clk_div       == 16'h0&&
            ss_en          == 4'h0&&
            ss_val         == 4'h0&&
            int_en           == '0&&
            int_stat         == '0&&
            delay_cfg      == 8'h0 && 
            rx_empty_w==1'h1&&              
            rx_full_w==1'h0&&             
            tx_empty_w==1'h1 && 
            tx_empty==1'h1&&           
            tx_full_w==1'h0&&               
             busy_in ==1'h0);      
       cover_R2: cover final ( ctrl_en == 1'b0 &&
            ctrl_mstr   == 1'b0&&
            ctrl_mode     == 2'b00&&
            ctrl_lsb_first == 1'b0&&
            ctrl_loopback  == 1'b0&&
            ctrl_width    == 2'b00&&
            clk_div       == 16'h0&&
            ss_en          == 4'h0&&
            ss_val         == 4'h0&&
            int_en           == '0&&
            int_stat         == '0&&
            delay_cfg      == 8'h0&& 
            rx_empty_w==1'h1&&              
            rx_full_w==1'h0&&             
            tx_empty_w==1'h1 &&  
             tx_empty==1'h1&&           
            tx_full_w==1'h0&&               
             busy_in ==1'h0);
        end 
//R11 TX FIFO depth is exactly 8 entries; TX_FULL asserts on the 8th pending entry
        if (tx_count==8)begin
        R11: assert final  (tx_full_w==1'h1);
        cover_R11: cover final  (tx_full_w==1'h1);
        end
//R12 RX FIFO depth is exactly 8 entries; RX_FULL asserts on the 8th received entry.
          if (rx_count==8)begin
        R12: assert final  (rx_full_w==1'h1);
        cover_R12: cover final  (rx_full_w==1'h1);
        end
//R20 SS_n[i] = !SS_EN[i] | SS_VAL[i] combinationally; IP never drives SS_n autonomously.
      R20:  assert final (SS_n == ~ss_en | ss_val); 
      cover_R20: cover final (SS_n == ~ss_en | ss_val); 
//R22 APB PSLVERR is 0 
          R22:  assert final (PSLVERR==0); 
         cover_R22: cover final (PSLVERR==0); 
//PREADY is 1 for every addressed access (zero wait states). 
         if (apb_access)begin
           R22_1:  assert final (PREADY==1); 
         cover_R22_1: cover final (PREADY==1); 
         end 

        end 
    property p_R3_fifo_reset;
        @(posedge PCLK) disable iff (!PRESETn)
        !ctrl_en |=>
            (rx_empty_w && !rx_full_w && tx_empty_w && tx_empty && !tx_full_w);
    endproperty

    R3_fifo_reset: assert property (p_R3_fifo_reset)
        else $error("[ASSERTION_ERROR] R3: EN=0 but FIFOs not flushed");

    cover_R3: cover property (p_R3_fifo_reset);
        // When CTRL.EN deasserts, aggregate IRQ MUST be 0 within 1 cycle
        // (student should extend with the exact spec wording from R19)
    a_irq_off_when_disabled : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
            (!ctrl_en) |-> ##[0:1] (IRQ == 1'b0 || int_stat != 0)
    ) else $error("[ASSERTION_ERROR] a_irq_off_when_disabled");


//R13 TX_DATA write while TX_FULL=1 discards the write and sets STATUS.TX_OVF and INT_STAT[TX_OVF].
   R13 : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
            (tx_push_dropped) |=>  (int_stat[IRQ_TX_OVF]== 1'b1)
    ) else $error("[ASSERTION_ERROR] Tx_OVF doesn't assert");

 
 
//R14 A transfer completing while RX_FULL=1 discards the received word and sets STATUS.RX_OVF and INT_STAT[RX_OVF].
//-FIFO: no push when full (after OVF clear) without explicit OVF assertion.
   R14 : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
            (rx_push_valid && rx_full_w) |=>  (int_stat[IRQ_RX_OVF]== 1'b1)
    ) else $error("[ASSERTION_ERROR] RX_OVF doesn't assert");


//R15 RX_DATA read while RX_EMPTY returns 0 and does NOT set RX_OVF.
   R15 : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
            (rx_empty_w && PADDR==8'h0C && apb_read) |->  (PRDATA==0&& int_stat[IRQ_RX_OVF]== 1'b0)
    ) else $error("[ASSERTION_ERROR] RX_OVF doesn't assert");


  // R16 IRQ = |(INT_STAT & INT_EN) at all times; INT_EN does not gate status capture.
    R16 : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
            IRQ == |(int_stat & int_en) 
    ) else $error("[ASSERTION_ERROR]IRQ error");

//R17 INT_STAT is W1C: writing 1 to a bit clears it; 0 has no effect.
R17_W1C : assert property (
    @(posedge PCLK) disable iff (!PRESETn )
    (apb_write && (PADDR == 8'h1C) && !($rose(transfer_done_pulse)) && !($rose(rx_push_valid)) && !($rose(tx_pop)))|=>(int_stat == ($past(int_stat) & ~$past(PWDATA[4:0])))
) else
    $error("[ASSERTION_ERROR] INT_STAT W1C behavior failed");


//R18_2
R18_w1c_race_if2 : assert property (
    @(posedge PCLK) disable iff (!PRESETn)
    ( apb_write && (PADDR == 8'h1C) && PWDATA[3]&& $rose(rx_push_valid) && rx_full_w )|=> (int_stat[3] == 1'b1)
) else $error("[ASSERTION_ERROR] R18: RACE if2 RX_OVF cleared despite simultaneous HW event");


//R18_
R18_w1c_race_rx_if3 : assert property (
    @(posedge PCLK) disable iff (!PRESETn)
    ( apb_write && (PADDR == 8'h1C) && PWDATA[1]&&$rose(rx_push_valid) && !rx_full_w && (rx_count == FIFO_DEPTH-1))|=> (int_stat[1] == 1'b1)
) else $error("[ASSERTION_ERROR] R18: W1C race lost - RACE if3 cleared despite simultaneous HW event");



R18_w1c_race_rx_if4 : assert property (
    @(posedge PCLK) disable iff (!PRESETn)
    ( apb_write && (PADDR == 8'h1C) && PWDATA[0]&& $rose(tx_pop) && (tx_count == 1))|=> (int_stat[0] == 1'b1)
) else $error("[ASSERTION_ERROR] R18: RACE if4 cleared despite simultaneous HW event");



R18_w1c_race_rx_if5 : assert property (
    @(posedge PCLK) disable iff (!PRESETn)
    ( apb_write && (PADDR == 8'h1C) && PWDATA[4]&& $rose(transfer_done_pulse))|=> (int_stat[4] == 1'b1)
) else $error("[ASSERTION_ERROR] R18: RACE if5 cleared despite simultaneous HW event");



//R23 Reserved offsets (0x24+) read as 0 and writes are ignored.
R23_reserved_read_zero : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (apb_read && (PADDR >= 8'h24))|-> (PRDATA == 32'h0) 
        ) else $error("[ASSERTION_ERROR] R23: Reserved offset 0x%02h returned non-zero PRDATA=0x%h", PADDR, PRDATA);
//PSEL=1 for at least 2 PCLK to complete a transaction.
R_APB_PSEL: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE)|=>(PSEL && PENABLE)
)else $error("[ASSERTION_ERROR] trans fail");

//PENABLE must only assert while PSEL=1.
R_APB_PEN: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (PENABLE)|-> (PSEL)
)else $error("[ASSERTION_ERROR] penable assertion fail");

//PADDR, PWRITE, PWDATA stable from SETUP to ACCESS of the same transaction.
R_APB_change: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE)|->($stable(PADDR) && $stable(PWRITE) && $stable(PWDATA))
 ) else $error("[ASSERTION_ERROR] change in trans fail");

    
endmodule

`endif // SPI_SVA_SV


`ifndef CORE_SVA_SV
`define CORE_SVA_SV
`timescale 1ns/1ps

module core_sva (
  
 


    input wire        PCLK,
    input wire        PRESETn,



    // ===== Added signals =====
    input wire        cfg_en,
    input wire        busy,
    input wire        SCLK,
    input wire        MOSI,
    input wire        MISO,
 input  wire         cfg_mstr,
    input wire [1:0]  cfg_mode,
    input wire        cpol,
    input wire        cpha,

    input wire  [1:0]  state,
    input wire        transfer_done_pulse,

    input wire        tx_empty,
    input wire [7:0]  cfg_delay,

    input wire [15:0] xfer_div,
    input wire [16:0] half_period,
    input wire [16:0] sclk_cnt,

    input wire        cfg_lsb_first,
    input wire [1:0]  cfg_width,
    input wire [15:0] cfg_clk_div,

    input wire [1:0]  xfer_mode,
    input wire        xfer_lsb_first,
    input wire [1:0]  xfer_width,

    input wire [8:0]  gap_cnt,

    input wire [3:0]  ss_n_drive,

    input wire        cfg_loopback,
    input wire        miso_eff,
    input wire sclk_phase
);
   localparam S_IDLE   = 2'd0;
   localparam S_SHIFT  = 2'd1;
   localparam S_FINISH = 2'd2;
   localparam S_GAP    = 2'd3;

  always_comb begin
if (!cfg_en)begin
//EN=0 holds the shifter 
R3_2_1: assert final (busy ==0);
cove_R3_2_1: cover final (busy ==0);
end
end

//R3  SCLK stays at CPOL idle;
    R3_2 : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (!cfg_en) |=> (SCLK == $past(cfg_mode[1]))
    ) else $error("[ASSERTION_ERROR] R3: SCLK=%b not at CPOL idle=%b when cfg_en=0",SCLK, cfg_mode[1]);

//R4 For each SPI mode, SCLK idle polarity matches CPOL before, between, and after transfers.
// SPI: SCLK idle level matches CPOL whenever BUSY=0.

 R4_idle: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (cfg_en && state==S_IDLE) |=> (SCLK == $past(cfg_mode[1]))
    ) else $error("[ASSERTION_ERROR] R4: SCLK idle=%b does not match CPOLidle=%b when not busy", SCLK, cfg_mode[1]);

 R4_finish: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (transfer_done_pulse) |-> (SCLK == $past(cpol))
    ) else $error("[ASSERTION_ERROR] R4: SCLK idle=%b does not match CPOL=%b after finish", SCLK, cpol);

 R4_GAP: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (state==S_GAP) |=> (SCLK == $past(cpol))
    ) else $error("[ASSERTION_ERROR] R4: SCLK idle=%b does not match CPOL=%b in between transfers", SCLK, cpol);

//R5 For each SPI mode, MOSI is stable across the sample edge defined by CPOL/CPHA and changes on the launch edge.
//- SPI: MOSI stable for at least 1 PCLK around each sample edge (WIRE-STABILITY).
logic leading;
logic is_sample_edge;
logic is_launch_edge;
assign leading =~sclk_phase;
assign is_sample_edge =(cpha == 1'b0) ? leading : ~leading;

assign is_launch_edge =~is_sample_edge;
R5_before: assert property (
        @(posedge PCLK) disable iff (!PRESETn) 
       (((cpha == cpol && $rose(SCLK)) || (cpha != cpol && $fell(SCLK)))&& state==S_SHIFT) |-> ($stable(MOSI))
    ) else $error("R5-A FAIL: MOSI changed on sample-edge cycle (MOSI=%0b, SCLK=%b)", MOSI, SCLK);
//to avoid racing condition
R5_after: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        ((sclk_cnt == half_period - 1)&&is_sample_edge && state==S_SHIFT) |=> ($stable(MOSI))
    ) else $error("R5-A FAIL: MOSI changed after sample-edge cycle (MOSI=%0b, SCLK=%b)", MOSI, SCLK);

R5_launch: assert property ( //trigger al assertion lw la2et change f al mosi ata2ked ank is launch edge 
//dlw2ty anta bttcheck an al mosi hasalha change 3n al cycle aly fatet 
//tb al cycle aly fatt anta kont eh >>kont shift f dollar sign past ll atnen w dollar sign past launch w sclk_cnt la2n al eevaluate ysm3 next cycle
        @(posedge PCLK) disable iff (!PRESETn)
        ( ($past(state) == S_SHIFT)&&$changed(MOSI))|->($past(is_launch_edge) && ($past(sclk_cnt) == half_period - 1))
    ) else $error("R5-A FAIL: MOSI is stable on launch edge cycle (MOSI=%0b, SCLK=%b)", MOSI, SCLK);
 

//R7 A transfer lasts exactly WIDTH SCLK cycles; BUSY=1 throughout and deasserts one PCLK after the last sample edge.

    R7_busy_during_finish : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (state == S_FINISH || state == S_GAP ||state == S_SHIFT ) |-> (busy == 1'b1)
    ) else $error("[ASSERTION_ERROR] R7: busy=0 during  trans");


    R7_busy_after_done : assert property ( 
        @(posedge PCLK) disable iff (!PRESETn)
        // When done pulse fires and no delay queued, IDLE next cycle -> busy=0
        (transfer_done_pulse && ($past(tx_empty) || ($past(cfg_delay) == 8'h0)))|-> (busy == 1'b0 )
    ) else $error("[ASSERTION_ERROR] R7: busy did not deassert after transfer_done_pulse");


//R8 SCLK frequency equals PCLK / (2 x (DIV+1)) for all DIV in [0, 65535].+ R24
     R8_halfperiodcalc : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
     (half_period == {1'b0, xfer_div} + 17'd1)
    ) else $error("[ASSERTION_ERROR] R8:  half_period error .  div=%0d ",xfer_div); 

    R8_sclk_toggles_at_half_period : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        // In SHIFT state, SCLK toggles IFF counter hits half_period-1
        (state == S_SHIFT && sclk_cnt == (half_period - 1)) |=> $changed(SCLK)
    ) else $error("[ASSERTION_ERROR] R8: SCLK did not toggle at half_period. div=%0d sclk_cnt=%0d",xfer_div, sclk_cnt);

    R8_sclk_stable_before_half_period : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (state == S_SHIFT && sclk_cnt < (half_period - 1))|=> $stable(SCLK)
    ) else $error("[ASSERTION_ERROR] R8: SCLK toggled early, before half_period. div=%0d cnt=%0d",xfer_div, sclk_cnt);
 
//R19 Loopback mode (CTRL.LOOPBACK=1) routes MOSI internally to the RX shift register; external MISO is ignored

     R19 : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
    ((cfg_loopback)|-> (miso_eff==MOSI))
    ) else $error("[ASSERTION_ERROR] R19:  half_period error .  div=%0d ",xfer_div); 


//R21 DELAY SCLK half-cycles of idle are inserted between consecutive transfers when DELAY > 0 and another word is queued.
// checking that we entered the gap state at the right time. 
R21: assert property (
    @(posedge PCLK) disable iff (!PRESETn)
    (state == S_FINISH &&
     sclk_cnt == (half_period - 1) &&
     cfg_delay > 0 && !tx_empty)
    |=> (state == S_GAP)
)else $error("[ASSERTION_ERROR] R21:  delay Gap error. cfg_delay=%0d gap_cnt=%0d",cfg_delay,gap_cnt); 


//R25 DIV, MODE, WIDTH, LSB_FIRST are sampled at transfer start and held for that transfer. 
   a_R25_latched_at_start_mode : assert property ( 
        @(posedge PCLK) disable iff (!PRESETn)
       (state==S_IDLE && cfg_en &&!tx_empty && cfg_mstr && (ss_n_drive != 4'hF)) |=> (xfer_mode == $past(cfg_mode)&&(xfer_lsb_first == $past(cfg_lsb_first))&&(xfer_div == $past(cfg_clk_div))&&(xfer_width == $past(cfg_width)))
    ) else $error("[ASSERTION_ERROR] R25: xfer not latched from cfg at transfer start");

   a_R25_held : assert property ( 
        @(posedge PCLK) disable iff (!PRESETn)
       (busy) |=> $stable(xfer_mode) && $stable(xfer_lsb_first) && $stable(xfer_div) && $stable(xfer_width)
    ) else $error("[ASSERTION_ERROR] R25: xfer not stable  at transfer ");


// SPI: SS_n held asserted for the entire WIDTH-bit transfer .
   extra_ss_n : assert property (
        @(posedge PCLK) disable iff (!PRESETn)
       (busy) |-> (ss_n_drive!=4'hF)
    ) else $error("[ASSERTION_ERROR] SS_n is desasserted during transmission ");
endmodule

`endif // SPI_SVA_SV