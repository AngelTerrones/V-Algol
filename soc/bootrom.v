// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : BootROM
// Project     : AlgolSoC
// Description : ROM for bootloader storage
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module bootrom #(
                 parameter ROM_AW     = 8,
                 parameter BOOTLOADER = "bootloader.hex"
                 )(
                   input wire        clk,
                   input wire        rst,
                   input wire [31:0] rom_address,
                   input wire        rom_valid,
                   output reg [31:0] rom_rdata,
                   output reg        rom_ready,
                   output reg        rom_error
                   );
    // =====================================================================
    localparam WORDS = 2**(ROM_AW-2); // words...
    // verilator lint_off UNDRIVEN
    reg [31:0]            mem[0:WORDS-1];
    // verilator lint_on UNDRIVEN
    wire [ROM_AW-3:0] d_address;  // Word address
    //
    initial begin
        $readmemh(BOOTLOADER, mem);
    end
    //
    assign d_address = rom_address[ROM_AW-1:2];
    // handshake
    always @(*) begin
        rom_error = 0;
    end
    always @(posedge clk) begin
        rom_ready <= rom_valid && !rom_ready && !(|rom_address[1:0]);
        if (rst) rom_ready <= 0;
    end
    // read
    always @(posedge clk) begin
        rom_rdata <= 32'bx;
        if (rom_valid) rom_rdata <= mem[d_address];
    end

    // =====================================================================
    // unused signals: remove verilator warnings about unused signal
    wire _unused = &{rom_address[31:ROM_AW]};
    // =====================================================================
endmodule
`default_nettype wire
// EOF
