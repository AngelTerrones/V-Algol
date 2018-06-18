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
// Title       : CPU testbench
// Project     : Algol
// Description : Top module for the CPU testbench
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module top #(
             parameter [31:0] HART_ID         = 0,
             parameter [31:0] RESET_ADDR      = 32'h8000_0000,
             parameter [0:0]  ENABLE_COUNTERS = 1
             )(
               input wire clk_i,
               input wire rst_i
               );
    //--------------------------------------------------------------------------
    /*AUTOWIRE*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    wire [31:0]         wbm_addr;            // From cpu of algol.v
    wire                wbm_cyc;             // From cpu of algol.v
    wire [31:0]         wbm_dat_o;           // From cpu of algol.v
    wire [31:0]         wbm_dat_i;           // From cpu of algol.v
    wire [3:0]          wbm_sel;             // From cpu of algol.v
    wire                wbm_stb;             // From cpu of algol.v
    wire                wbm_we;              // From cpu of algol.v
    // End of automatics
    wire                wbm_ack;

    algol #(/*AUTOINSTPARAM*/
            // Parameters
            .HART_ID         (HART_ID[31:0]),
            .RESET_ADDR      (RESET_ADDR[31:0]),
            .ENABLE_COUNTERS (ENABLE_COUNTERS[0:0])
            ) cpu (/*AUTOINST*/
                   // Outputs
                   .wbm_addr_o  (wbm_addr),
                   .wbm_dat_o   (wbm_dat_o),
                   .wbm_sel_o   (wbm_sel),
                   .wbm_cyc_o   (wbm_cyc),
                   .wbm_stb_o   (wbm_stb),
                   .wbm_we_o    (wbm_we),
                   // Inputs
                   .clk_i       (clk_i),
                   .rst_i       (rst_i),
                   .wbm_dat_i   (wbm_dat_i),
                   .wbm_ack_i   (wbm_ack),
                   .wbm_err_i   (0),
                   .xint_meip_i (0),
                   .xint_mtip_i (0),
                   .xint_msip_i (0));
    //
    ram #(/*AUTOINSTPARAM*/
          // Parameters
          .ADDR_WIDTH (24),
          .BASE_ADDR  (32'h8000_0000)
          ) memory (/*AUTOINST*/
                    // Outputs
                    .wbs_dat_o      (wbm_dat_i),
                    .wbs_ack_o      (wbm_ack),
                    // Inputs
                    .wbs_addr_i     (wbm_addr),
                    .wbs_dat_i      (wbm_dat_o),
                    .wbs_sel_i      (wbm_sel),
                    .wbs_cyc_i      (wbm_cyc),
                    .wbs_stb_i      (wbm_stb),
                    .wbs_we_i       (wbm_we));
    //--------------------------------------------------------------------------
endmodule

// Local Variables:
// verilog-library-directories:("." "../../hardware")
// End:
