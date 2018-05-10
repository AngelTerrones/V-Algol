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
#define X_LOAD_ADDR_MISA       4
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
// syscalls definition
#define SYS_EXIT  0
#define SYS_READ  1
#define SYS_WRITE 2
// Console device address
#define CONSOLE_BUFFER 0x80000000
#define CONSOLE_FLUSH  0x80000004
// Code placement
#define LOCATE_FUNC __attribute__((__section__(".text.mcode")))
#define UNIMP_FUNC(__f) ".globl " #__f "\n.type " #__f ", @function\n" #__f ":\n"

// Private (machine) variables.
extern volatile uint64_t tohost;

// -----------------------------------------------------------------------------
// for simulation purposes: write to tohost address.
void LOCATE_FUNC tohost_exit(uintptr_t code) {
        tohost = (code << 1) | 1;
        while(1);
        __builtin_unreachable();
}

// Check syscalls
// Abort execution/simulation for invalid syscode.
void LOCATE_FUNC _handle_syscall(uint32_t syscode, uint32_t arg0, uint32_t arg1, uint32_t arg2) {
        switch (syscode) {
        case SYS_EXIT:
                tohost_exit(arg0);
                break;
        case SYS_WRITE: {
                void       *ptr    = (void *)arg1;
                size_t      len    = arg2;
                const void *endptr = ptr + len;
                volatile int *_stdout = (volatile int *)arg0;
                while (ptr != endptr)
                        *_stdout = *(char *)(ptr++);
                break;
        }
        default:
                // Wrong syscode: abort :)
                tohost_exit(1);
                __builtin_unreachable();
        }
}

// C trap handler
uintptr_t LOCATE_FUNC handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32])
{
        switch (cause){
        case X_UCALL:
                _handle_syscall(regs[10], regs[11], regs[12], regs[13]);  // x10 = syscode, x11 = first argument
                break;
        default:
                // unimplemented handler. GTFO.
                tohost_exit(cause);
                __builtin_unreachable();
        }
        return epc + 4; //WARNING:
}

// machine code initialization: placeholder
void LOCATE_FUNC platform_init() {
        // TODO: DO SOMETHING!!
}

// -----------------------------------------------------------------------------
// read syscall. Does nothing for now.
ssize_t _read(int file, void *ptr, size_t len) {
        return 0;
}

// write syscall.
ssize_t _write(int file, const void *ptr, size_t len) {
        // For stdout, file == 1.
        // Maybe create a map file -> device address/function to perform the requested write (via syscalls)
        if (file != STDOUT_FILENO)
                return -1;
        asm volatile ("move a3, %0;" : : "r" (len));
        asm volatile ("move a2, %0;" : : "r" (ptr));
        asm volatile ("li a1, %0" : : "rn" (CONSOLE_BUFFER));
        asm volatile ("li a0, %0;" : : "I" (SYS_WRITE));
        asm volatile ("ecall;");
        return 0;
}

// close syscall
ssize_t _close(int file) {
        return 0;
}

ssize_t _fstat(int file, struct stat *st) {
        errno = ENOENT;
        return -1;
}

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
        // Load syscall code and arguments to a0-aX, and do the call
        asm volatile ("move a1, a0;"
                      "li a0, %0;"
                      "ecall;"
                      :
                      : "I" (SYS_EXIT));
        __builtin_unreachable();
}

// Taken from picorv32 repository (with some modifications)
// Copyright (C) 2015  Clifford Wolf <clifford@clifford.at>
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
        // TODO: print error
        _exit(-1);
        __builtin_unreachable();
}

// -----------------------------------------------------------------------------
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
