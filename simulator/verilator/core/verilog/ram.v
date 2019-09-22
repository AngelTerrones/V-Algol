// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : RAM
// Description : Dualport memory
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module ram #(
             parameter ADDR_WIDTH = 22,
             parameter BASE_ADDR  = 32'h0000_0000
             )(
               input wire        clk,
               input wire [31:0] mem_address,
               input wire [31:0] mem_wdata,
               input wire [ 3:0] mem_wsel,
               input wire        mem_valid,
               output reg [31:0] mem_rdata,
               output reg        mem_ready,
               output reg        mem_error
               );
    //--------------------------------------------------------------------------
    localparam BYTES = 2**ADDR_WIDTH;
    //
    byte                    mem[0:BYTES - 1];
    wire [ADDR_WIDTH - 1:0] d_addr;
    wire                    d_access;
    // read/write data
    assign d_addr   = {mem_address[ADDR_WIDTH - 1:2], 2'b0};
    assign d_access = mem_address[31:ADDR_WIDTH] == BASE_ADDR[31:ADDR_WIDTH];
    // read
    always @(*) begin
        mem_rdata = 32'hx;
        if (d_access && mem_valid) begin
            mem_rdata[7:0]   = mem[d_addr + 0];
            mem_rdata[15:8]  = mem[d_addr + 1];
            mem_rdata[23:16] = mem[d_addr + 2];
            mem_rdata[31:24] = mem[d_addr + 3];
        end
    end
    // write
    always @(posedge clk) begin
        if (d_access && mem_valid) begin
            if (|mem_wsel) begin
                if (mem_wsel[0]) mem[d_addr + 0] <= mem_wdata[0+:8];
                if (mem_wsel[1]) mem[d_addr + 1] <= mem_wdata[8+:8];
                if (mem_wsel[2]) mem[d_addr + 2] <= mem_wdata[16+:8];
                if (mem_wsel[3]) mem[d_addr + 3] <= mem_wdata[24+:8];
            end
        end
    end
    //
    always @(*) begin
        mem_ready = mem_valid && d_access; // ready always 1, except for errors.
        mem_error = mem_valid && !d_access;
    end
    //--------------------------------------------------------------------------
    // SystemVerilog DPI functions
    export "DPI-C" function ram_v_dpi_read_word;
    export "DPI-C" function ram_v_dpi_read_byte;
    export "DPI-C" function ram_v_dpi_write_word;
    export "DPI-C" function ram_v_dpi_write_byte;
    export "DPI-C" function ram_v_dpi_load;
    import "DPI-C" function void ram_c_dpi_load(input byte mem[], input string filename);
    //
    function int ram_v_dpi_read_word(int address);
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
    function byte ram_v_dpi_read_byte(int address);
        if (address[31:ADDR_WIDTH] != BASE_ADDR[31:ADDR_WIDTH]) begin
            $display("[RAM read byte] Bad address: %h. Abort.\n", address);
            $finish;
        end
        return mem[address[ADDR_WIDTH-1:0]];
    endfunction
    //
    function void ram_v_dpi_write_word(int address, int data);
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
    function void ram_v_dpi_write_byte(int address, byte data);
        if (address[31:ADDR_WIDTH] != BASE_ADDR[31:ADDR_WIDTH]) begin
            $display("[RAM write word] Bad address: %h. Abort.\n", address);
            $finish;
        end
        mem[address[ADDR_WIDTH-1:0]] = data;
    endfunction
    //
    function void ram_v_dpi_load(string filename);
        ram_c_dpi_load(mem, filename);
    endfunction
    //--------------------------------------------------------------------------
    // unused signals: remove verilator warnings about unused signal
    wire _unused = &{mem_address[1:0]};
    //--------------------------------------------------------------------------
endmodule
