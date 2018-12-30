// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : Timer
// Project     : AlgolSoC
// Description : System timer.
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module timer (
              input wire        clk,
              input wire        rst,
              input wire [31:0] timer_address,
              input wire [31:0] timer_wdata,
              input wire [ 3:0] timer_wsel,
              input wire        timer_valid,
              output reg [31:0] timer_rdata,
              output reg        timer_ready,
              output reg        timer_error,
              //
              output reg        xint_mtip
              );
    // =====================================================================
    reg [63:0] mtimecmp, mtime;
    // read
    always @(posedge clk) begin
        case (timer_address[3:2])
            2'b00: timer_rdata <= mtimecmp[31:0];
            2'b01: timer_rdata <= mtimecmp[63:32];
            2'b10: timer_rdata <= mtime[31:0];
            2'b11: timer_rdata <= mtime[63:32];
        endcase
    end
    // write
    always @(posedge clk) begin
        if (timer_valid && timer_ready && (&timer_wsel)) begin
            // verilator lint_off CASEINCOMPLETE
            case (timer_address[3:2])
                2'b00: mtimecmp[31:0]  <= timer_wdata;
                2'b01: mtimecmp[63:32] <= timer_wdata;
            endcase
            // verilator lint_on CASEINCOMPLETE
        end
        if (rst) mtimecmp <= -1;
    end
    // handshake
    always @(*) begin
        timer_error = 0;  // TODO: assert error for unaligned access?
    end
    always @(posedge clk) begin
        timer_ready <= timer_valid && !(|timer_address[1:0]);
        if (rst) timer_ready <= 0;
    end
    // counter
    always @(posedge clk) begin
        mtime <= mtime + 1;
        if (rst) mtime <= 0;
    end
    // interrupt flag
    always @(posedge clk) begin
        xint_mtip <= mtime >= mtimecmp;
    end
    // =====================================================================
    // unused signals: remove verilator warnings about unused signal
    wire _unused = &{timer_address};
    // =====================================================================
endmodule
`default_nettype wire
// EOF
