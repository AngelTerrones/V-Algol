// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : SoC
// Project     : AlgolSoC
// Description : SoC using the Algol CPU
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module algolsoc #(
                  parameter [31:0] RESET_ADDR      = 32'h0000_0000,
                  parameter        FAST_SHIFT      = 0,
                  parameter        ENABLE_COUNTERS = 0,
                  parameter RAM_AW                 = 15,
                  parameter ROM_AW                 = 8,
                  parameter BOOTLOADER             = "bootloader.hex"
                  )(
                    input wire  clk,
                    input wire  rst,
                    output wire uart_tx,
                    input wire  uart_rx
                    );
    // =====================================================================
    wire        rst_sync;
    wire        xint_mtip;
    wire [31:0] master_address;
    wire [31:0] master_wdata;
    wire [3:0]  master_wsel;
    wire        master_valid;
    wire [31:0] master_rdata;
    wire        master_ready;
    wire        master_error;
    //
    wire [31:0] slave_address;
    wire [31:0] slave_wdata;
    wire [3:0]  slave_wsel;
    wire        slave0_valid;
    wire [31:0] slave0_rdata;
    wire        slave0_ready;
    wire        slave0_error;
    wire        slave1_valid;
    wire [31:0] slave1_rdata;
    wire        slave1_ready;
    wire        slave1_error;
    wire        slave2_valid;
    wire [31:0] slave2_rdata;
    wire        slave2_ready;
    wire        slave2_error;
    wire        slave3_valid;
    wire [31:0] slave3_rdata;
    wire        slave3_ready;
    wire        slave3_error;

    rst_generator rst_gen (// Outputs
                           .rst_sync  (rst_sync),
                           // Inputs
                           .clk       (clk),
                           .rst_async (rst)
                           );

    algol #(// Parameters
            .HART_ID         (0),
            .RESET_ADDR      (RESET_ADDR),
            .FAST_SHIFT      (FAST_SHIFT),
            .ENABLE_COUNTERS (ENABLE_COUNTERS)
            ) algol0 (// Outputs
                      .mem_address (master_address[31:0]),
                      .mem_wdata   (master_wdata[31:0]  ),
                      .mem_wsel    (master_wsel[3:0]    ),
                      .mem_valid   (master_valid        ),
                      // Inputs
                      .clk         (clk                 ),
                      .rst         (rst_sync            ),
                      .mem_rdata   (master_rdata[31:0]  ),
                      .mem_ready   (master_ready        ),
                      .mem_error   (master_error        ),
                      .xint_meip   (0                   ),
                      .xint_mtip   (xint_mtip           ),
                      .xint_msip   (0                   )
                      );

    mux_switch #(// Parameters
                 .NSLAVES    (4),
                 //            3              2              1              0
                 .BASE_ADDR  ({32'h2001_0000, 32'h2000_0000, 32'h1000_0000, 32'h0000_0000}),
                 .ADDR_WIDTH ({5'd8,          5'd8,          5'd16,         5'd8})
                 ) bus0 (// Outputs
                         .master_rdata   (master_rdata[31:0]                                      ),
                         .master_ready   (master_ready                                            ),
                         .master_error   (master_error                                            ),
                         .slave_address  (slave_address[31:0]                                     ),
                         .slave_wdata    (slave_wdata[31:0]                                       ),
                         .slave_wsel     (slave_wsel[3:0]                                         ),
                         .slave_valid    ({slave3_valid, slave2_valid, slave1_valid, slave0_valid}),
                         // Inputs
                         .master_address (master_address[31:0]                                    ),
                         .master_wdata   (master_wdata[31:0]                                      ),
                         .master_wsel    (master_wsel[3:0]                                        ),
                         .master_valid   (master_valid                                            ),
                         .slave_rdata    ({slave3_rdata, slave2_rdata, slave1_rdata, slave0_rdata}),
                         .slave_ready    ({slave3_ready, slave2_ready, slave1_ready, slave0_ready}),
                         .slave_error    ({slave3_error, slave2_error, slave1_error, slave0_error})
                         );

    bootrom #(// Parameters
              .ROM_AW     (ROM_AW),
              .BOOTLOADER (BOOTLOADER)
              ) bootrom0 (// Outputs
                          .rom_rdata   (slave0_rdata[31:0] ),
                          .rom_ready   (slave0_ready       ),
                          .rom_error   (slave0_error       ),
                          // Inputs
                          .clk         (clk                ),
                          .rst         (rst_sync           ),
                          .rom_address (slave_address[31:0]),
                          .rom_valid   (slave0_valid       )
                          );

    ram #(// Parameters
          .RAM_AW (RAM_AW)
          ) ram0 (// Outputs
                  .ram_rdata   (slave1_rdata[31:0] ),
                  .ram_ready   (slave1_ready       ),
                  .ram_error   (slave1_error       ),
                  // Inputs
                  .clk         (clk                ),
                  .rst         (rst_sync           ),
                  .ram_address (slave_address[31:0]),
                  .ram_wdata   (slave_wdata[31:0]  ),
                  .ram_wsel    (slave_wsel[3:0]    ),
                  .ram_valid   (slave1_valid       )
                  );

    timer timer0 (// Outputs
                  .timer_rdata   (slave2_rdata[31:0] ),
                  .timer_ready   (slave2_ready       ),
                  .timer_error   (slave2_error       ),
                  .xint_mtip     (xint_mtip          ),
                  // Inputs
                  .clk           (clk                ),
                  .rst           (rst_sync           ),
                  .timer_address (slave_address[31:0]),
                  .timer_wdata   (slave_wdata[31:0]  ),
                  .timer_wsel    (slave_wsel[3:0]    ),
                  .timer_valid   (slave2_valid       )
                  );

    uart uart0 (// Outputs
                .uart_rdata   (slave3_rdata[31:0] ),
                .uart_ready   (slave3_ready       ),
                .uart_error   (slave3_error       ),
                .uart_tx      (uart_tx            ),
                // Inputs
                .clk          (clk                ),
                .rst          (rst_sync           ),
                .uart_address (slave_address[31:0]),
                .uart_wdata   (slave_wdata[31:0]  ),
                .uart_wsel    (slave_wsel[3:0]    ),
                .uart_valid   (slave3_valid       ),
                .uart_rx      (uart_rx            )
                );
    // =====================================================================
endmodule // algolsoc
`default_nettype wire
// Local Variables:
// verilog-library-directories:("." "../hardware")
// End:
