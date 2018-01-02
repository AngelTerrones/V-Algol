/*
 * Algol - A RISC-V (RV32I) Processor Core.
 *
 * Copyright (C) 2017 Angel Terrones <angelterrones@gmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

`default_nettype none
`timescale 1 ns / 1 ps

module algol #(
               parameter [31:0] HART_ID = 0,
               parameter [31:0] RESET_ADDR = 32'h0000_0000,
               parameter [0:0]  ENABLE_COUNTERS = 0
               )(
                 input wire        clk_i,
                 input wire        rst_i,
                 // wishbone instruction and data port
                 output reg [31:0] wbm_addr_o,
                 output reg [31:0] wbm_dat_o,
                 output reg [ 3:0] wbm_sel_o,
                 output reg        wbm_cyc_o,
                 output reg        wbm_stb_o,
                 output reg        wbm_we_o,
                 input wire [31:0] wbm_dat_i,
                 input wire        wbm_ack_i,
                 input wire        wbm_err_i,
                 // external interrupts interface
                 input wire        xint_meip_i,
                 input wire        xint_mtip_i,
                 input wire        xint_msip_i
                 );
    // ---------------------------------------------------------------------
    // State machine
    localparam cpu_state_reset   = 10'b0000000001;
    localparam cpu_state_fetch   = 10'b0000000010;
    localparam cpu_state_decode  = 10'b0000000100;
    localparam cpu_state_execute = 10'b0000001000;
    localparam cpu_state_shift   = 10'b0000010000;
    localparam cpu_state_ld      = 10'b0000100000;
    localparam cpu_state_st      = 10'b0001000000;
    localparam cpu_state_csr     = 10'b0010000000;
    localparam cpu_state_wb      = 10'b0100000000;
    localparam cpu_state_trap    = 10'b1000000000;
    // CSR
    localparam CYCLE      = 12'hC00;
    localparam INSTRET    = 12'hC02;
    localparam CYCLEH     = 12'hC80;
    localparam INSTRETH   = 12'hC82;
    localparam MVENDORID  = 12'hF11;
    localparam MARCHID    = 12'hF12;
    localparam MIMPID     = 12'hF13;
    localparam MHARTID    = 12'hF14;
    localparam MSTATUS    = 12'h300;
    localparam MISA       = 12'h301;
    localparam MEDELEG    = 12'h302;
    localparam MIDELEG    = 12'h303;
    localparam MIE        = 12'h304;
    localparam MTVEC      = 12'h305;
    localparam MCOUNTEREN = 12'h306;
    localparam MSCRATCH   = 12'h340;
    localparam MEPC       = 12'h341;
    localparam MCAUSE     = 12'h342;
    localparam MTVAL      = 12'h343;
    localparam MIP        = 12'h344;
    localparam MCYCLE     = 12'hB00;
    localparam MINSTRET   = 12'hB02;
    localparam MCYCLEH    = 12'hB80;
    localparam MINSTRETH  = 12'hB82;
    //
    localparam E_INST_ADDR_MISALIGNED      = 4'd0;
    localparam E_INST_ACCESS_FAULT         = 4'd1;
    localparam E_ILLEGAL_INST              = 4'd2;
    localparam E_BREAKPOINT                = 4'd3;
    localparam E_LOAD_ADDR_MISALIGNED      = 4'd4;
    localparam E_LOAD_ACCESS_FAULT         = 4'd5;
    localparam E_STORE_AMO_ADDR_MISALIGNED = 4'd6;
    localparam E_STORE_AMO_ACCESS_FAULT    = 4'd7;
    localparam E_ECALL_FROM_U              = 4'd8;
    localparam E_ECALL_FROM_S              = 4'd9;
    localparam E_ECALL_FROM_M              = 4'd11;
    localparam I_U_SOFTWARE                = 4'd0;
    localparam I_S_SOFTWARE                = 4'd1;
    localparam I_M_SOFTWARE                = 4'd3;
    localparam I_U_TIMER                   = 4'd4;
    localparam I_S_TIMER                   = 4'd5;
    localparam I_M_TIMER                   = 4'd7;
    localparam I_U_EXTERNAL                = 4'd8;
    localparam I_S_EXTERNAL                = 4'd9;
    localparam I_M_EXTERNAL                = 4'd11;
    //
    localparam PRIV_U = 2'b00;
    localparam PRIV_S = 2'b01;
    localparam PRIV_M = 2'b11;
    // ---------------------------------------------------------------------
    // Signals
    reg [9:0]   cpu_state;
    reg [31:0]  pc;
    reg [31:0]  next_pc;
    reg [31:0]  pc_jal;
    reg [31:0]  pc_jalr;
    reg [31:0]  pc_branch;
    reg [31:0]  pc_u;
    reg [31:0]  pc_4;
    // instuction decode
    wire [31:0] instruction_q;
    // verilator lint_off UNUSED
    reg [31:0]  instruction_r;
    // verilator lint_on UNUSED
    reg [31:0]  imm_i, imm_s, imm_b, imm_u, imm_j;
    // instructions
    reg         latch_instruction;
    reg         inst_lui, inst_auipc;
    reg         inst_jal, inst_jalr;
    reg         inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu;
    reg         inst_lb, inst_lh, inst_lw, inst_lbu, inst_lhu;
    reg         inst_sb, inst_sh, inst_sw;
    reg         inst_addi, inst_slti, inst_sltiu, inst_xori, inst_ori, inst_andi, inst_slli, inst_srli, inst_srai;
    reg         inst_add, inst_sub, inst_sll, inst_slt, inst_sltu, inst_xor, inst_srl, inst_sra, inst_or, inst_and;
    reg         inst_fence;
    reg         inst_csrrw, inst_csrrs, inst_csrrc, inst_csrrwi, inst_csrrsi, inst_csrrci;
    reg         inst_xcall, inst_xbreak, inst_xret;
    reg         is_j, is_b, is_l, is_s, is_alu, is_csr, is_csrx, is_csrs, is_csrc;
    // register file -----------------------------------------------------------
    wire [4:0]  rs1, rs2;
    reg [4:0]   rd;
    reg [31:0]  rs1_d, rs2_d, rf_wd;
    reg         rf_we, latch_rf;
    reg [31:0]  regfile [0:31];
    // branch ------------------------------------------------------------------
    reg         is_eq, is_lt, is_ltu, take_branch;
    // ALU ---------------------------------------------------------------------
    reg [31:0]  alu_a, alu_b, alu_out, alu_add_sub, shift_out;
    reg         alu_cmp, is_add_sub, is_shift, is_cmp;
    reg [4:0]   shamt;
    reg         shift_busy;
    reg         is_xor, is_or, is_and;
    // CSR ---------------------------------------------------------------------
    reg [11:0]  csr_address;
    reg [31:0]  csr_dat_o, csr_dat_i, exc_data;
    wire        undef_register;
    // CSR registers
    reg [1:0]   priv_mode;
    wire [31:0] mstatus;
    wire [31:0] mie;
    reg [31:0]  mtvec;
    reg [31:0]  mscratch;
    reg [31:0]  mepc;
    wire [31:0] mcause;
    reg [31:0]  mtval;
    wire [31:0] mip;
    reg [63:0]  cycle;
    reg [63:0]  instret;
    // msatus fields
    reg [1:0]   mstatus_mpp;
    reg         mstatus_mpie;
    reg         mstatus_mie;
    // mie fields
    reg         mie_meie, mie_mtie, mie_msie;
    // mcause
    reg         mcause_interrupt;
    reg [3:0]   mcause_mecode, e_code;
    // access check
    reg         priv_valid, illegal_access;
    reg         is_misa, is_mhartid, is_mvendorid, is_marchid, is_mimpid, is_mstatus, is_mie, is_mtvec, is_mscratch, is_mepc;
    reg         is_mcause, is_mtval, is_mip, is_cycle, is_instret, is_cycleh, is_instreth;
    // extra
    // verilator lint_off UNUSED
    reg [31:0]  pend_int;
    // verilator lint_off UNUSED
    reg         csr_wen;
    reg [31:0]  csr_wdata;
    reg         csr_wcmd, csr_scmd, csr_ccmd; // CSR commands: read/write, set, clear
    reg         exception, interrupt, trap_valid;
    // for memory access
    reg [31:0]  mdat_o, mdat_i, ld_addr, st_addr;
    reg [3:0]   msel_o;
    reg         ld_misalign, st_misalign;
    // ---------------------------------------------------------------------
    // Decoder
    assign instruction_q = wbm_dat_i;
    // decode instuctions
    always @(posedge clk_i) begin
        if (rst_i) begin
            // verilator lint_off BLKSEQ
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            csr_address <= 12'h0;
            imm_b        = 32'h0;
            imm_i        = 32'h0;
            imm_j        = 32'h0;
            imm_s        = 32'h0;
            imm_u        = 32'h0;
            inst_add     = 1'h0;
            inst_addi    = 1'h0;
            inst_and     = 1'h0;
            inst_andi    = 1'h0;
            inst_auipc   = 1'h0;
            inst_beq     = 1'h0;
            inst_bge     = 1'h0;
            inst_bgeu    = 1'h0;
            inst_blt     = 1'h0;
            inst_bltu    = 1'h0;
            inst_bne     = 1'h0;
            inst_csrrc   = 1'h0;
            inst_csrrci  = 1'h0;
            inst_csrrs   = 1'h0;
            inst_csrrsi  = 1'h0;
            inst_csrrw   = 1'h0;
            inst_csrrwi  = 1'h0;
            inst_fence   = 1'h0;
            inst_jal     = 1'h0;
            inst_jalr    = 1'h0;
            inst_lb      = 1'h0;
            inst_lbu     = 1'h0;
            inst_lh      = 1'h0;
            inst_lhu     = 1'h0;
            inst_lui     = 1'h0;
            inst_lw      = 1'h0;
            inst_or      = 1'h0;
            inst_ori     = 1'h0;
            inst_sb      = 1'h0;
            inst_sh      = 1'h0;
            inst_sll     = 1'h0;
            inst_slli    = 1'h0;
            inst_slt     = 1'h0;
            inst_slti    = 1'h0;
            inst_sltiu   = 1'h0;
            inst_sltu    = 1'h0;
            inst_sra     = 1'h0;
            inst_srai    = 1'h0;
            inst_srl     = 1'h0;
            inst_srli    = 1'h0;
            inst_sub     = 1'h0;
            inst_sw      = 1'h0;
            inst_xbreak  = 1'h0;
            inst_xcall   = 1'h0;
            inst_xor     = 1'h0;
            inst_xori    = 1'h0;
            inst_xret    = 1'h0;
            is_add_sub  <= 1'h0;
            is_alu      <= 1'h0;
            is_and      <= 1'h0;
            is_b        <= 1'h0;
            is_cmp      <= 1'h0;
            is_csr      <= 1'h0;
            is_csrc     <= 1'h0;
            is_csrs     <= 1'h0;
            is_csrx     <= 1'h0;
            is_j        <= 1'h0;
            is_l        <= 1'h0;
            is_or       <= 1'h0;
            is_s        <= 1'h0;
            is_shift    <= 1'h0;
            is_xor      <= 1'h0;
            rd          <= 5'h0;
            // End of automatics
            // verilator lint_off BLKSEQ
        end else if (latch_instruction) begin
            inst_lui     = instruction_q[6:0] == 7'b0110111;
            inst_auipc   = instruction_q[6:0] == 7'b0010111;
            //
            inst_jal     = instruction_q[6:0] == 7'b1101111;
            inst_jalr    = instruction_q[6:0] == 7'b1100111;
            //
            inst_beq     = instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b000;
            inst_bne     = instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b001;
            inst_blt     = instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b100;
            inst_bge     = instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b101;
            inst_bltu    = instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b110;
            inst_bgeu    = instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b111;
            //
            inst_lb      = instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b000;
            inst_lh      = instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b001;
            inst_lw      = instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b010;
            inst_lbu     = instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b100;
            inst_lhu     = instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b101;
            //
            inst_sb      = instruction_q[6:0] == 7'b0100011 && instruction_q[14:12] == 3'b000;
            inst_sh      = instruction_q[6:0] == 7'b0100011 && instruction_q[14:12] == 3'b001;
            inst_sw      = instruction_q[6:0] == 7'b0100011 && instruction_q[14:12] == 3'b010;
            //
            inst_addi    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b000;
            inst_slti    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b010;
            inst_sltiu   = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b011;
            inst_xori    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b100;
            inst_ori     = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b110;
            inst_andi    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b111;
            inst_slli    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b001 && instruction_q[31:25] == 7'b0000000;
            inst_srli    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0000000;
            inst_srai    = instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0100000;
            //
            inst_add     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b000 && instruction_q[31:25] == 7'b0000000;
            inst_sub     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b000 && instruction_q[31:25] == 7'b0100000;
            inst_sll     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b001 && instruction_q[31:25] == 7'b0000000;
            inst_slt     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b010 && instruction_q[31:25] == 7'b0000000;
            inst_sltu    = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b011 && instruction_q[31:25] == 7'b0000000;
            inst_xor     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b100 && instruction_q[31:25] == 7'b0000000;
            inst_srl     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0000000;
            inst_sra     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0100000;
            inst_or      = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b110 && instruction_q[31:25] == 7'b0000000;
            inst_and     = instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b111 && instruction_q[31:25] == 7'b0000000;
            //
            inst_fence   = instruction_q[6:0] == 7'b0001111;
            //
            inst_csrrw   = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b001;
            inst_csrrs   = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b010;
            inst_csrrc   = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b011;
            inst_csrrwi  = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b101;
            inst_csrrsi  = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b110;
            inst_csrrci  = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b111;
            //inst_system  = instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b000;
            inst_xcall   = instruction_q[6:0] == 7'b1110011 && instruction_q[31:7] == 0;
            inst_xbreak  = instruction_q[6:0] == 7'b1110011 && instruction_q[31:7] == 25'b0000000000010000000000000;
            inst_xret    = instruction_q[6:0] == 7'b1110011 && instruction_q[31:30] == 2'b0 && instruction_q[27:7] == 21'b000000100000000000000 && priv_mode >= instruction_q[29:28];
            //
            is_j        <= |{inst_jal, inst_jalr};
            is_b        <= |{inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu};
            is_l        <= |{inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw};
            is_s        <= |{inst_sb, inst_sh, inst_sw};
            is_csr      <= |{inst_csrrw, inst_csrrs, inst_csrrc, inst_csrrwi, inst_csrrsi, inst_csrrci};
            is_alu      <= |{inst_addi, inst_slti,inst_sltiu, inst_xori, inst_ori, inst_andi,
                             inst_add, inst_sub, inst_slt, inst_sltu, inst_xor, inst_or, inst_and};
            // verilator lint_off WIDTH
            imm_i        = $signed(instruction_q[31:20]);
            imm_s        = $signed({instruction_q[31:25], instruction_q[11:7]});
            imm_b        = $signed({instruction_q[31], instruction_q[7], instruction_q[30:25], instruction_q[11:8], 1'b0});
            imm_u        = {instruction_q[31:12], {12{1'b0}}};
            imm_j        = $signed({instruction_q[31], instruction_q[19:12], instruction_q[20], instruction_q[30:21], 1'b0});
            // verilator lint_on WIDTH
            //is_csr_sc   <= |{inst_csrrc, inst_csrrs, inst_csrrci, inst_csrrsi};
            is_csrs     <= |{inst_csrrs, inst_csrrsi};
            is_csrc     <= |{inst_csrrc, inst_csrrci};
            is_csrx     <= |{inst_csrrw, inst_csrrc, inst_csrrs};
            csr_address <= instruction_q[31:20];
            rd          <= instruction_q[11:7];
            //
            is_add_sub  <= |{inst_add, inst_addi, inst_sub};
            is_shift    <= |{inst_slli, inst_sll, inst_srli, inst_srl, inst_srai, inst_sra};
            is_cmp      <= |{inst_slti, inst_slt, inst_sltiu, inst_sltu};
            is_xor      <= inst_xori || inst_xor;
            is_or       <= inst_ori || inst_or;
            is_and      <= inst_andi || inst_and;
            //
            pc_jal       = pc + imm_j;
            pc_branch    = pc + imm_b;
            pc_u         = pc + imm_u;
            pc_4         = pc + 4;
        end
    end
    // ---------------------------------------------------------------------
    // State machine
    reg [3:0] latched_csr;
    reg [3:0] decode_delay;

    always @(posedge clk_i) begin
        if (rst_i) begin
            cpu_state         <= cpu_state_reset;
            pc                <= RESET_ADDR;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            csr_dat_i         <= 32'h0;
            e_code            <= 4'h0;
            instruction_r     <= 32'h0;
            latch_instruction <= 1'h0;
            latch_rf          <= 1'h0;
            rf_we             <= 1'h0;
            shamt             <= 5'h0;
            shift_busy        <= 1'h0;
            shift_out         <= 32'h0;
            trap_valid        <= 1'h0;
            // End of automatics
        end else begin
            exc_data <= pc;
            (* parallel_case, full_case *)
            case ( cpu_state )
                // -------------------------------------------------------------
                cpu_state_reset: begin
                    latch_rf          <= 1'b0;
                    latch_instruction <= 1'b1;
                    cpu_state <= cpu_state_fetch;
                end
                cpu_state_fetch: begin
                    rf_we <= 0;
                    (* parallel_case *)
                    case (1'b1)
                        pc[1:0] != 0: begin
                            instruction_r <= instruction_q;
                            trap_valid    <= 1;
                            e_code        <= E_INST_ADDR_MISALIGNED;
                            cpu_state     <= cpu_state_trap;
                        end
                        wbm_err_i: begin
                            instruction_r <= instruction_q;
                            trap_valid    <= 1;
                            e_code        <= E_INST_ACCESS_FAULT;
                            cpu_state     <= cpu_state_decode;
                        end
                        wbm_ack_i: begin
                            instruction_r     <= instruction_q;
                            latch_rf          <= 1'b1;
                            latch_instruction <= 1'b0;
                            cpu_state         <= cpu_state_decode;
                        end
                    endcase
                end
                // -------------------------------------------------------------
                cpu_state_decode: begin
                    (* parallel_case*)
                    case (1'b1)
                        is_shift: cpu_state <= cpu_state_shift;
                        is_alu: cpu_state   <= cpu_state_execute;
                        is_l: begin
                            exc_data <= ld_addr;
                            e_code   <= E_LOAD_ADDR_MISALIGNED;
                            if (decode_delay[1]) begin
                                cpu_state <= cpu_state_ld;
                                if (ld_misalign) begin
                                    trap_valid <= 1;
                                    cpu_state  <= cpu_state_trap;
                                end
                            end
                        end
                        is_s: begin
                            exc_data <= st_addr;
                            e_code   <= E_STORE_AMO_ADDR_MISALIGNED;
                            if (decode_delay[1]) begin
                                cpu_state <= cpu_state_st;
                                if (st_misalign) begin
                                    trap_valid <= 1;
                                    cpu_state  <= cpu_state_trap;
                                end
                            end
                        end
                        inst_fence: begin
                            latch_instruction <= 1'b1;
                            latch_rf          <= 1'b0;
                            pc                <= pc_4;
                            cpu_state         <= cpu_state_fetch;
                        end
                        inst_lui: begin
                            rf_we     <= 1;
                            cpu_state <= cpu_state_wb;
                        end
                        inst_jal: begin
                            exc_data <= pc_jal;
                            e_code   <= E_INST_ADDR_MISALIGNED;
                            if (pc_jal[1:0] != 0) begin
                                trap_valid <= 1;
                                cpu_state  <= cpu_state_trap;
                            end else begin
                                rf_we     <= 1;
                                cpu_state <= cpu_state_wb;
                            end
                        end
                        inst_jalr: begin
                            exc_data <= pc_jalr;
                            e_code   <= E_INST_ADDR_MISALIGNED;
                            if (decode_delay[0]) begin
                                if (pc_jalr[1:0] != 0) begin
                                    trap_valid <= 1;
                                    cpu_state  <= cpu_state_trap;
                                end else begin
                                    rf_we     <= 1;
                                    cpu_state <= cpu_state_wb;
                                end
                            end
                        end
                        is_b: begin
                            exc_data <= pc_branch;
                            e_code   <= E_INST_ADDR_MISALIGNED;
                            if (decode_delay[1]) begin
                                cpu_state <= cpu_state_wb;
                                if (take_branch) begin
                                    if (pc_branch[1:0] != 0) begin
                                        trap_valid <= 1;
                                        cpu_state  <= cpu_state_trap;
                                    end
                                end
                            end
                        end
                        is_csr: begin
                            csr_dat_i <= is_csrx ? rs1_d : {27'b0, rs1};
                            cpu_state <= cpu_state_csr;
                        end
                        inst_auipc: begin
                            rf_we     <= 1;
                            cpu_state <= cpu_state_wb;
                        end
                        inst_xret: begin
                            latch_instruction <= 1'b1;
                            latch_rf          <= 1'b0;
                            pc                <= mepc;
                            cpu_state         <= cpu_state_fetch;
                        end
                        interrupt: begin
                            (* parallel_case *)
                            case (1'b1)
                                // verilator lint_off WIDTH
                                pend_int[11]: e_code <= I_U_EXTERNAL + priv_mode;
                                pend_int[7]:  e_code <= I_U_TIMER + priv_mode;
                                pend_int[3]:  e_code <= I_U_SOFTWARE + priv_mode;
                                // verilator lint_on WIDTH
                            endcase
                            trap_valid <= 1;
                            cpu_state  <= cpu_state_trap;
                        end
                        default: begin
                            trap_valid <= 1;
                            exc_data   <= instruction_r;
                            (* parallel_case *)
                            case (1'b1)
                                // verilator lint_off WIDTH
                                inst_xcall:  e_code <= E_ECALL_FROM_U + priv_mode;
                                // verilator lint_on WIDTH
                                inst_xbreak: e_code <= E_BREAKPOINT;
                                default:     e_code <= E_ILLEGAL_INST;
                            endcase
                            cpu_state <= cpu_state_trap;
                        end
                    endcase
                end
                // -------------------------------------------------------------
                cpu_state_execute: begin
                    rf_we     <= 1;
                    cpu_state <= cpu_state_wb;
                end
                // -------------------------------------------------------------
                cpu_state_shift: begin
                    if (shift_busy == 0) begin
                        shift_out  <= alu_a;
                        shamt      <= alu_b[4:0];
                        shift_busy <= 1;
                    end else if (shamt >= 4) begin
                        (* parallel_case *)
                        case (1'b1)
                            |{inst_slli, inst_sll}: shift_out <= shift_out << 4;
                            |{inst_srli, inst_srl}: shift_out <= shift_out >> 4;
                            |{inst_srai, inst_sra}: shift_out <= $signed(shift_out) >>> 4;
                        endcase
                        shamt <= shamt - 4;
                    end else if (shamt > 0) begin
                        (* parallel_case *)
                        case (1'b1)
                            |{inst_slli, inst_sll}: shift_out <= shift_out << 1;
                            |{inst_srli, inst_srl}: shift_out <= shift_out >> 1;
                            |{inst_srai, inst_sra}: shift_out <= $signed(shift_out) >>> 1;
                        endcase
                        shamt <= shamt - 1;
                    end else begin
                        shift_busy  <= 0;
                        rf_we       <= 1;
                        cpu_state   <= cpu_state_wb;
                    end
                end
                // -------------------------------------------------------------
                cpu_state_ld: begin
                    (* parallel_case *)
                    case (1'b1)
                        wbm_err_i: begin
                            trap_valid <= 1;
                            exc_data   <= ld_addr;
                            e_code     <= E_LOAD_ACCESS_FAULT;
                            cpu_state  <= cpu_state_trap;
                        end
                        wbm_ack_i: begin
                            rf_we     <= 1;
                            cpu_state <= cpu_state_wb;
                        end
                    endcase
                end
                // -------------------------------------------------------------
                cpu_state_st: begin
                    (* parallel_case *)
                    case (1'b1)
                        wbm_err_i: begin
                            trap_valid <= 1;
                            exc_data   <= st_addr;
                            e_code     <= E_STORE_AMO_ACCESS_FAULT;
                            cpu_state  <= cpu_state_trap;
                        end
                        wbm_ack_i: begin
                            latch_instruction <= 1'b1;
                            latch_rf          <= 1'b0;
                            pc                <= next_pc;
                            cpu_state         <= cpu_state_fetch;
                        end
                    endcase
                end
                // -------------------------------------------------------------
                cpu_state_csr: begin
                    if (latched_csr[1]) begin
                        if (illegal_access) begin
                            trap_valid <= 1;
                            exc_data   <= instruction_r;
                            e_code     <= E_ILLEGAL_INST;
                            cpu_state  <= cpu_state_trap;
                        end else begin
                            rf_we     <= 1;
                            cpu_state <= cpu_state_wb;
                        end
                    end
                end
                // -------------------------------------------------------------
                cpu_state_trap: begin
                    latch_instruction <= 1'b1;
                    latch_rf          <= 1'b0;
                    trap_valid        <= 0;
                    pc                <= mtvec;
                    cpu_state         <= cpu_state_fetch;
                end
                cpu_state_wb: begin
                    latch_instruction <= 1'b1;
                    latch_rf          <= 1'b0;
                    rf_we             <= 0;
                    pc                <= next_pc;
                    cpu_state         <= cpu_state_fetch;
                end
                // -------------------------------------------------------------
                default: begin
                    pc                <= RESET_ADDR;
                    cpu_state         <= cpu_state_reset;
                end
            endcase
        end
    end
    // delays
    always @(posedge clk_i) begin
        if (rst_i) begin
            decode_delay <= 4'h0;
        end else begin
            if (~latch_rf) begin
                decode_delay <= 0;
            end else if (decode_delay == 0) begin
                decode_delay <= {decode_delay[2:0], 1'b1};
            end else begin
                decode_delay <= decode_delay << 1;
            end
        end
    end
    // ---------------------------------------------------------------------
    // register file
    assign rs1 = latch_rf ? instruction_r[19:15] : instruction_q[19:15];
    assign rs2 = latch_rf ? instruction_r[24:20] : instruction_q[24:20];
    always @(posedge clk_i) begin
        rs1_d <= |rs1 ? regfile[rs1] : 32'b0;
        rs2_d <= |rs2 ? regfile[rs2] : 32'b0;

        if (rf_we && |rd) begin
            regfile[rd] <= rf_wd;
        end
    end

    always @(posedge clk_i) begin
        (* parallel_case *)
        case (1'b1)
            is_j:       rf_wd <= pc_4;
            is_csr:     rf_wd <= csr_dat_o;
            is_alu:     rf_wd <= alu_out;
            inst_auipc: rf_wd <= pc_u;
            inst_lui:   rf_wd <= imm_u;
            is_l:       rf_wd <= mdat_i;
            is_shift:   rf_wd <= shift_out;
            default:    rf_wd <= 32'bx;
        endcase
    end
    // ---------------------------------------------------------------------
    // PC's
    always @(posedge clk_i) begin
        pc_jalr   <= (rs1_d + imm_i) & 32'hFFFFFFFE;

        (* parallel_case, full_case *)
        case (1'b1)
            inst_jal:    next_pc <= pc_jal;
            inst_jalr:   next_pc <= pc_jalr;
            take_branch: next_pc <= pc_branch;
            default:     next_pc <= pc_4;
        endcase
    end
    // ---------------------------------------------------------------------
    // branch
    always @(posedge clk_i) begin
        is_eq       <= rs1_d == rs2_d;
        is_lt       <= $signed(rs1_d) < $signed(rs2_d);
        is_ltu      <= rs1_d < rs2_d;
        take_branch <= 1'b0;
        if (decode_delay[0]) begin
            take_branch <= |{is_eq & inst_beq, ~is_eq & inst_bne, is_lt & inst_blt, ~is_lt & inst_bge,
                             is_ltu & inst_bltu, ~is_ltu & inst_bgeu};
         end
    end
    // ---------------------------------------------------------------------
    // ALU
    always @(posedge clk_i) begin
        alu_a <= rs1_d;
        if (instruction_r[6:0] == 7'b0010011) begin
            alu_b <= imm_i;
        end else begin
            alu_b <= rs2_d;
        end
    end

    always @(*) begin
        alu_add_sub = inst_sub ? alu_a - alu_b : alu_a + alu_b;
        (* parallel_case *)
        case (1'b1)
            |{inst_slti, inst_slt}:   alu_cmp = $signed(alu_a) < $signed(alu_b);
            |{inst_sltiu, inst_sltu}: alu_cmp = alu_a < alu_b;
            default: alu_cmp = 0;
        endcase
    end

    always @(*) begin
        (* parallel_case *)
        case (1'b1)
            is_add_sub: alu_out = alu_add_sub;
            is_cmp:     alu_out = {31'b0, alu_cmp};
            is_xor:     alu_out = alu_a ^ alu_b;
            is_or:      alu_out = alu_a | alu_b;
            is_and:     alu_out = alu_a & alu_b;
            default:    alu_out = 32'bx;
        endcase
    end
    // ---------------------------------------------------------------------
    // Memory access
    always @(posedge clk_i) begin
        ld_addr     <= rs1_d + imm_i;
        st_addr     <= rs1_d + imm_s;
        ld_misalign <= (ld_addr[0] && (inst_lh || inst_lhu)) || (|ld_addr[1:0] && inst_lw);
        st_misalign <= (st_addr[0] && inst_sh) || (st_addr[1:0] != 0 && inst_sw);
    end
    // Memory output data
    always @(*) begin
        (* parallel_case *)
        case (1'b1)
            inst_sb: begin
                mdat_o = {4{rs2_d[7:0]}};
                msel_o = 4'b0001 << st_addr[1:0];
            end
            inst_sh: begin
                mdat_o = {2{rs2_d[15:0]}};
                msel_o = st_addr[1] ? 4'b1100 : 4'b0011;
            end
            default: begin
                mdat_o = rs2_d;
                msel_o = 4'b1111;
            end
        endcase
    end

    always @(*) begin
        (* parallel_case *)
        // verilator lint_off WIDTH
        case (1'b1)
            inst_lb: begin
                case (ld_addr[1:0])
                    2'b00: mdat_i = $signed(wbm_dat_i[7:0]);
                    2'b01: mdat_i = $signed(wbm_dat_i[15:8]);
                    2'b10: mdat_i = $signed(wbm_dat_i[23:16]);
                    2'b11: mdat_i = $signed(wbm_dat_i[31:24]);
                endcase
            end
            inst_lbu: begin
                case (ld_addr[1:0])
                    2'b00: mdat_i = wbm_dat_i[7:0];
                    2'b01: mdat_i = wbm_dat_i[15:8];
                    2'b10: mdat_i = wbm_dat_i[23:16];
                    2'b11: mdat_i = wbm_dat_i[31:24];
                endcase
            end
            inst_lh:  begin
                case (ld_addr[1])
                    1'b0: mdat_i = $signed(wbm_dat_i[15:0]);
                    1'b1: mdat_i = $signed(wbm_dat_i[31:16]);
                endcase
            end
            inst_lhu: begin
                case (ld_addr[1])
                    1'b0: mdat_i = wbm_dat_i[15:0];
                    1'b1: mdat_i = wbm_dat_i[31:16];
                endcase
            end
            inst_lw: mdat_i = wbm_dat_i;
            default: mdat_i = 32'bx;
        endcase
        // verilator lint_on WIDTH
    end
    // ---------------------------------------------------------------------
    always @(*) begin
        (* parallel_case *)
        case (cpu_state)
            cpu_state_fetch: begin
                wbm_addr_o = pc;
                wbm_dat_o  = 32'bx;
                wbm_sel_o  = 4'b0;
                wbm_we_o   = 1'b0;
                wbm_cyc_o  = pc[1:0] == 0;
                wbm_stb_o  = pc[1:0] == 0;
            end
            cpu_state_ld: begin
                wbm_addr_o = ld_addr;
                wbm_dat_o  = 32'bx;
                wbm_sel_o  = 4'b0;
                wbm_we_o   = 1'b0;
                wbm_cyc_o  = 1'b1;
                wbm_stb_o  = 1'b1;
            end
            cpu_state_st: begin
                wbm_addr_o = st_addr;
                wbm_dat_o  = mdat_o;
                wbm_sel_o  = msel_o;
                wbm_we_o   = 1'b1;
                wbm_cyc_o  = 1'b1;
                wbm_stb_o  = 1'b1;
            end
            default: begin
                wbm_addr_o = 32'hx;
                wbm_dat_o  = 32'hx;
                wbm_sel_o  = 4'b0;
                wbm_we_o   = 1'b0;
                wbm_cyc_o  = 1'b0;
                wbm_stb_o  = 1'b0;
            end
        endcase
    end
    // ---------------------------------------------------------------------
    // CSR
    reg wen;
    // Behavior modeling
    assign mstatus = {19'b0, mstatus_mpp, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
    assign mip     = {20'b0, xint_meip_i, 3'b0, xint_mtip_i, 3'b0, xint_msip_i, 3'b0};
    assign mie     = {20'b0, mie_meie, 3'b0, mie_mtie, 3'b0, mie_msie, 3'b0};
    assign mcause  = {mcause_interrupt, 27'b0, mcause_mecode};

    // latch commands
    always @(posedge clk_i) begin
        // TODO: use a latched is_csr?
        latched_csr    <= is_csr ? {latched_csr[2:0], latched_csr == 0} : 0;
        csr_wcmd       <= |{inst_csrrw, inst_csrrwi};
        csr_scmd       <= &{is_csrs, instruction_r[19:15] != 0}; // check rs1 != 0
        csr_ccmd       <= &{is_csrc, instruction_r[19:15] != 0}; // check rs1 != 0
        //
        priv_valid     <= priv_mode >= csr_address[9:8];
        csr_wen         = |{csr_wcmd, csr_scmd, csr_ccmd};
        illegal_access <= (csr_wen && (csr_address[11:10] == 2'b11)) || (is_csr && (!priv_valid || undef_register));
        wen            <= csr_wen && csr_address[11:10] != 2'b11 && priv_valid && latched_csr[1];
    end
    // check CSR address
    always @(posedge clk_i) begin
        // valid 1st cycle of CSR state
        is_misa      <= csr_address == MISA;
        is_mhartid   <= csr_address == MHARTID;
        is_mvendorid <= csr_address == MVENDORID;
        is_marchid   <= csr_address == MARCHID;
        is_mimpid    <= csr_address == MIMPID;
        is_mstatus   <= csr_address == MSTATUS;
        is_mie       <= csr_address == MIE;
        is_mtvec     <= csr_address == MTVEC;
        is_mscratch  <= csr_address == MSCRATCH;
        is_mepc      <= csr_address == MEPC;
        is_mcause    <= csr_address == MCAUSE;
        is_mtval     <= csr_address == MTVAL;
        is_mip       <= csr_address == MIP;
        is_cycle     <= csr_address == CYCLE || csr_address == MCYCLE;
        is_instret   <= csr_address == INSTRET || csr_address == MINSTRET;
        is_cycleh    <= csr_address == CYCLEH || csr_address == MCYCLEH;
        is_instreth  <= csr_address == INSTRETH || csr_address == MINSTRETH;
    end
    // write -------------------------------------------------------------------
    always @(posedge clk_i) begin
       if (ENABLE_COUNTERS) begin
            if (rst_i) begin
                cycle <= 0;
            end else begin
                if (wen && is_cycle) begin
                    cycle[31:0] <= csr_wdata;
                end if (wen && is_cycleh) begin
                    cycle[63:32] <= csr_wdata;
                end else begin
                    cycle <= cycle + 1;
                end
            end
       end else begin
           cycle <= 32'hx;
       end
    end
    //
    always @(posedge clk_i) begin
        if (ENABLE_COUNTERS) begin
            if (rst_i) begin
                instret <= 0;
            end else begin
                (* parallel_case *)
                case (1'b1)
                    wen && is_instret:         instret[31: 0] <= csr_wdata;
                    wen && is_instreth:        instret[63: 32] <= csr_wdata;
                    cpu_state == cpu_state_wb: instret <= instret + 1;
                    inst_fence:                instret <= instret + 1;
                    inst_xret:                 instret <= instret + 1;
                    trap_valid:                instret <= instret + {63'b0, (inst_xcall || inst_xbreak)};
                endcase
            end
        end else begin
            instret <= 32'hx;
        end
    end
    // interrupts
    always @(posedge clk_i) begin
        pend_int  <= (priv_mode < PRIV_M || mstatus_mie) ? mip & mie : 32'b0; //
        interrupt <= |{pend_int[11], pend_int[7], pend_int[3]};
    end
    // privilege mode
    always @(posedge clk_i) begin
        if (rst_i) begin
            priv_mode <= PRIV_M;
        end
        if (trap_valid)
            priv_mode <= PRIV_M;
        else if (inst_xret && !latch_instruction)
            priv_mode <= mstatus_mpp;
    end
    // auxiliar write data
    always @(posedge clk_i) begin
        (* parallel_case *)
        case (1'b1)
            csr_scmd: csr_wdata <= csr_dat_o | csr_dat_i;
            csr_ccmd: csr_wdata <= csr_dat_o & ~csr_dat_i;
            default:  csr_wdata <= csr_dat_i;
        endcase
    end
    // mstatus
    always @(posedge clk_i) begin
        if (rst_i) begin
            mstatus_mpp  <= 0;
            mstatus_mpie <= 0;
            mstatus_mie  <= 0;
        end else if (trap_valid) begin
            mstatus_mpp  <= priv_mode;
            mstatus_mpie <= mstatus_mie;
            mstatus_mie  <= 0;
        end else if (inst_xret && !latch_instruction) begin
            mstatus_mpp  <= PRIV_U;
            mstatus_mpie <= 1;
            mstatus_mie  <= mstatus_mpie;
        end else if (wen && is_mstatus) begin
            mstatus_mpp  <= {2{csr_wdata[11] || csr_wdata[12]}}; // 00 or 11
            mstatus_mpie <= csr_wdata[7];
            mstatus_mie  <= csr_wdata[3];
        end
    end
    // mepc
    always @(posedge clk_i) begin
        if (rst_i) mepc <= 0;
        else if (trap_valid) mepc <= {pc[31:2], 2'b0};
        else if (wen && is_mepc) mepc <= {csr_wdata[31:2], 2'b0};
    end
    always @(posedge clk_i) begin
        if (rst_i) begin
            mcause_interrupt <= 0;
            mcause_mecode    <= E_ILLEGAL_INST;
        end else if (trap_valid) begin
            mcause_interrupt <= interrupt;
            mcause_mecode    <= e_code;
        end else if (wen && is_mcause) begin
            mcause_interrupt <= csr_wdata[31];
            mcause_mecode    <= csr_wdata[3:0];
        end
    end
    // mtval
    always @(posedge clk_i) begin
        if (trap_valid) begin
            mtval <= exc_data;
        end
        else if (wen && is_mtval) begin
            mtval <= csr_wdata;
        end
    end
    // mie
    always @(posedge clk_i) begin
        if (rst_i) begin
            mie_meie <= 0;
            mie_mtie <= 0;
            mie_msie <= 0;
        end else if (wen && is_mie) begin
            mie_meie <= csr_wdata[11];
            mie_mtie <= csr_wdata[7];
            mie_msie <= csr_wdata[3];
        end
    end
    // default
    always @(posedge clk_i) begin
        if (rst_i) begin
            mtvec <= RESET_ADDR;
        end else if (wen) begin
            (* parallel_case *)
            case (1'b1)
                is_mtvec: mtvec       <= csr_wdata;
                is_mscratch: mscratch <= csr_wdata;
            endcase
        end
    end
    // read registers
    assign undef_register = ~|{is_misa, is_mhartid, is_mvendorid, is_marchid, is_mimpid, is_mstatus, is_mie, is_mtvec, is_mscratch, is_mepc, is_mcause, is_mtval, is_mip, is_cycle, is_instret, is_cycleh, is_instreth};
    always @(posedge clk_i) begin
        // valid 2nd cycle of CSR state
        (* parallel_case *)
        case (1'b1)
            is_misa:                                csr_dat_o <= {2'b01, 4'b0, 26'b00000100000000000100000000};
            is_mhartid:                             csr_dat_o <= HART_ID;
            |{is_mvendorid, is_marchid, is_mimpid}: csr_dat_o <= 0;
            is_mstatus:                             csr_dat_o <= mstatus;
            is_mie:                                 csr_dat_o <= mie;
            is_mtvec:                               csr_dat_o <= mtvec;
            is_mscratch:                            csr_dat_o <= mscratch;
            is_mepc:                                csr_dat_o <= mepc;
            is_mcause:                              csr_dat_o <= mcause;
            is_mtval:                               csr_dat_o <= mtval;
            is_mip:                                 csr_dat_o <= mip;
            |{is_cycle, is_cycleh}:                 csr_dat_o <= is_cycle ? cycle[31:     0] : cycle[63:   32];
            |{is_instret, is_instreth}:             csr_dat_o <= is_instret ? instret[31: 0] : instret[63: 32];
            default:                                csr_dat_o <= 32'bx;
        endcase
    end

endmodule
// EOF
