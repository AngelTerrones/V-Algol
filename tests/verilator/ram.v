// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
// -----------------------------------------------------------------------------
// Title       : RAM
// Project     : Algol
// Description : Dualport wishbone memory
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module ram #(
             parameter ADDR_WIDTH = 22,
             parameter BASE_ADDR  = 32'h0000_0000
             )(
               // verilator lint_off UNUSED
               input wire [31:0] wbs_addr_i,
               // verilator lint_on UNUSED
               input wire [31:0] wbs_dat_i,
               input wire [ 3:0] wbs_sel_i,
               input wire        wbs_cyc_i,
               input wire        wbs_stb_i,
               input wire        wbs_we_i,
               output reg [31:0] wbs_dat_o,
               output reg        wbs_ack_o
               );
    //--------------------------------------------------------------------------
    localparam BYTES = 2**ADDR_WIDTH;
    //
    byte                    mem[0:BYTES - 1];
    wire [ADDR_WIDTH - 1:0] d_addr;
    wire                    d_access;
    // read/write data
    assign d_addr   = {wbs_addr_i[ADDR_WIDTH - 1:2], 2'b0};
    assign d_access = wbs_addr_i[31:ADDR_WIDTH] == BASE_ADDR[31:ADDR_WIDTH];
    always @(*) begin
        wbs_dat_o = 32'hx;
        if (wbs_we_i && d_access) begin
            if (wbs_sel_i[0]) mem[d_addr + 0] = wbs_dat_i[0+:8];
            if (wbs_sel_i[1]) mem[d_addr + 1] = wbs_dat_i[8+:8];
            if (wbs_sel_i[2]) mem[d_addr + 2] = wbs_dat_i[16+:8];
            if (wbs_sel_i[3]) mem[d_addr + 3] = wbs_dat_i[24+:8];
        end else begin
            wbs_dat_o[7:0]    = mem[d_addr + 0];
            wbs_dat_o[15:8]   = mem[d_addr + 1];
            wbs_dat_o[23:16]  = mem[d_addr + 2];
            wbs_dat_o[31:24]  = mem[d_addr + 3];
        end
        //
        wbs_ack_o = wbs_cyc_i && wbs_stb_i && d_access;
    end
    //--------------------------------------------------------------------------
    // SystemVerilog DPI functions
    export "DPI-C" function dpi_read_word;
    export "DPI-C" function dpi_read_byte;
    export "DPI-C" function dpi_write_word;
    export "DPI-C" function dpi_load_mem;
    import "DPI-C" function void c_load_mem(input byte mem[], input string filename);
    //
    function int dpi_read_word(int address);
        if (address[31:ADDR_WIDTH] != BASE_ADDR[31:ADDR_WIDTH]) begin
            $display("[RAM read word] Bad address: %h. Abort.\n", address);
            $finish;
        end
        return {mem[address[ADDR_WIDTH-1:0] + 3],
                mem[address[ADDR_WIDTH-1:0] + 2],
                mem[address[ADDR_WIDTH-1:0] + 1],
                mem[address[ADDR_WIDTH-1:0] + 0]};
    endfunction
    //
    function byte dpi_read_byte(int address);
        if (address[31:ADDR_WIDTH] != BASE_ADDR[31:ADDR_WIDTH]) begin
            $display("[RAM read byte] Bad address: %h. Abort.\n", address);
            $finish;
        end
        return mem[address[ADDR_WIDTH-1:0]];
    endfunction
    //
    function void dpi_write_word(int address, int data);
        if (address[31:ADDR_WIDTH] != BASE_ADDR[31:ADDR_WIDTH]) begin
            $display("[RAM write word] Bad address: %h. Abort.\n", address);
            $finish;
        end
        mem[address[ADDR_WIDTH-1:0] + 0] = data[7:0];
        mem[address[ADDR_WIDTH-1:0] + 1] = data[15:8];
        mem[address[ADDR_WIDTH-1:0] + 2] = data[23:16];
        mem[address[ADDR_WIDTH-1:0] + 3] = data[31:24];
    endfunction
    //
    function void dpi_load_mem(string filename);
        c_load_mem(mem, filename);
    endfunction
    //--------------------------------------------------------------------------
endmodule
