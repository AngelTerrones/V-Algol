// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : RAM
// Project     : AlgolSoC
// Description : System RAM
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module ram #(
             parameter RAM_AW = 20
             )(
               input wire        clk,
               input wire        rst,
               input wire [31:0] ram_address,
               input wire [31:0] ram_wdata,
               input wire [ 3:0] ram_wsel,
               input wire        ram_valid,
               output reg [31:0] ram_rdata,
               output reg        ram_ready,
               output reg        ram_error
               );
    // =====================================================================
    localparam WORDS = 2**(RAM_AW-2);  // words
    //
    reg [31:0]        mem[0:WORDS-1] /* verilator public */;
    wire [RAM_AW-3:0] d_address;         // words...
    //
    assign d_address = ram_address[RAM_AW-1:2];
    // handshake
    always @(*) begin
        ram_error = 0;
    end
    always @(posedge clk) begin
        ram_ready <= ram_valid && !ram_ready;
        if (rst) ram_ready <= 0;
    end
    // read
    always @(posedge clk) begin
        ram_rdata <= 32'bx;
        if (ram_valid && !ram_ready) ram_rdata <= mem[d_address];
    end

    // write
    always @(posedge clk) begin
        if (ram_valid && ram_ready) begin
            if (ram_wsel[0]) mem[d_address][0+:8]  <= ram_wdata[0+:8];
            if (ram_wsel[1]) mem[d_address][8+:8]  <= ram_wdata[8+:8];
            if (ram_wsel[2]) mem[d_address][16+:8] <= ram_wdata[16+:8];
            if (ram_wsel[3]) mem[d_address][24+:8] <= ram_wdata[24+:8];
        end
    end
    // =====================================================================
    // unused signals: remove verilator warnings about unused signal
    wire _unused = &{ram_address[31:RAM_AW], ram_address[1:0]};
    // =====================================================================
endmodule
`default_nettype wire
// EOF
