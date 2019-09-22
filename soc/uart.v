// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : UART
// Project     : AlgolSoC
// Description : Serial Tx/Rx
//               Adapted from picosoc
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

module uart (
             input wire        clk,
             input wire        rst,
             input wire [31:0] uart_address,
             input wire [31:0] uart_wdata,
             input wire [ 3:0] uart_wsel,
             input wire        uart_valid,
             output reg [31:0] uart_rdata,
             output reg        uart_ready,
             output reg        uart_error,
             //
             input wire        uart_rx,
             output wire       uart_tx
             );
    // =====================================================================
    reg [31:0] clk_cfg;  // 0
    reg [7:0]  tx_data;  // 4
    reg [7:0]  rx_data;  // 8
    reg        tx_done, rx_done; //12, b0, b1
    reg [9:0]  tx_pattern;
    wire       is_clk_cfg, is_tx_data, is_rx_data, is_status;
    //
    assign is_clk_cfg = uart_address[3:0] == 4'b0000;
    assign is_tx_data = uart_address[3:0] == 4'b0100;
    assign is_rx_data = uart_address[3:0] == 4'b1000;
    assign is_status  = uart_address[3:0] == 4'b1100;
    // read
    always @(posedge clk) begin
        (* parallel_case *)
        case (1'b1)
            is_clk_cfg: uart_rdata <= clk_cfg;
            is_tx_data: uart_rdata <= {24'b0, tx_data};
            is_rx_data: uart_rdata <= {24'b0, rx_data};
            is_status:  uart_rdata <= {30'b0, rx_done, tx_done};
            default:    uart_rdata <= 32'bx;
        endcase
    end
    // write
    always @(posedge clk or posedge rst) begin
        if (uart_valid && uart_ready && (&uart_wsel)) begin
            (* parallel_case *)
            case (1'b1)
                is_clk_cfg: clk_cfg <= uart_wdata;
                is_tx_data: tx_data <= uart_wdata[7:0];
            endcase
        end
        if (rst) begin
            clk_cfg <= 1; // Max baudrate
        end
    end
    // handshake
    always @(*) begin
        uart_error = 0; // TODO: assert error for unaligned access?
    end
    always @(posedge clk or posedge rst) begin
        uart_ready <= uart_valid && !(|uart_address[1:0]);
        if (rst) uart_ready <= 0;
    end
    // Rx
    reg [3:0]  rx_state;
    reg [7:0]  rx_buffer;
    reg [31:0] rx_div_cnt;
    reg [1:0]  uart_rx_sync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state     <= 0;
            rx_div_cnt   <= 0;
            rx_buffer    <= 0;
            rx_done      <= 0;
            uart_rx_sync <= -1;
        end else begin
            uart_rx_sync <= {uart_rx, uart_rx_sync[1]};
            rx_div_cnt <= rx_div_cnt + 1;
            if (uart_ready && uart_valid && |uart_wsel && is_status) begin
                rx_done <= 0;
            end
            case (rx_state)
                4'd0: begin
                    rx_div_cnt <= 0;
                    if (uart_rx_sync == 0) rx_state <= 1;
                end
                4'd1: begin // middle of START BIT
                    if (2*rx_div_cnt > clk_cfg) begin
                        rx_state   <= 2;
                        rx_div_cnt <= 0;
                    end
                end
                4'd10: begin // STOP bit
                    if (rx_div_cnt > clk_cfg) begin
                        rx_data  <= rx_buffer;
                        rx_state <= 0;
                        rx_done  <= 1;
                    end
                end
                default: begin
                    if (rx_div_cnt > clk_cfg) begin
                        rx_buffer  <= {uart_rx_sync[0], rx_buffer[7:1]};
                        rx_state   <= rx_state + 1;
                        rx_div_cnt <= 0;
                    end
                end
            endcase
        end
    end
    // Tx
    reg [3:0]  bitcnt;
    reg [31:0] tx_div_cnt;
    reg        tx_start;
    reg        init;
    assign uart_tx = tx_pattern[0];

    always @(posedge clk or posedge rst) begin
        tx_div_cnt <= tx_div_cnt + 1;
        tx_start <= uart_valid && uart_ready && is_tx_data && (&uart_wsel);

        if (rst) begin
            tx_pattern <= -1;
            bitcnt     <= 0;
            tx_div_cnt <= 0;
            tx_done    <= 0;
            init       <= 1;
        end else begin
            if (init && (bitcnt == 0)) begin
                tx_pattern <= -1;
                bitcnt     <= -1;
                tx_div_cnt <= 0;
                init       <= 0;
            end
            if (tx_start && (bitcnt == 0)) begin
                tx_pattern <= {1'b1, tx_data, 1'b0};
                bitcnt     <= 10;
                tx_div_cnt <= 0;
                tx_done    <= 0;
            end
            if (tx_div_cnt > clk_cfg && |bitcnt) begin
                tx_pattern <= {1'b1, tx_pattern[9:1]};
                bitcnt     <= bitcnt - 1;
                tx_div_cnt <= 0;
                tx_done    <= bitcnt == 1;
            end
        end
    end
    // =====================================================================
    // unused signals: remove verilator warnings about unused signal
    wire _unused = &{uart_address};
    // =====================================================================
endmodule
`default_nettype wire
// EOF
