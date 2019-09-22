// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : system reset generator
// Project     : AlgolSoC
// Description : Debounce and Synchronize the reset signal
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module rst_generator (
                      input wire clk,
                      input wire rst_async,
                      output reg rst_sync
                      );
    // =====================================================================
    reg [1:0] sync_rst;

    initial sync_rst = 2'b11;
    initial rst_sync = 1'b1;

    always @(posedge clk) begin
        {rst_sync, sync_rst} <= {sync_rst, rst_async};
    end
    // =====================================================================
endmodule
`default_nettype wire
// EOF
