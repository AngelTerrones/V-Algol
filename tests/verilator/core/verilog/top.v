// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : CPU testbench
// Project     : Algol
// Description : Top module for the CPU testbench
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module top #(
             parameter [31:0] HART_ID         = 0,
             parameter [31:0] RESET_ADDR      = 32'h8000_0000,
             parameter [0:0]  ENABLE_COUNTERS = 1,
             parameter [31:0] MEM_SIZE        = 32'h0100_0000
             )(
               input wire clk,
               input wire rst,
               input wire xint_meip,
               input wire xint_mtip,
               input wire xint_msip
               );
    //--------------------------------------------------------------------------
    localparam ADDR_WIDTH = $clog2(MEM_SIZE);
    localparam BASE_ADDR  = RESET_ADDR;
    /*AUTOWIRE*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    wire [31:0]         mem_address;            // From cpu of algol.v
    wire                mem_error;              // From memory of ram.v
    wire [31:0]         mem_rdata;              // From memory of ram.v
    wire                mem_ready;              // From memory of ram.v
    wire                mem_valid;              // From cpu of algol.v
    wire [31:0]         mem_wdata;              // From cpu of algol.v
    wire [3:0]          mem_wsel;               // From cpu of algol.v
    // End of automatics

    algol #(/*AUTOINSTPARAM*/
            // Parameters
            .HART_ID         (HART_ID[31:0]),
            .RESET_ADDR      (RESET_ADDR[31:0])
            ) cpu (/*AUTOINST*/
                   // Outputs
                   .mem_address       (mem_address[31:0]),
                   .mem_wdata         (mem_wdata[31:0]),
                   .mem_wsel          (mem_wsel[3:0]),
                   .mem_valid         (mem_valid),
                   // Inputs
                   .clk               (clk),
                   .rst               (rst),
                   .mem_rdata         (mem_rdata[31:0]),
                   .mem_ready         (mem_ready),
                   .mem_error         (mem_error),
                   .xint_meip         (xint_meip),
                   .xint_mtip         (xint_mtip),
                   .xint_msip         (xint_msip));
    //
    ram #(/*AUTOINSTPARAM*/
          // Parameters
          .ADDR_WIDTH (ADDR_WIDTH),
          .BASE_ADDR  (BASE_ADDR)
          ) memory (/*AUTOINST*/
                    // Outputs
                    .mem_rdata         (mem_rdata[31:0]),
                    .mem_ready         (mem_ready),
                    .mem_error         (mem_error),
                    // Inputs
                    .clk               (clk),
                    .mem_address       (mem_address[31:0]),
                    .mem_wdata         (mem_wdata[31:0]),
                    .mem_wsel          (mem_wsel[3:0]),
                    .mem_valid         (mem_valid));
    //--------------------------------------------------------------------------
endmodule

// Local Variables:
// verilog-library-directories:("." "../../../hardware")
// End:
