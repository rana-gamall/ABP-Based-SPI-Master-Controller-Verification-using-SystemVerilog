`ifndef REGFILE_COVERAGE_COL_SV
`define REGFILE_COVERAGE_COL_SV

class regfile_coverage_col;

    // FIFO — cg_fifo_status
    bit [3:0] tx_count;
    bit [3:0] rx_count;
    bit       tx_full;
    bit       rx_full;

    // R6 — cg_bit_order
    bit       cv_lsb_first;
    bit [1:0] cv_width;
    bit       cv_match_tx;
    bit       cv_match_rx;
    bit       cv_first_bit_tx;
    bit       cv_first_bit_rx;
    bit       cv_expected_tx;
    bit       cv_expected_rx;

    // R9 — cg_r9_tx_push
    bit       cv_write_tx;
    bit       cv_push_accepted;
    bit       cv_tx_full;

    // R10 — cg_r10_rx_pop
    bit       cv_read_rx;
    bit       cv_pop_valid;
    bit       cv_rx_empty;
    bit        cv_rx_push_valid ;

    // R13, R14 — cg_rx_tx_overflow
    bit       cv_tx_ovf;
    bit       cv_rx_ovf;
    bit       cv_rx_full;

    // R16 — cg_interrupts
    bit [4:0]   cv_interrupt_bits;
    int_event_e cv_int_event;
    bit [4:0]   cv_int_en_bits;
    bit         cv_irq;

    // R17 — cg_R17
    bit       cv_write;
    bit       cv_cleared;
    bit       cv_w1;

    // R1 — cg_reg_rw
    bit [7:0] addr;
    bit       apb_write;
    bit       apb_read;

    // R23 — cg_reserved_offsets
    bit       is_reserved;
    bit       is_read;
    bit       is_write;
    bit       read_zero;

    // R2 — cg_reset
    bit [31:0] cv_ctrl_reg;
    bit [31:0] status_reg;
    bit [31:0] tx_reg;
    bit [31:0] rx_reg;
    bit [31:0] clk_div_reg;
    bit [31:0] ss_ctrl_reg;
    bit [31:0] int_en_reg;
    bit [31:0] int_stat_reg;
    bit [31:0] delay_reg;

    // R15 — cg_r15
    bit [7:0]  cv_paddr;
    bit        cv_psel;
    bit        cv_penable;
    bit        cv_pwrite;
    bit [31:0] PRDATA;
    bit        rx_empty_w;
    bit [4:0]  int_stat;

    localparam integer IRQ_TX_EMPTY      = 0;
    localparam integer IRQ_RX_FULL       = 1;
    localparam integer IRQ_TX_OVF        = 2;
    localparam integer IRQ_RX_OVF        = 3;
    localparam integer IRQ_TRANSFER_DONE = 4;
    localparam integer IRQ_COUNT         = 5;
    localparam [7:0]   OFF_RX_DATA       = 8'h0C;
    localparam [7:0]   OFF_INT_STAT      = 8'h1C;

    covergroup cg_fifo_status;
        option.per_instance = 1;

        cv_tx_level : coverpoint tx_count {
            bins empty = {0};
            bins low   = {1};
            bins mid   = {4};
            bins high  = {7};
            bins full  = {8};
        }

        cp_tx_full : coverpoint tx_full {
            bins full_tx = {1};
        }

        cp_rx_full : coverpoint rx_full {
            bins full_rx = {1};
        }

        cv_rx_level : coverpoint rx_count {
            bins empty = {0};
            bins low   = {1};
            bins mid   = {4};
            bins high  = {7};
            bins full  = {8};
        }

        cross_tx_full : cross cv_tx_level, cp_tx_full {
            option.cross_auto_bin_max = 0;
            bins tx_full_correct =
                binsof(cv_tx_level.full) &&
                binsof(cp_tx_full.full_tx);
        }

        cross_rx_full : cross cv_rx_level, cp_rx_full {
            option.cross_auto_bin_max = 0;
            bins rx_full_correct =
                binsof(cv_rx_level.full) &&
                binsof(cp_rx_full.full_rx);
        }
    endgroup

    covergroup cg_bit_order;
        option.per_instance = 1;

        cp_lsb_first : coverpoint cv_lsb_first {
            bins lsb = {1};
            bins msb = {0};
        }

        cp_width : coverpoint cv_width {
            bins w8  = {2'b00};
            bins w16 = {2'b01};
            bins w32 = {2'b10};
        }

        cp_tx_match : coverpoint cv_match_tx {
            bins correct = {1};
        }

        cp_rx_match : coverpoint cv_match_rx {
            bins correct = {1};
        }

        cross_tx : cross cp_lsb_first, cp_width, cp_tx_match;
        cross_rx : cross cp_lsb_first, cp_width, cp_rx_match;
    endgroup

    covergroup cg_reset;
        option.per_instance = 1;

        coverpoint cv_ctrl_reg  { bins reset_val = {32'h0000_0000}; }
        coverpoint status_reg   { bins reset_val = {32'h0000_0014}; }
        coverpoint tx_reg       { bins reset_val = {32'h0000_0000}; }
        coverpoint rx_reg       { bins reset_val = {32'h0000_0000}; }
        coverpoint clk_div_reg  { bins reset_val = {32'h0000_0000}; }
        coverpoint ss_ctrl_reg  { bins reset_val = {32'h0000_0000}; }
        coverpoint int_en_reg   { bins reset_val = {32'h0000_0000}; }
        coverpoint int_stat_reg { bins reset_val = {32'h0000_0000}; }
        coverpoint delay_reg    { bins reset_val = {32'h0000_0000}; }
    endgroup

    covergroup cg_R9_tx_push;
        option.per_instance = 1;

        cp_write_tx : coverpoint cv_write_tx iff (!cv_tx_full) {
            bins write = {1};
        }

        cp_push_accepted : coverpoint cv_push_accepted {
            bins accepted = {1};
        }

        cross cp_write_tx, cp_push_accepted;
    endgroup

    covergroup cg_R10_rx_pop;
        option.per_instance = 1;

        cp_read_rx : coverpoint cv_read_rx iff (!cv_rx_empty) {
            bins read = {1};
        }

        cp_pop_valid : coverpoint cv_pop_valid {
            bins valid_pop = {1};
        }

        cross cp_read_rx, cp_pop_valid;
    endgroup

    covergroup cg_R17;
        option.per_instance = 1;

        cp_write   : coverpoint cv_write   { bins done  = {1}; }
        cp_w1      : coverpoint cv_w1      { bins one   = {1}; }
        cp_cleared : coverpoint cv_cleared { bins clear = {1}; }

        cross_R17 : cross cp_write, cp_w1, cp_cleared {
            bins valid = binsof(cp_write.done)  &&
                         binsof(cp_w1.one)      &&
                         binsof(cp_cleared.clear);
        }
    endgroup

    covergroup cg_reg_rw;
        option.per_instance = 1;

        cp_addr : coverpoint addr {
            bins CTRL    = {8'h00};
            bins CLK_DIV = {8'h10};
            bins SS_CTRL = {8'h14};
            bins INT_EN  = {8'h18};
            bins DELAY   = {8'h20};
        }

        cp_write : coverpoint apb_write;
        cp_read  : coverpoint apb_read;

        cross cp_addr, cp_write;
        cross cp_addr, cp_read;
        
    endgroup

    covergroup cg_rx_tx_overflow;
        option.per_instance = 1;

        cp_write_tx : coverpoint cv_write_tx { bins wr   = {1}; }
        cp_tx_full  : coverpoint cv_tx_full  { bins full = {1}; }
        cp_tx_ovf   : coverpoint cv_tx_ovf   { bins ovf  = {1}; }

        cp_rx_push  : coverpoint  cv_rx_push_valid  { bins push = {1}; }
        cp_rx_full  : coverpoint cv_rx_full  { bins full = {1}; }
        cp_rx_ovf   : coverpoint cv_rx_ovf   { bins ovf  = {1}; }

        cross cp_write_tx, cp_tx_full, cp_tx_ovf;
        cross cp_rx_push,  cp_rx_full, cp_rx_ovf; 
    endgroup

    covergroup cg_interrupts;
        option.per_instance = 1;

        cp_tx_empty : coverpoint cv_interrupt_bits[IRQ_TX_EMPTY] {
            bins set = {1};
            bins clear = {0};
        }
        cp_rx_full : coverpoint cv_interrupt_bits[IRQ_RX_FULL] {
            bins set = {1};
            bins clear = {0};
        }
        cp_tx_ovf : coverpoint cv_interrupt_bits[IRQ_TX_OVF] {
            bins set = {1};
            bins clear = {0};
        }
        cp_rx_ovf : coverpoint cv_interrupt_bits[IRQ_RX_OVF] {
            bins set = {1};
            bins clear = {0};
        }
        cp_transfer_done : coverpoint cv_interrupt_bits[IRQ_TRANSFER_DONE] {
            bins set = {1};
            bins clear = {0};
        }

        cp_event : coverpoint cv_int_event {
            bins asserted = {ASSERTED};
            bins cleared  = {W1C_CLEARED};
            bins masked   = {MASKED};
        }

        cp_en : coverpoint cv_int_en_bits {
            bins disabled = {5'b00000};
            bins enabled  = {[1:31]};
        }

        cp_irq : coverpoint cv_irq {
            bins irq_off = {0};
            bins irq_on  = {1};
        }

        cx_intr_event1 : cross cp_tx_empty, cp_event{
            option.cross_auto_bin_max = 0;
            bins tx_empty_asserted = binsof(cp_tx_empty.set) && binsof(cp_event.asserted);
            bins tx_empty_cleared = binsof(cp_tx_empty.clear) && binsof(cp_event.cleared);
            bins tx_empty_masked  = binsof(cp_tx_empty.set) && binsof(cp_event.masked);
        }
        cx_intr_event2 : cross cp_rx_full, cp_event{
            option.cross_auto_bin_max = 0;
            bins rx_full_asserted = binsof(cp_rx_full.set) && binsof(cp_event.asserted);
            bins rx_full_cleared = binsof(cp_rx_full.clear) && binsof(cp_event.cleared);
            bins rx_full_masked  = binsof(cp_rx_full.set) && binsof(cp_event.masked);
        }
        cx_intr_event3 : cross cp_tx_ovf, cp_event{
            option.cross_auto_bin_max = 0;
            bins tx_ovf_asserted = binsof(cp_tx_ovf.set) && binsof(cp_event.asserted);
            bins tx_ovf_cleared = binsof(cp_tx_ovf.clear) && binsof(cp_event.cleared);
            bins tx_ovf_masked  = binsof(cp_tx_ovf.set) && binsof(cp_event.masked);
        }
        cx_intr_event4 : cross cp_rx_ovf, cp_event{
            option.cross_auto_bin_max = 0;
            bins rx_ovf_asserted = binsof(cp_rx_ovf.set) && binsof(cp_event.asserted);
            bins rx_ovf_cleared = binsof(cp_rx_ovf.clear) && binsof(cp_event.cleared);
            bins rx_ovf_masked  = binsof(cp_rx_ovf.set) && binsof(cp_event.masked);
        }
        cx_intr_event5 : cross cp_transfer_done, cp_event{
            option.cross_auto_bin_max = 0;
            bins transfer_done_asserted = binsof(cp_transfer_done.set) && binsof(cp_event.asserted);
            bins transfer_done_cleared = binsof(cp_transfer_done.clear) && binsof(cp_event.cleared);
            bins transfer_done_masked  = binsof(cp_transfer_done.set) && binsof(cp_event.masked);
        }

        cx_irq_logic1 : cross cp_tx_empty, cp_en, cp_irq {
            option.cross_auto_bin_max = 0;
            bins irq_fires  = binsof(cp_en.enabled)  && binsof(cp_irq.irq_on);
            bins irq_masked = binsof(cp_en.disabled) && binsof(cp_irq.irq_off);
        }
        cx_irq_logic2 : cross cp_rx_full, cp_en, cp_irq {
            option.cross_auto_bin_max = 0;
            bins irq_fires  = binsof(cp_en.enabled)  && binsof(cp_irq.irq_on);
            bins irq_masked = binsof(cp_en.disabled) && binsof(cp_irq.irq_off);
        }
        cx_irq_logic3 : cross cp_tx_ovf, cp_en, cp_irq {
            option.cross_auto_bin_max = 0;
            bins irq_fires  = binsof(cp_en.enabled)  && binsof(cp_irq.irq_on);
            bins irq_masked = binsof(cp_en.disabled) && binsof(cp_irq.irq_off);
        }
        cx_irq_logic4 : cross cp_rx_ovf, cp_en, cp_irq {
            option.cross_auto_bin_max = 0;
            bins irq_fires  = binsof(cp_en.enabled)  && binsof(cp_irq.irq_on);
            bins irq_masked = binsof(cp_en.disabled) && binsof(cp_irq.irq_off);
        }
        cx_irq_logic5 : cross cp_transfer_done, cp_en, cp_irq {
            option.cross_auto_bin_max = 0;
            bins irq_fires  = binsof(cp_en.enabled)  && binsof(cp_irq.irq_on);
            bins irq_masked = binsof(cp_en.disabled) && binsof(cp_irq.irq_off);
        }
    endgroup

    covergroup cg_r15;
        option.per_instance = 1;

        cp_rx_read : coverpoint cv_paddr
                     iff (cv_psel && cv_penable && !cv_pwrite) {
            bins rx_data = {OFF_RX_DATA};
        }

        cp_rx_empty : coverpoint rx_empty_w {
            bins empty = {1};
        }

        cp_prdata : coverpoint PRDATA {
            bins zero = {32'h0};
        }

        cp_rx_ovf : coverpoint int_stat[IRQ_RX_OVF] {
            bins no_ovf = {0};
        }

        cross_R15 : cross cp_rx_read, cp_rx_empty, cp_prdata, cp_rx_ovf {
            bins hit = binsof(cp_rx_read.rx_data) &&
                       binsof(cp_rx_empty.empty)  &&
                       binsof(cp_prdata.zero)     &&
                       binsof(cp_rx_ovf.no_ovf);
        }
    endgroup

    function new();
        cg_fifo_status      = new();
        cg_bit_order        = new();
        cg_reset            = new();
        cg_R9_tx_push       = new();
        cg_r15              = new();
        cg_interrupts       = new();
        cg_rx_tx_overflow   = new();
        cg_reg_rw           = new();
        cg_R10_rx_pop       = new();
        cg_R17              = new();
    endfunction

    task sample_fifo_status(
        input bit [3:0] i_tx_count,
        input bit [3:0] i_rx_count,
        input bit       i_tx_full,
        input bit       i_rx_full
    );
        tx_count = i_tx_count;
        rx_count = i_rx_count;
        tx_full  = i_tx_full;
        rx_full  = i_rx_full;
        cg_fifo_status.sample();
    endtask

    task sample_bit_order(
        input bit        lsb_first,
        input bit [1:0]  width,
        input bit [31:0] tx_data,
        input bit [31:0] rx_data,
        input bit        first_bit_tx_observed,
        input bit        first_bit_rx_observed
    );
        cv_lsb_first    = lsb_first;
        cv_width        = width;
        cv_first_bit_tx = first_bit_tx_observed;
        cv_first_bit_rx = first_bit_rx_observed;

        case (width)
            2'b00: cv_expected_tx = lsb_first ? tx_data[0] : tx_data[7];
            2'b01: cv_expected_tx = lsb_first ? tx_data[0] : tx_data[15];
            2'b10: cv_expected_tx = lsb_first ? tx_data[0] : tx_data[31];
            default: cv_expected_tx = 0;
        endcase

        case (width)
            2'b00: cv_expected_rx = lsb_first ? rx_data[0] : rx_data[7];
            2'b01: cv_expected_rx = lsb_first ? rx_data[0] : rx_data[15];
            default: cv_expected_rx = lsb_first ? rx_data[0] : rx_data[31];
        endcase

        cv_match_tx = (cv_first_bit_tx == cv_expected_tx);
        cv_match_rx = (cv_first_bit_rx == cv_expected_rx);
        cg_bit_order.sample();
    endtask

    task sample_reset_values(
        input logic [31:0] i_ctrl_reg ,
        input logic [31:0] i_status_reg ,
        input logic [31:0] i_tx_reg ,
        input logic [31:0] i_rx_reg ,
        input logic [31:0] i_clk_div_reg ,
        input logic [31:0] i_ss_ctrl_reg ,
        input logic [31:0] i_int_en_reg ,
        input logic [31:0] i_int_stat_reg ,
        input logic [31:0] i_delay_reg 
    );
        cv_ctrl_reg  = i_ctrl_reg;
        status_reg   = i_status_reg;
        tx_reg       = i_tx_reg;
        rx_reg       = i_rx_reg;
        clk_div_reg  = i_clk_div_reg;
        ss_ctrl_reg  = i_ss_ctrl_reg;
        int_en_reg   = i_int_en_reg;
        int_stat_reg = i_int_stat_reg;
        delay_reg    = i_delay_reg;
        cg_reset.sample();
    endtask

    task sample_r9_tx_push(
        input bit       i_apb_write,
        input bit [7:0] i_addr,
        input bit       i_tx_full,
        input bit       i_tx_push
    );
        cv_write_tx      = (i_apb_write && i_addr == 8'h08);
        cv_tx_full       = i_tx_full;
        cv_push_accepted = (i_tx_push && !i_tx_full);
        cg_R9_tx_push.sample();
    endtask

    task sample_r10_rx_pop(
        input bit       i_apb_read,
        input bit [7:0] i_addr,
        input bit       i_rx_empty,
        input bit       i_rx_pop
    );
        cv_read_rx   = (i_apb_read && i_addr == 8'h0C);
        cv_rx_empty  = i_rx_empty;
        cv_pop_valid = (i_rx_pop && !i_rx_empty);
        cg_R10_rx_pop.sample();
    endtask

    task sample_reg_rw(
        input bit [7:0] i_addr,
        input bit       i_write,
        input bit       i_read
    );
        addr      = i_addr;
        apb_write = i_write;
        apb_read  = i_read;
        cg_reg_rw.sample();
    endtask

    task sample_rx_tx_overflow(
        input bit i_write_tx,
        input bit i_tx_full,
        input bit i_tx_ovf,
        input bit i_rx_push,
        input bit i_rx_full,
        input bit i_rx_ovf
    );
        cv_write_tx = i_write_tx;
        cv_tx_full  = i_tx_full;
        cv_tx_ovf   = i_tx_ovf;
        cv_rx_push_valid = i_rx_push;
        cv_rx_full  = i_rx_full;
        cv_rx_ovf   = i_rx_ovf;
        cg_rx_tx_overflow.sample();
    endtask

    task sample_interrupt(
        input bit [4:0]   i_irq_src,
        input int_event_e i_ev_type,
        input bit [4:0]   i_int_en,
        input bit         i_irq
    );
        cv_interrupt_bits = i_irq_src;
        cv_int_event      = i_ev_type;
        cv_int_en_bits    = i_int_en;
        cv_irq            = i_irq;
        cg_interrupts.sample();
    endtask

    task sample_R17(
        input bit       i_write,
        input bit [7:0] i_addr,
        input bit [4:0] i_wdata,
        input bit [4:0] i_int_stat_before,
        input bit [4:0] i_int_stat_after
    );
        cv_write   = (i_write && i_addr == OFF_INT_STAT);
        cv_w1      = (i_wdata != 0);
        cv_cleared = (i_int_stat_after == (i_int_stat_before & ~i_wdata));
        cg_R17.sample();
    endtask

    task sample_cg_r15(
        input bit        i_psel,
        input bit        i_penable,
        input bit        i_pwrite,
        input bit [7:0]  i_paddr,
        input bit        i_rx_empty_w,
        input bit [31:0] i_prdata,
        input bit [4:0]  i_int_stat
    );
        cv_psel    = i_psel;
        cv_penable = i_penable;
        cv_pwrite  = i_pwrite;
        cv_paddr   = i_paddr;
        rx_empty_w = i_rx_empty_w;
        PRDATA     = i_prdata;
        int_stat   = i_int_stat;
        cg_r15.sample();
    endtask

endclass

`endif