/*
 * Algol - A RISC-V (RV32I) Processor Core.
 *
 * Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
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

#include <stdio.h>
#include <stdint.h>
#include "syscall.h"

// exception cause
#define X_INST_ADDRESS_MISA    0
#define X_INST_ACCESS_FAULT    1
#define X_ILLEGAL_INSTRUCTION  2
#define X_BREAKPOINT           3
#define X_LOAD_ADDR_MISA       4
#define X_LOAD_ACCESS_FAULT    5
#define X_STORE_ADDRESS_MISA   6
#define X_STORE_ACCESS_FAULT   7
#define X_UCALL                8
#define X_SCALL                9
#define X_MCALL                11
#define I_USER_SW_INT          ((1 << 31) | 0)
#define I_SUPERVISOR_SW_INT    ((1 << 31) | 1)
#define I_MACHINE_SW_INT       ((1 << 31) | 3)
#define I_USER_TIMER_INT       ((1 << 31) | 4)
#define I_SUPERVISOR_TIMER_INT ((1 << 31) | 5)
#define I_MACHINE_TIMER_INT    ((1 << 31) | 7)
#define I_USER_X_INT           ((1 << 31) | 8)
#define I_SUPERVISOR_X_INT     ((1 << 31) | 9)
#define I_MACHINE_X_INT        ((1 << 31) | 11)

#define LOCATE_FUNC __attribute__((__section__(".text.mcode")))
extern volatile uint64_t tohost;

// for simulation purposes: write to tohost address.
void __attribute__((noreturn)) LOCATE_FUNC tohost_exit(uintptr_t code) {
        tohost = (code << 1) | 1;
        while(1);
}

// exit syscall
void _exit(int code) {
        // Load syscall code and arguments to a0-aX, and do the call
        asm volatile ("move a1, a0;"
                      "addi a0, zero, 0;"
                      "ecall;");
        __builtin_unreachable();
}

// Check syscalls
void LOCATE_FUNC _handle_syscall(uint32_t syscode, uint32_t arg0) {
        switch (syscode) {
        case SYS_EXIT:
                tohost_exit(arg0);
                break;
        default:
                // Wrong syscode: do nothing
                break;
        }
}

// C trap handler
uintptr_t LOCATE_FUNC handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32])
{
        //printf("[SYSCALL] Weak trap handler: implement your own!\n");
        switch (cause){
        case X_UCALL:
                _handle_syscall(regs[10], regs[11]);  // x10 = syscode, x11 = first argument
                break;
        default:
                // unimplemented handler. GTFO.
                tohost_exit(0x2222);
                __builtin_unreachable();
        }
        return epc + 4; //WARNING:
}

// machine code initialization: placeholder
void __attribute__((weak)) LOCATE_FUNC platform_init() {
        //printf("[SYSCALL] Weak platform initialization: implement your own!\n");
}

// placeholder.
int __attribute__((weak)) main(int argc, char* argv[]){
        //printf("[SYSCALL] Weak main: implement your own!\n");
        return -1;
}

// configure the call to main()
void _init() {
        // TODO: do something else?
        int rcode = main(0, 0);
        _exit(rcode);
}
