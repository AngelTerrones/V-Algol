// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : BootROM
// Project     : AlgolSoC
// Description : ROM for bootloader storage
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module mux_switch #(
                    parameter                  NSLAVES    = 4,
                    parameter [NSLAVES*32-1:0] BASE_ADDR  = 0,
                    parameter [NSLAVES*5-1:0]  ADDR_WIDTH = 0
                    )(
                      input wire [31:0]           master_address,
                      input wire [31:0]           master_wdata,
                      input wire [3:0]            master_wsel,
                      input wire                  master_valid,
                      output wire [31:0]          master_rdata,
                      output wire                 master_ready,
                      output wire                 master_error,
                      //
                      output wire [31:0]          slave_address,
                      output wire [31:0]          slave_wdata,
                      output wire [3:0]           slave_wsel,
                      output wire [NSLAVES-1:0]   slave_valid,
                      input wire [NSLAVES*32-1:0] slave_rdata,
                      input wire [NSLAVES-1:0]    slave_ready,
                      input wire [NSLAVES-1:0]    slave_error
                      );
    // =====================================================================
    localparam NBITSLAVE = clog2(NSLAVES);
    //
    reg [NBITSLAVE-1:0]  slave_sel;
    wire [NSLAVES-1:0]   match;
    // Get selected slave
    generate
        genvar i;
        for (i = 0; i < NSLAVES; i = i + 1) begin:addr_match
            localparam idx = ADDR_WIDTH[i*5+:5];
            assign match[i] = master_address[31:idx] == BASE_ADDR[i*32+idx+:32-idx];
        end
    endgenerate

    always @(*) begin
        slave_sel = 0;
        begin: slave_match
            integer idx;
            for (idx = 0; idx < NSLAVES; idx = idx + 1) begin : find_slave
                if (match[idx]) slave_sel = idx[NBITSLAVE-1:0];
            end
        end
    end

    assign slave_address = master_address;
    assign slave_wdata   = master_wdata;
    assign slave_wsel    = master_wsel;
    assign slave_valid   = match & {NSLAVES{master_valid}}; // WARNING: this should have only one bit set, or zero
    assign master_rdata  = slave_rdata[slave_sel*32+:32];
    assign master_ready  = slave_ready[slave_sel];
    assign master_error  = slave_error[slave_sel];

    // I hate ISE c:
    function integer clog2;
        input integer value;
        begin
            value = value - 1;
            for (clog2 = 0; value > 0; clog2 = clog2 + 1)
              value = value >> 1;
        end
    endfunction
    // =====================================================================
endmodule // bus
`default_nettype wire
// EOF
