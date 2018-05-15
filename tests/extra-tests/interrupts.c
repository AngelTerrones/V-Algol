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

// Test program for external interrupts
#include <stdio.h>
#include "algol.h"

#define TRIGGER_SI_ADDR 0x20000000u
#define TRIGGER_TI_ADDR 0x20000004u
#define TRIGGER_EI_ADDR 0x20000008u

static int nint;

// Functions to trigger interrupts
void write_si(uint32_t value){
        *(volatile int *)TRIGGER_SI_ADDR = value;
}

void write_ti(uint32_t value){
        *(volatile int *)TRIGGER_TI_ADDR = value;
}

void write_ei(uint32_t value){
        *(volatile int *)TRIGGER_EI_ADDR = value;
}

// -----------------------------------------------------------------------------
// interrupt handlers
uintptr_t si_handler(uintptr_t epc, uintptr_t regs[32]){
        printf("\tSoftware Interrupt handler\n");
        write_si(0);
        nint--;
        return epc;
}

uintptr_t ti_handler(uintptr_t epc, uintptr_t regs[32]){
        printf("\tTimer Interrupt handler\n");
        write_ti(0);
        nint--;
        return epc;
}

uintptr_t ei_handler(uintptr_t epc, uintptr_t regs[32]){
        printf("\tExternal Interrupt handler\n");
        write_ei(0);
        nint--;
        return epc;
}

// -----------------------------------------------------------------------------
// Main
int main(int argc, char* argv[]) {
        // Install the interrupt handlers
        insert_ihandler(I_MACHINE_SW_INT, si_handler);
        insert_ihandler(I_MACHINE_TIMER_INT, ti_handler);
        insert_ihandler(I_MACHINE_X_INT, ei_handler);
        /*
         * Each interrupt must decrement the global variable.
         * Test will pass if nint == 0.
         */
        printf("\tBegin C Interrupt Test\n");
        nint = 3;
        enable_interrupts();
        enable_si();
        enable_ti();
        enable_ei();
        //
        write_si(0x01);
        write_ti(0x01);
        write_ei(0x01);
        //
        disable_si();
        disable_ti();
        disable_ei();
        disable_interrupts();
        printf("\tEnd test\n");
        return nint;
}
