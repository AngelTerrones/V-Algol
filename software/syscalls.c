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
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>
#include <sys/stat.h>

// exception cause values
#define X_INST_ADDRESS_MISA    0
#define X_INST_ACCESS_FAULT    1
#define X_ILLEGAL_INSTRUCTION  2
#define X_BREAKPOINT           3
#define X_LOAD_ADDRESS_MISA    4
#define X_LOAD_ACCESS_FAULT    5
#define X_STORE_ADDRESS_MISA   6
#define X_STORE_ACCESS_FAULT   7
#define X_UCALL                8
#define X_SCALL                9
#define X_MCALL                11
// interrupt cause values
#define I_USER_SW_INT          ((1 << 31) | 0)
#define I_SUPERVISOR_SW_INT    ((1 << 31) | 1)
#define I_MACHINE_SW_INT       ((1 << 31) | 3)
#define I_USER_TIMER_INT       ((1 << 31) | 4)
#define I_SUPERVISOR_TIMER_INT ((1 << 31) | 5)
#define I_MACHINE_TIMER_INT    ((1 << 31) | 7)
#define I_USER_X_INT           ((1 << 31) | 8)
#define I_SUPERVISOR_X_INT     ((1 << 31) | 9)
#define I_MACHINE_X_INT        ((1 << 31) | 11)
// Output device address
#define CONSOLE_BUFFER 0x10000000
#define CONSOLE_FLUSH  0x10000004
// Code placement
#define UNIMP_FUNC(__f) ".globl " #__f "\n.type " #__f ", @function\n" #__f ":\n"

// Private (machine) variables.
extern volatile uint64_t tohost;

// -----------------------------------------------------------------------------
// for simulation purposes: write to tohost address.
void tohost_exit(uintptr_t code) {
        tohost = (code << 1) | 1;
        while(1);
        __builtin_unreachable();
}

// C trap handler
uintptr_t handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32])
{
        // TODO: improve trap handler
        switch (cause){
        case X_INST_ADDRESS_MISA:
                printf("Instruction fetch misaligned.\n");
                break;
        case X_INST_ACCESS_FAULT:
                printf("Instruction fetch error.\n");
                break;
        case X_ILLEGAL_INSTRUCTION:
                printf("Illegal instruction.\n");
                break;
        case X_LOAD_ADDRESS_MISA:
                printf("Load address misaligned.\n");
                break;
        case X_LOAD_ACCESS_FAULT:
                printf("Load access error.\n");
                break;
        case X_STORE_ADDRESS_MISA:
                printf("Store address misaligned.\n");
                break;
        case X_STORE_ACCESS_FAULT:
                printf("Store access error.\n");
                break;
        case X_UCALL:
                printf("Environmental call");
                break;
        default:
                // unimplemented handler. GTFO.
                printf("Unimplemented handler.\n");
        }
        tohost_exit(cause);
        __builtin_unreachable();
        return epc + 4; //WARNING: Will never reach (for now)
}

// -----------------------------------------------------------------------------
// Syscalls: Taken from the picorv32 repository (with some modifications)
// Copyright (C) 2015  Clifford Wolf <clifford@clifford.at>

// read syscall. Does nothing for now.
// TODO: implement for input device
ssize_t _read(int file, void *ptr, size_t len) {
        return 0;
}

// write syscall.
ssize_t _write(int file, const void *ptr, size_t len) {
        // Writes to STDOUT and STDERR: to output device.
        // everything else: ignore.
        // Other devices: Use a custom write function =)
        if (file != STDOUT_FILENO && file != STDERR_FILENO)
                return -1;
        const void *eptr = ptr + len;
        while(ptr != eptr)
                *(volatile int*)CONSOLE_BUFFER = *(char *)(ptr++);
        return len;
}

// close syscall
ssize_t _close(int file) {
        return 0;
}

//
ssize_t _fstat(int file, struct stat *st) {
        errno = ENOENT;
        return -1;
}

//
void *_sbrk(ptrdiff_t incr) {
        extern unsigned char _end[]; // defined by the linker
        static unsigned long heap_end = 0;

        if (heap_end == 0)
                heap_end = (long)_end;
        heap_end += incr;
        return (void *)(heap_end - incr);
}

// exit syscall
void _exit(int code) {
        tohost_exit(code);
        __builtin_unreachable();
}

asm (
        ".section .text;"
        ".align 2;"
        UNIMP_FUNC(_open)
        UNIMP_FUNC(_openat)
        UNIMP_FUNC(_lseek)
        UNIMP_FUNC(_stat)
        UNIMP_FUNC(_lstat)
        UNIMP_FUNC(_fstatat)
        UNIMP_FUNC(_isatty)
        UNIMP_FUNC(_access)
        UNIMP_FUNC(_faccessat)
        UNIMP_FUNC(_link)
        UNIMP_FUNC(_unlink)
        UNIMP_FUNC(_execve)
        UNIMP_FUNC(_getpid)
        UNIMP_FUNC(_fork)
        UNIMP_FUNC(_kill)
        UNIMP_FUNC(_wait)
        UNIMP_FUNC(_times)
        UNIMP_FUNC(_gettimeofday)
        UNIMP_FUNC(_ftime)
        UNIMP_FUNC(_utime)
        UNIMP_FUNC(_chown)
        UNIMP_FUNC(_chmod)
        UNIMP_FUNC(_chdir)
        UNIMP_FUNC(_getcwd)
        UNIMP_FUNC(_sysconf)
        "j unimplemented_syscall;"
        );

void unimplemented_syscall() {
        printf("Unimplemented syscall! Abort()\n");
        _exit(-1);
        __builtin_unreachable();
}

// -----------------------------------------------------------------------------
// placeholder.
int __attribute__((weak)) main(int argc, char* argv[]){
        printf("[SYSCALL] Weak main: implement your own!\n");
        return -1;
}

// configure the call to main()
void _init() {
        int rcode = main(0, 0);
        _exit(rcode);
        __builtin_unreachable();
}
