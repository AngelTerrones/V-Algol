// -----------------------------------------------------------------------------
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// -----------------------------------------------------------------------------
// Title       : A RISC-V processor
// Project     : Algol
// Description : A multi-cycle, RV32I, RISC-V processor.
// -----------------------------------------------------------------------------

`default_nettype none
`timescale 1 ns / 1 ps

// from picorv32 :)
`ifdef FORMAL
    `define FORMAL_KEEP (* keep *)
`else
    `ifdef DEBUG
        `define FORMAL_KEEP (* keep *)
    `else
        `define FORMAL_KEEP
    `endif
`endif

module algol #(
               parameter [31:0] HART_ID         = 0,
               parameter [31:0] RESET_ADDR      = 32'h8000_0000,
               parameter        FAST_SHIFT      = 0,
               parameter        ENABLE_COUNTERS = 0
               )(
                 input wire        clk,
                 input wire        rst,
                 // Memory port
                 output reg [31:0] mem_address,
                 output reg [31:0] mem_wdata,
                 output reg [3:0]  mem_wsel,
                 output reg        mem_valid,
                 input wire [31:0] mem_rdata,
                 input wire        mem_ready,
                 input wire        mem_error,
                 // external interrupts interface
                 input wire        xint_meip,
                 input wire        xint_mtip,
                 input wire        xint_msip
                 );
    // =====================================================================
    // CSR list
    localparam MVENDORID  = 12'hF11; //
    localparam MARCHID    = 12'hF12; //
    localparam MIMPID     = 12'hF13; //
    localparam MHARTID    = 12'hF14; //
    localparam MSTATUS    = 12'h300; //
    localparam MISA       = 12'h301; //
    localparam MIE        = 12'h304; //
    localparam MTVEC      = 12'h305; //
    localparam MSCRATCH   = 12'h340; //
    localparam MEPC       = 12'h341; //
    localparam MCAUSE     = 12'h342; //
    localparam MTVAL      = 12'h343; //
    localparam MIP        = 12'h344; //
    localparam MCYCLE     = 12'hB00; //
    localparam MINSTRET   = 12'hB02; //
    localparam MCYCLEH    = 12'hB80; //
    localparam MINSTRETH  = 12'hB82; //
    // Exception codes
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
    // State machine
    localparam cpu_state_reset   = 6'b000000;
    localparam cpu_state_fetch   = 6'b000001;
    localparam cpu_state_execute = 6'b000010;
    localparam cpu_state_mem     = 6'b000100;
    localparam cpu_state_csr     = 6'b001000;
    localparam cpu_state_wb      = 6'b010000;
    localparam cpu_state_trap    = 6'b100000;
    // =====================================================================
    // Signals
    reg [5:0]   cpu_state, cpu_state_nxt;
    reg [31:0]  pc, pc4;
    reg [31:0]  instruction;
    wire [31:0] instruction_q;
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
    reg         inst_wfi;
    reg         is_j, is_b, is_l, is_s, is_shift, is_csr, is_csrx, is_csrs, is_csrc;
    reg         is_add, is_logic, is_cmp;
    reg [31:0]  imm_i, imm_s, imm_b, imm_u, imm_j;
    wire [4:0]  rs1, rs2, rd;
    reg [31:0]  rs1_d, rs2_d, rf_wdata;
    reg         rf_we;
    reg [31:0]  regfile1 [0:31];
    reg [31:0]  regfile2 [0:31];
    reg         is_imm;
    //
    wire        interrupt;
    reg [31:0]  mem_dat_o, mem_dat_i;
    reg [3:0]   mem_sel_o;
    reg [11:0]  csr_address;
    // =====================================================================
    // debug-simulation
    `FORMAL_KEEP reg [20*8 - 1:0] dbg_ascii_state;

    always @(*) begin
        dbg_ascii_state = "unknown";
        if (cpu_state == cpu_state_reset)   dbg_ascii_state = "reset";
        if (cpu_state == cpu_state_fetch)   dbg_ascii_state = "fetch";
        if (cpu_state == cpu_state_execute) dbg_ascii_state = "execute";
        if (cpu_state == cpu_state_mem)     dbg_ascii_state = "mem";
        if (cpu_state == cpu_state_csr)     dbg_ascii_state = "csr";
        if (cpu_state == cpu_state_wb)      dbg_ascii_state = "commit";
        if (cpu_state == cpu_state_trap)    dbg_ascii_state = "trap";
    end // always @ (*)
    // =====================================================================
    // decodificar instruccion
    assign instruction_q = mem_rdata;
    always @(posedge clk) begin
        if (cpu_state == cpu_state_fetch) begin
            instruction <= instruction_q;
            //
            inst_lui    <= instruction_q[6:0] == 7'b0110111;
            inst_auipc  <= instruction_q[6:0] == 7'b0010111;
            //
            inst_jal    <= instruction_q[6:0] == 7'b1101111;
            inst_jalr   <= instruction_q[6:0] == 7'b1100111;
            //
            inst_beq    <= instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b000;
            inst_bne    <= instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b001;
            inst_blt    <= instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b100;
            inst_bge    <= instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b101;
            inst_bltu   <= instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b110;
            inst_bgeu   <= instruction_q[6:0] == 7'b1100011 && instruction_q[14:12] == 3'b111;
            //
            inst_lb     <= instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b000;
            inst_lh     <= instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b001;
            inst_lw     <= instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b010;
            inst_lbu    <= instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b100;
            inst_lhu    <= instruction_q[6:0] == 7'b0000011 && instruction_q[14:12] == 3'b101;
            //
            inst_sb     <= instruction_q[6:0] == 7'b0100011 && instruction_q[14:12] == 3'b000;
            inst_sh     <= instruction_q[6:0] == 7'b0100011 && instruction_q[14:12] == 3'b001;
            inst_sw     <= instruction_q[6:0] == 7'b0100011 && instruction_q[14:12] == 3'b010;
            //
            inst_addi   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b000;
            inst_slti   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b010;
            inst_sltiu  <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b011;
            inst_xori   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b100;
            inst_ori    <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b110;
            inst_andi   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b111;
            inst_slli   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b001 && instruction_q[31:25] == 7'b0000000;
            inst_srli   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0000000;
            inst_srai   <= instruction_q[6:0] == 7'b0010011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0100000;
            //
            inst_add    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b000 && instruction_q[31:25] == 7'b0000000;
            inst_sub    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b000 && instruction_q[31:25] == 7'b0100000;
            inst_sll    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b001 && instruction_q[31:25] == 7'b0000000;
            inst_slt    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b010 && instruction_q[31:25] == 7'b0000000;
            inst_sltu   <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b011 && instruction_q[31:25] == 7'b0000000;
            inst_xor    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b100 && instruction_q[31:25] == 7'b0000000;
            inst_srl    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0000000;
            inst_sra    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b101 && instruction_q[31:25] == 7'b0100000;
            inst_or     <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b110 && instruction_q[31:25] == 7'b0000000;
            inst_and    <= instruction_q[6:0] == 7'b0110011 && instruction_q[14:12] == 3'b111 && instruction_q[31:25] == 7'b0000000;
            //
            inst_fence  <= instruction_q[6:0] == 7'b0001111;
            //
            inst_csrrw  <= instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b001;
            inst_csrrs  <= instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b010;
            inst_csrrc  <= instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b011;
            inst_csrrwi <= instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b101;
            inst_csrrsi <= instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b110;
            inst_csrrci <= instruction_q[6:0] == 7'b1110011 && instruction_q[14:12] == 3'b111;
            inst_xcall  <= instruction_q[6:0] == 7'b1110011 && instruction_q[31:7] == 0;
            inst_xbreak <= instruction_q[6:0] == 7'b1110011 && instruction_q[31:7] == 25'b0000000000010000000000000;
            inst_xret   <= instruction_q[6:0] == 7'b1110011 && instruction_q[31:30] == 2'b0 && instruction_q[27:7] == 21'b000000100000000000000; // all xRET instrucctions are valid.
            //
            inst_wfi    <= instruction_q == 32'b00010000010100000000000001110011;
            //
            csr_address <= instruction_q[31:20];
            is_imm      <= instruction_q[6:0] == 7'b0010011;
        end // if (cpu_state == cpu_state_fetch && mem_valid)
    end
    // immediate values
    always @(posedge clk) begin
        if (cpu_state == cpu_state_fetch) begin
            // verilator lint_off WIDTH
            imm_i <= $signed(instruction_q[31:20]);
            imm_s <= $signed({instruction_q[31:25], instruction_q[11:7]});
            imm_b <= $signed({instruction_q[31], instruction_q[7], instruction_q[30:25], instruction_q[11:8], 1'b0});
            imm_u <= {instruction_q[31:12], {12{1'b0}}};
            imm_j <= $signed({instruction_q[31], instruction_q[19:12], instruction_q[20], instruction_q[30:21], 1'b0});
            // verilator lint_on WIDTH
        end
    end
    //
    always @(*) begin
        is_j     = |{inst_jal, inst_jalr};
        is_b     = |{inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu};
        is_l     = |{inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw};
        is_s     = |{inst_sb, inst_sh, inst_sw};
        is_csr   = |{inst_csrrw, inst_csrrs, inst_csrrc, inst_csrrwi, inst_csrrsi, inst_csrrci};
        is_add   = |{inst_auipc, inst_lui, inst_add, inst_addi, inst_sub};
        is_logic = |{inst_and, inst_andi, inst_or, inst_ori, inst_xor, inst_xori};
        is_cmp   = |{inst_slt, inst_slti, inst_sltu, inst_sltiu};
        is_shift = |{inst_slli, inst_sll, inst_srli, inst_srl, inst_srai, inst_sra};
        is_csrs  = |{inst_csrrs, inst_csrrsi};
        is_csrc  = |{inst_csrrc, inst_csrrci};
        is_csrx  = |{inst_csrrw, inst_csrrs, inst_csrrc};
    end
    // =====================================================================
    // Register file
    assign rs1 = instruction_q[19:15];
    assign rs2 = instruction_q[24:20];
    assign rd  = instruction[11:7];
    // split the RF to force BRAM in vivado.
    always @(posedge clk) begin
        if (cpu_state == cpu_state_fetch) begin
            rs1_d <= (|rs1)? regfile1[rs1] : 0;
        end
        if (rf_we && |rd) begin
            regfile1[rd] <= rf_wdata;
        end
    end
    always @(posedge clk) begin
        if (cpu_state == cpu_state_fetch) begin
            rs2_d <= (|rs2)? regfile2[rs2] : 0;
        end
        if (rf_we && |rd) begin
            regfile2[rd] <= rf_wdata;
        end
    end
    //
    reg [31:0] csr_dat;
    always @(posedge clk) begin
        csr_dat <= csr_dat_o;
    end
    always @(*) begin
        rf_we    = 0;
        if (cpu_state == cpu_state_wb) rf_we = |{is_j, is_l, is_csr, is_logic, is_cmp, is_shift, is_add};
    end

    reg [31:0] rf_tmp1, rf_tmp2;
    always @(*) begin
        case (1'b1)
            is_j:     begin rf_tmp1 = pc4;       end
            is_l:     begin rf_tmp1 = mem_dat_i; end
            is_csr:   begin rf_tmp1 = csr_dat;   end
            default:  begin rf_tmp1 = logic_out; end
        endcase
    end
    always @(*) begin
        case (1'b1)
            is_cmp:   begin rf_tmp2 = {31'b0, cmp_out}; end
            is_shift: begin rf_tmp2 = shift_out;        end
            default:  begin rf_tmp2 = add_out;          end
        endcase
    end
    always @(*) begin
        if (is_j || is_l || is_csr || is_logic) rf_wdata = rf_tmp1;
        else rf_wdata = rf_tmp2;
    end
    // =========================================================================
    // FSM
    wire use_alu;
    assign use_alu = is_add | is_j | is_b | is_cmp | is_logic;
    always @(posedge clk or posedge rst) begin
        if (rst) cpu_state <= cpu_state_reset;
        else     cpu_state <= cpu_state_nxt;
    end
    //
    always @(*) begin
        cpu_state_nxt = cpu_state;
        (* parallel_case *)
        case (cpu_state)
            cpu_state_reset: begin
                cpu_state_nxt = cpu_state_fetch;
            end
            cpu_state_fetch: begin
                case (1'b1)
                    mem_ready:                cpu_state_nxt = cpu_state_execute;
                    mem_error | if_unaligned: cpu_state_nxt = cpu_state_trap;
                endcase
            end
            cpu_state_execute: begin
                case (1'b1)
                    is_shift: begin
                        if (shift_done || FAST_SHIFT) cpu_state_nxt = cpu_state_wb;
                    end
                    use_alu:      cpu_state_nxt = cpu_state_wb;
                    inst_fence:   cpu_state_nxt = cpu_state_fetch;
                    inst_wfi:     cpu_state_nxt = cpu_state_fetch;
                    is_l || is_s: cpu_state_nxt = cpu_state_mem;
                    is_csr:       cpu_state_nxt = cpu_state_csr;
                    default:      cpu_state_nxt = cpu_state_trap;
                endcase
                if (interrupt) cpu_state_nxt = cpu_state_trap;
            end
            cpu_state_mem: begin
                case (1'b1)
                    mem_ready:                 cpu_state_nxt = cpu_state_wb;
                    mem_error | mem_unaligned: cpu_state_nxt = cpu_state_trap;
                endcase
            end
            cpu_state_csr: begin
                cpu_state_nxt = cpu_state_wb;
                if (csr_error) cpu_state_nxt = cpu_state_trap;
            end
            cpu_state_wb: begin
                cpu_state_nxt = cpu_state_fetch;
                if (wb_error) cpu_state_nxt = cpu_state_trap;
            end
            cpu_state_trap: begin
                cpu_state_nxt = cpu_state_fetch;
            end
            default: begin
                cpu_state_nxt = cpu_state_reset;
            end
        endcase
    end
    // =========================================================================
    // set the new pc
    always @(*) begin
        pc4 = pc + 4;
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= RESET_ADDR;
        end else begin
            if (cpu_state == cpu_state_execute) begin
                if (inst_fence) pc <= pc4;
                if (inst_wfi)   pc <= pc4;
            end
            if (cpu_state == cpu_state_wb) begin
                if (is_j || b_taken) begin
                    if (!wb_error) pc <= {add_out[31:1], 1'b0};
                end else  begin
                    pc <= pc4;
                end
            end
            if (cpu_state == cpu_state_trap) begin
                pc <= mtvec;
                if (inst_xret) pc <= mepc;
            end
        end
    end
    // =========================================================================
    // jumps
    wire b_taken;
    assign b_taken = |{is_eq  && inst_beq, ~is_eq   && inst_bne,
                       is_lt  && inst_blt, ~is_lt   && inst_bge,
                       is_ltu && inst_bltu, ~is_ltu && inst_bgeu};
    // =========================================================================
    // ALU
    reg [31:0] alu_a, alu_b, add_out, logic_out, shift_out;
    reg [31:0] cmp_b;
    reg        cmp_out;
    wire       is_or, is_and;
    reg        is_lt, is_ltu, is_eq;

    // input a
    always @(*) begin
        case (1'b1)
            inst_lui:                     alu_a = 0;
            inst_auipc | inst_jal | is_b: alu_a = pc;
            default:                      alu_a = rs1_d;
        endcase
    end
    // input b
    always @(*) begin
        case (1'b1)
            inst_lui | inst_auipc:     alu_b = imm_u;
            inst_jal:                  alu_b = imm_j;
            is_b:                      alu_b = imm_b;
            is_s:                      alu_b = imm_s;
            inst_jalr | is_l | is_imm: alu_b = imm_i;
            inst_sub:                  alu_b = ~rs2_d;
            default:                   alu_b = rs2_d;
        endcase
    end
    // cmp_b
    always @(*) begin
        case (1'b1)
            inst_slti | inst_sltiu: cmp_b = imm_i;
            default:                cmp_b = rs2_d;
        endcase
    end
    // output
    assign is_or  = |{inst_or, inst_ori};
    assign is_and = |{inst_and, inst_andi};

    always @(posedge clk) begin
        add_out <= alu_a + alu_b + {31'b0, inst_sub};
    end

    always @(posedge clk) begin
        case (1'b1)
            is_and:  logic_out <= alu_a & alu_b;
            is_or:   logic_out <= alu_a | alu_b;
            default: logic_out <= alu_a ^ alu_b;
        endcase
    end

    always @(posedge clk) begin
        is_eq  <= rs1_d == cmp_b;
        is_lt  <= $signed(rs1_d) < $signed(cmp_b);
        is_ltu <= rs1_d < cmp_b;
    end

    always @(*) begin
        cmp_out = (is_lt && (inst_slt || inst_slti)) || (is_ltu && (inst_sltu || inst_sltiu));
    end

    reg shift_done;
    generate
        if (FAST_SHIFT) begin
            always @(*) begin
                shift_done = 0;
            end

            always @(posedge clk) begin
                (* parallel_case *)
                case (1'b1)
                    |{inst_slli, inst_sll}: shift_out <= alu_a << alu_b[4:0];
                    |{inst_srli, inst_srl}: shift_out <= alu_a >> alu_b[4:0];
                    default:                shift_out <= $signed(alu_a) >>> alu_b[4:0];
                endcase
            end
        end else begin
            reg [4:0] shift_cnt;
            reg [1:0] shift_state;

            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    shift_state <= 0;
                end else begin
                    shift_done  <= 0;
                    if (shift_state == 0) begin
                        shift_cnt  <= alu_b[4:0];
                        shift_out  <= alu_a;

                        if (is_shift && cpu_state == cpu_state_execute) begin
                            shift_state <= 1;
                        end
                    end else if(shift_state == 1) begin
                        shift_cnt <= shift_cnt - 1;
                        if (shift_cnt == 0) begin
                            shift_done  <= 1;
                            shift_state <= 2;
                        end else begin
                            shift_out <= {(inst_sra || inst_srai) && shift_out[31], shift_out[31:1]};
                            if (|{inst_slli, inst_sll}) shift_out <= shift_out << 1;
                        end
                    end else begin // if (shift_state == 1)
                        shift_state <= 0;
                    end
                    //
                end
            end
        end
    endgenerate
    // =========================================================================
    // handle load/store instructions
    // =========================================================================
    // Format data: write
    reg [3:0] mem_sel_b, mem_sel_h;
    always @(*) begin
        case (add_out[1:0])
            2'b00: mem_sel_b = 4'b0001;
            2'b01: mem_sel_b = 4'b0010;
            2'b10: mem_sel_b = 4'b0100;
            2'b11: mem_sel_b = 4'b1000;
        endcase
    end
    always @(*) begin
        mem_sel_h = add_out[1] ? 4'b1100 : 4'b0011;
    end
    always @(*) begin
        case (1'b1)
            inst_sb: begin
                mem_dat_o = {4{rs2_d[7:0]}};
                mem_sel_o = mem_sel_b;
            end
            inst_sh: begin
                mem_dat_o = {2{rs2_d[15:0]}};
                mem_sel_o = mem_sel_h;
            end
            inst_sw: begin
                mem_dat_o = rs2_d;
                mem_sel_o = 4'b1111;
            end
            default: begin
                mem_dat_o = 32'hx;
                mem_sel_o = 0;
            end
        endcase
    end
    // Format data: read
    reg [8:0]  mbyte;
    reg [16:0] mhalf;
    //
    always @(*) begin
        case (add_out[1:0])
            2'b00: mbyte = {inst_lb && mem_rdata[7],  mem_rdata[7:0]};
            2'b01: mbyte = {inst_lb && mem_rdata[15], mem_rdata[15:8]};
            2'b10: mbyte = {inst_lb && mem_rdata[23], mem_rdata[23:16]};
            2'b11: mbyte = {inst_lb && mem_rdata[31], mem_rdata[31:24]};
        endcase
    end
    //
    always @(*) begin
        case (add_out[1])
            1'b0: mhalf = {inst_lh && mem_rdata[15], mem_rdata[15:0]};
            1'b1: mhalf = {inst_lh && mem_rdata[31], mem_rdata[31:16]};
        endcase
    end
    //
    always @(posedge clk) begin
        // verilator lint_off WIDTH
        case (1'b1)
            inst_lb || inst_lbu: mem_dat_i <= $signed(mbyte);
            inst_lh || inst_lhu: mem_dat_i <= $signed(mhalf);
            default:             mem_dat_i <= mem_rdata;
        endcase
        // verilator lint_on WIDTH
    end
    // Handle the memory port
    reg mem_enable;
    always @(posedge clk) begin
        mem_enable <= cpu_state == cpu_state_mem && !mem_unaligned; // enable mem port if no exceptions
    end
    always @(*) begin
        (* parallel_case *)
        case (cpu_state)
            cpu_state_fetch: begin
                mem_address = pc;
                mem_wdata   = 32'bx;
                mem_wsel    = 0;
                mem_valid   = 1;
            end
            cpu_state_mem: begin
                mem_address = add_out;
                mem_wdata   = mem_dat_o;
                mem_wsel    = mem_sel_o;
                mem_valid   = mem_enable;
            end
            default: begin
                mem_address = 32'hx;
                mem_wdata   = 32'hx;
                mem_wsel    = 0;
                mem_valid   = 0;
            end
        endcase
    end
    // =========================================================================
    // CSR
    wire [31:0] mstatus, mie, mcause, mip;
    reg [31:0]  mscratch, mtval;
    reg [29:0]  _mtvec, _mepc;
    wire [31:0] mtvec, mepc;
    // msatus fields
    reg         mstatus_mpie;
    reg         mstatus_mie;
    // mie fields
    reg         mie_meie, mie_mtie, mie_msie;
    // mcause fields
    reg         mcause_interrupt;
    reg [3:0]   mcause_mcode, ecode;
    reg [63:0]  cycle, instret;
    // access check
    reg         is_misa, is_mhartid, is_mstatus, is_mie, is_mtvec, is_mscratch, is_mepc, is_mcause,
                is_mtval, is_mip, is_cycle, is_cycleh, is_instret, is_instreth;
    reg         _is_misa, _is_mhartid, _is_mstatus, _is_mie, _is_mtvec, _is_mscratch, _is_mepc, _is_mcause,
                _is_mtval, _is_mip, _is_cycle, _is_cycleh, _is_instret, _is_instreth;
    reg         undef_register;
    //
    reg [31:0]  csr_dat_o, csr_dat_i, csr_wdata, edata;
    reg         csr_wcmd, csr_scmd, csr_ccmd;
    wire        csr_wen;
    wire        take_trap, csr_error;
    //
    assign mstatus = {19'b0, 2'b11, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
    assign mip     = {20'b0, xint_meip, 3'b0, xint_mtip, 3'b0, xint_msip, 3'b0};
    assign mie     = {20'b0, mie_meie, 3'b0, mie_mtie, 3'b0, mie_msie, 3'b0};
    assign mcause  = {mcause_interrupt, 27'b0, mcause_mcode};
    assign mtvec   = {_mtvec, 2'b0};
    assign mepc    = {_mepc, 2'b0};

    assign csr_wen   = |{csr_wcmd, csr_scmd, csr_ccmd} && (cpu_state == cpu_state_csr);
    assign take_trap = cpu_state == cpu_state_trap;
    assign csr_error = is_csr && undef_register;

    always @(posedge clk) begin
        csr_wcmd <= inst_csrrw || inst_csrrwi;
        csr_scmd <= is_csrs && |instruction[19:15]; // cmd is valid only if rs1 != 0
        csr_ccmd <= is_csrc && |instruction[19:15]; // cmd is valid only if rs1 != 0
    end
    // ---------------------------------------------------------------------
    // check CSR address
    always @(*) begin
        _is_misa      = csr_address == MISA;
        _is_mhartid   = csr_address == MHARTID;
        _is_mstatus   = csr_address == MSTATUS;
        _is_mie       = csr_address == MIE;
        _is_mtvec     = csr_address == MTVEC;
        _is_mscratch  = csr_address == MSCRATCH;
        _is_mepc      = csr_address == MEPC;
        _is_mcause    = csr_address == MCAUSE;
        _is_mtval     = csr_address == MTVAL;
        _is_mip       = csr_address == MIP;
        _is_cycle     = ENABLE_COUNTERS && csr_address == MCYCLE;
        _is_cycleh    = ENABLE_COUNTERS && csr_address == MCYCLEH;
        _is_instret   = ENABLE_COUNTERS && csr_address == MINSTRET;
        _is_instreth  = ENABLE_COUNTERS && csr_address == MINSTRETH;
    end
    always @(posedge clk) begin
        // valid 1st cycle of CSR state
        is_misa        <= _is_misa;
        is_mhartid     <= _is_mhartid;
        is_mstatus     <= _is_mstatus;
        is_mie         <= _is_mie;
        is_mtvec       <= _is_mtvec;
        is_mscratch    <= _is_mscratch;
        is_mepc        <= _is_mepc;
        is_mcause      <= _is_mcause;
        is_mtval       <= _is_mtval;
        is_mip         <= _is_mip;
        is_cycle       <= _is_cycle;
        is_cycleh      <= _is_cycleh;
        is_instret     <= _is_instret;
        is_instreth    <= _is_instreth;
        undef_register <= ~|{_is_misa, _is_mhartid, _is_mstatus, _is_mie, _is_mtvec,
                             _is_mscratch, _is_mepc, _is_mcause, _is_mtval, _is_mip,
                             _is_cycle, _is_cycleh, _is_instret, _is_instreth};
    end
    // ---------------------------------------------------------------------
    // CSR: read registers
    always @(*) begin
        (* parallel_case *)
        case (1'b1)
            is_misa:     csr_dat_o = {2'b01, 4'b0, 26'b00000000000000000100000000};
            is_mhartid:  csr_dat_o = HART_ID;
            is_mstatus:  csr_dat_o = mstatus;
            is_mie:      csr_dat_o = mie;
            is_mtvec:    csr_dat_o = mtvec;
            is_mscratch: csr_dat_o = mscratch;
            is_mepc:     csr_dat_o = mepc;
            is_mcause:   csr_dat_o = mcause;
            is_mtval:    csr_dat_o = mtval;
            is_mip:      csr_dat_o = mip;
            is_cycle:    csr_dat_o = cycle[31:0];
            is_cycleh:   csr_dat_o = cycle[63:32];
            is_instret:  csr_dat_o = instret[31:0];
            is_instreth: csr_dat_o = instret[63:32];
            default:     csr_dat_o = 32'b0;
        endcase
    end
    // ---------------------------------------------------------------------
    // CSR: write registers
    always @(*) begin
        csr_dat_i = {27'b0, instruction[19:15]};
        if (is_csrx) csr_dat_i = rs1_d;
    end
    always @(*) begin
        case (1'b1)
            csr_scmd : csr_wdata = csr_dat_o | csr_dat_i;
            csr_ccmd : csr_wdata = csr_dat_o & ~csr_dat_i;
            default  : csr_wdata = csr_dat_i;
        endcase
    end

    generate
        if (ENABLE_COUNTERS) begin
            // cycle
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    cycle <= 0;
                end else begin
                    //(* parallel_case *)
                    case (1'b1)
                        csr_wen && is_cycle:  cycle[31:0]  <= csr_wdata;
                        csr_wen && is_cycleh: cycle[63:32] <= csr_wdata;
                        default:              cycle <= cycle + 1;
                    endcase
                end
            end
            // Instruction counter
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    instret <= 0;
                end else begin
                    (* parallel_case *)
                    case(1'b1)
                        csr_wen && is_instret:       instret[31: 0]  <= csr_wdata;
                        csr_wen && is_instreth:      instret[63: 32] <= csr_wdata;
                        cpu_state == cpu_state_wb:   instret <= instret + 1;
                        cpu_state == cpu_state_trap: instret <= instret + 1;
                    endcase
                end
            end
        end else begin
            always @(posedge clk) begin
                cycle   <= 64'hx;
                instret <= 64'hx;
            end
        end
    endgenerate
    // mstatus
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus_mpie <= 0;
            mstatus_mie  <= 0;
        end else begin
            if (take_trap) begin
                mstatus_mpie <= mstatus_mie;
                mstatus_mie  <= 0;
            end else if (inst_xret) begin
                mstatus_mpie <= 1;
                mstatus_mie  <= mstatus_mpie;
            end else if (csr_wen && is_mstatus) begin
                mstatus_mpie <= csr_wdata[7];
                mstatus_mie  <= csr_wdata[3];
            end
        end
    end
    // mepc
    always @(posedge clk) begin
        if (take_trap)               _mepc <= pc[31:2];
        else if (csr_wen && is_mepc) _mepc <= csr_wdata[31:2];
    end
    // mcause
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mcause_interrupt <= 0; // This is not needed. But this reduces LUT count (._. )
        end else begin
            if (take_trap) begin
                mcause_interrupt <= interrupt;
                mcause_mcode     <= ecode;
            end else if (csr_wen && is_mcause) begin
                mcause_interrupt <= csr_wdata[31];
                mcause_mcode     <= csr_wdata[3:0];
            end
        end
    end
    // mtval
    always @(posedge clk) begin
        if (take_trap)                mtval <= edata;
        else if (csr_wen && is_mtval) mtval <= csr_wdata;
    end
    // mie
    always @(posedge clk or posedge rst) begin
        if (rst)
            {mie_meie, mie_mtie, mie_msie} <= 0;
        else if (csr_wen && is_mie)
            {mie_meie, mie_mtie, mie_msie} <= {csr_wdata[11], csr_wdata[7], csr_wdata[3]};
    end
    // others
    always @(posedge clk) begin
        if(csr_wen && is_mtvec) _mtvec <= csr_wdata[31:2];
    end
    always @(posedge clk) begin
        if(csr_wen && is_mscratch) mscratch <= csr_wdata;
    end
    // =========================================================================
    // Exceptions
    reg [2:0] pend_int;
    reg mem_unaligned, if_unaligned, wb_error;
    //
    assign interrupt = |pend_int;
    always @(posedge clk) begin
        pend_int <= 0;
        if (mstatus_mie) pend_int <= {xint_meip & mie_meie, xint_msip & mie_msie, xint_mtip & mie_mtie};
    end
    //
    always @(*) begin
        wb_error     = (is_j || b_taken) && add_out[1];
        if_unaligned = |pc[1:0];
        case (1'b1)
            add_out[0] && |{inst_lh, inst_lhu, inst_sh}: mem_unaligned = 1;
            |add_out[1:0] && |{inst_lw, inst_sw}:        mem_unaligned = 1;
            default:                                     mem_unaligned = 0;
        endcase
    end
    //
    always @(posedge clk) begin
        case (cpu_state)
            cpu_state_fetch: begin
                edata <= pc;
                ecode <= E_INST_ADDR_MISALIGNED;
                if (mem_error) ecode <= E_INST_ACCESS_FAULT;
            end
            cpu_state_execute: begin
                edata <= instruction;
                ecode <= E_ILLEGAL_INST;
                if (inst_xcall) begin
                    edata <= 0;
                    ecode <= E_ECALL_FROM_M;
                end
                if (inst_xbreak) begin
                    edata <= pc;
                    ecode <= E_BREAKPOINT;
                end
                if (interrupt) begin
                    edata <= instruction;
                    case (1'b1)
                        pend_int[2]: ecode <= I_M_EXTERNAL;
                        pend_int[1]: ecode <= I_M_SOFTWARE;
                        pend_int[0]: ecode <= I_M_TIMER;
                    endcase
                end
            end
            cpu_state_mem: begin
                edata <= add_out;
                if (is_s && mem_error)     ecode <= E_STORE_AMO_ACCESS_FAULT;
                if (is_s && mem_unaligned) ecode <= E_STORE_AMO_ADDR_MISALIGNED;
                if (is_l && mem_error)     ecode <= E_LOAD_ACCESS_FAULT;
                if (is_l && mem_unaligned) ecode <= E_LOAD_ADDR_MISALIGNED;
            end
            cpu_state_csr: begin
                edata <= instruction;
                ecode <= E_ILLEGAL_INST;
            end
            default: begin
                edata <= {add_out[31:1], 1'b0};
                ecode <= E_INST_ADDR_MISALIGNED;
            end
        endcase
    end
    // =========================================================================
    // Formal verification
`ifdef FORMAL
    reg fv_valid = 0;
    always @(posedge clk) begin
        fv_valid = 1;
    end
    // ---------------------------------------------------------------------
    // force initial reset
    initial restrict (rst);
    // ---------------------------------------------------------------------
    // check that cpu state is always in valid state.
    reg cpu_state_ok;
    always @(*) begin
        if (!rst) begin
            cpu_state_ok = 0;
            if (cpu_state == cpu_state_reset)   cpu_state_ok = 1;
            if (cpu_state == cpu_state_fetch)   cpu_state_ok = 1;
            if (cpu_state == cpu_state_execute) cpu_state_ok = 1;
            if (cpu_state == cpu_state_mem)     cpu_state_ok = 1;
            if (cpu_state == cpu_state_csr)     cpu_state_ok = 1;
            if (cpu_state == cpu_state_wb)      cpu_state_ok = 1;
            if (cpu_state == cpu_state_trap)    cpu_state_ok = 1;
            assert (cpu_state_ok);
        end
    end
    // ---------------------------------------------------------------------
    // PC always aligned
    always @(posedge clk) begin
        if (!rst) assert(pc[1:0] == 0);
    end
    // ---------------------------------------------------------------------
    // verify memory port
    // Check valid signal.
    always @(posedge clk) begin
        if (!rst) begin
            case (cpu_state)
                cpu_state_fetch: begin
                    assume(!mem_ready);
                    assume(!mem_error);
                    assert(mem_address[1:0] == 0); // always aligned
                    assert(mem_valid == 1);
                end
                cpu_state_mem: begin
                    assume(!mem_ready);
                    assume(!mem_error);
                    if (is_s) assert(|mem_wsel);
                    if (is_l) assert(mem_wsel == 0);
                    assert(mem_valid == mem_enable); // FIXME mem_enable is not defined
                end
                default: begin
                    assert(mem_valid == 0);
                end
            endcase
        end
    end
    // After reset, mem_ready must be zero.
    always @(posedge clk) begin
        if (fv_valid && $past(rst)) begin
            assume(!mem_ready);
            assume(!mem_error);
            assert(!mem_valid);
        end
    end
    // check end of transaction
    always @(posedge clk) begin
        if (fv_valid && $past(mem_ready) && $past(mem_valid)) assert(!mem_valid);
        if (fv_valid && $past(mem_error) && $past(mem_valid)) assert(!mem_valid);
    end
    // error and ready must not be high at the same time
    always @(*) begin
        assume(!mem_ready || !mem_error);
    end
    // mem_wsel must be valid: 0000, 1111, 1100, 0011, 1000, 0100, 0010, 0001
    reg mem_wsel_ok;
    always @(*) begin
        mem_wsel_ok = 0;
        if(mem_wsel_ok == 4'b0000) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b1111) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b1100) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b0011) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b1000) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b0100) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b0010) mem_wsel_ok = 1;
        if(mem_wsel_ok == 4'b0001) mem_wsel_ok = 1;
        assert(mem_wsel_ok);
    end
    // ---------------------------------------------------------------------
    // check interrupts
    always @(posedge clk) begin
        if (fv_valid && interrupt) begin
            assert($past(mstatus_mie) && |{$past(mie_meie), $past(mie_msie), $past(mie_mtie)});
        end
    end
    // ---------------------------------------------------------------------
`endif
    // =====================================================================
    // unused signals: remove verilator warnings about unused signal
    wire _unused = &{dbg_ascii_state};
    // =====================================================================
endmodule
`default_nettype wire
// EOF
