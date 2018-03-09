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

// File: elf.cpp
// Elf loader for RISC-V ELF files

#include <assert.h>
#include <stdio.h>
#include <fcntl.h>
#include <libelf.h>
#include <gelf.h>
#include <unistd.h>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <sstream>

#include "aelf.h"

#ifndef O_BINARY
#define O_BINARY 0
#endif

// -----------------------------------------------------------------------------
bool isELF(const char *filename)
{
        FILE *fp;
        fp = fopen(filename, "rb");

        if(fp == NULL) return false;
        if(fgetc(fp) != 0x7f) return false;
        if(fgetc(fp) != 'E') return false;
        if(fgetc(fp) != 'L') return false;
        if(fgetc(fp) != 'F') return false;
        fclose(fp);
        return true;
}

void elfread(const char *filename, uint32_t &entry, ELFSECTION **&sections)
{
        // Initialize library
        if (elf_version(EV_CURRENT) == EV_NONE){
                std::cerr << "ELF library initialization failed, " << elf_errmsg(-1) << std::endl;
                exit(EXIT_FAILURE);
        }
        // open filename
        int fd = open(filename, O_RDONLY | O_BINARY, 0);
        if (fd < 0){
                std::cerr << "Unable to open file, " << filename << std::endl;
                exit(EXIT_FAILURE);
        }
        Elf *elf = elf_begin(fd, ELF_C_READ, NULL);
        if (elf == NULL){
                std::cerr << "elf_begin() failed, " << elf_errmsg(-1);
                exit(EXIT_FAILURE);
        }
        // Check ELF type
        Elf_Kind ek = elf_kind(elf);
        switch (ek){
        case ELF_K_AR:
                std::cerr << "AR archive. Abort." << std::endl;
                exit(EXIT_FAILURE);
        case ELF_K_ELF:
                break;
        case ELF_K_NONE:
                std::cerr << "Data. WTF." << std::endl;
                break;
        default:
                std::cerr << "Unrecognized ELF ????." << std::endl;
                exit(EXIT_FAILURE);
        }

        // Get ELF executable header
        GElf_Ehdr ehdr;
        if (gelf_getehdr(elf, &ehdr) == NULL){
                std::cerr << "getehdr() failed: " << elf_errmsg(-1) << std::endl;
                exit(EXIT_FAILURE);
        }
        // check ELF class
        int elfclass = gelf_getclass(elf);
        if (elfclass == ELFCLASSNONE){
                std::cerr << "getclass() failed: " << elf_errmsg(-1) << std::endl;
                exit(EXIT_FAILURE);
        }
        if (elfclass != ELFCLASS32){
                std::cerr << "64-bit ELF file. Unsupported file. Abort" << std::endl;
                exit(EXIT_FAILURE);
        }
        // get indent
        char *id = elf_getident(elf, NULL);
        if (id == NULL){
                std::cerr << "getident() failed: " << elf_errmsg(-1) << std::endl;
                exit(EXIT_FAILURE);
        }

#ifdef DEBUG
        printf("Executable header:\n");
        printf("   %-20s 0x%jx\n", "e_type", (uintmax_t)ehdr.e_type);
        printf("   %-20s 0x%jx\n", "e_machine", (uintmax_t)ehdr.e_machine);
        printf("   %-20s 0x%jx\n", "e_version", (uintmax_t)ehdr.e_version);
        printf("   %-20s 0x%jx\n", "e_entry", (uintmax_t)ehdr.e_entry);
        printf("   %-20s 0x%jx\n", "e_phoff", (uintmax_t)ehdr.e_phoff);
        printf("   %-20s 0x%jx\n", "e_shoff", (uintmax_t)ehdr.e_shoff);
        printf("   %-20s 0x%jx\n", "e_flags", (uintmax_t)ehdr.e_flags);
        printf("   %-20s 0x%jx\n", "e_ehsize", (uintmax_t)ehdr.e_ehsize);
        printf("   %-20s 0x%jx\n", "e_phentsize", (uintmax_t)ehdr.e_phentsize);
        printf("   %-20s 0x%jx\n", "e_shentsize", (uintmax_t)ehdr.e_shentsize);
#endif

        // check for a RISC-V ELF file (EM_RISCV == 243)
        if(ehdr.e_machine != 243){
                std::cerr << "This is not a RISC-V ELF file: " << ehdr.e_machine << std::endl;
                exit(EXIT_FAILURE);
        }

        // get executable header
        entry = ehdr.e_entry; // ??
        size_t n;
        if (elf_getphdrnum(elf, &n) != 0){
                std::cerr << "elf_getphdrnum() failed: " << elf_errmsg(-1) << std::endl;
                exit(EXIT_FAILURE);
        }
        assert(n != 0);

        size_t total_bytes = 0;
        GElf_Phdr phdr;

        // read program header
        for (size_t i = 0; i < n; i++){
                if (gelf_getphdr(elf, i, &phdr) != &phdr){
                        std::cerr << "getphdr() failed: " << elf_errmsg(-1) << std::endl;
                        exit(EXIT_FAILURE);
                }
#ifdef DEBUG
                printf("Program header:\n");
                printf("   %-20s 0x%jx\n", "p_type", (uintmax_t)phdr.p_type);
                printf("   %-20s 0x%jx\n", "p_offset", (uintmax_t)phdr.p_offset);
                printf("   %-20s 0x%jx\n", "p_vaddr", (uintmax_t)phdr.p_vaddr);
                printf("   %-20s 0x%jx\n", "p_paddr", (uintmax_t)phdr.p_paddr);
                printf("   %-20s 0x%jx\n", "p_filesz", (uintmax_t)phdr.p_filesz);
                printf("   %-20s 0x%jx\n", "p_memsz", (uintmax_t)phdr.p_memsz);
                printf("   %-20s 0x%jx [", "p_flags", (uintmax_t)phdr.p_flags);
                if (phdr.p_flags & PF_X) printf(" EX ");
                if (phdr.p_flags & PF_R) printf(" RD ");
                if (phdr.p_flags & PF_W) printf(" WR ");
                printf("]\n");
                printf("   %-20s 0x%jx\n", "p_align", (uintmax_t)phdr.p_align);
#endif

                total_bytes += sizeof(ELFSECTION *) + sizeof(ELFSECTION) + phdr.p_memsz;
        }
        // reserve memory for a linked list.
        char *data = new char[total_bytes + sizeof(ELFSECTION *)];
        memset(data, 0, total_bytes);

        // set the initial pointer
        sections = (ELFSECTION **)data;
        size_t current_offset = (n + 1) * sizeof(ELFSECTION *);
        for (size_t i = 0; i < n; i++){
                if (gelf_getphdr(elf, i, &phdr) != &phdr){
                        std::cerr << "getphdr() failed: " << elf_errmsg(-1) << std::endl;
                        exit(EXIT_FAILURE);
                }
                sections[i] = (ELFSECTION *)(&data[current_offset]);
                sections[i]->m_start = phdr.p_paddr;
                sections[i]->m_len   = phdr.p_filesz;
                // read/copy section
                if (lseek(fd, phdr.p_offset, SEEK_SET) < 0){
                        std::stringstream ss;
                        ss << "Unable to seek file position " << std::hex << phdr.p_offset;
                        std::cerr << ss.str() << std::endl;
                        exit(EXIT_FAILURE);
                }
                if (phdr.p_filesz > phdr.p_memsz){
                        std::cerr << "[WARNING] filesz > p_memsz" << std::endl;
                        phdr.p_filesz = 0;
                }
                if (read(fd, sections[i]->m_data, phdr.p_filesz) != (int)phdr.p_filesz){
                        std::cerr << "Unable to read the entire section." << std::endl;
                        exit(EXIT_FAILURE);
                }

                current_offset += phdr.p_memsz + sizeof(ELFSECTION);
        }

        // final pointer. Invalid data.
        sections[n] = NULL;

        elf_end(elf);
        close(fd);
}
