![logo](documentation/img/logo.png)

# ALGOL - A RISC-V CPU


Algol is a CPU core that implements the [RISC-V RV32I Instruction
Set](http://riscv.org/).

Algol is free and open hardware licensed under the [MIT
license](https://en.wikipedia.org/wiki/MIT_License).

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [ALGOL - A RISC-V CPU](#algol---a-risc-v-cpu)
    - [CPU core details](#cpu-core-details)
    - [Project Details](#project-details)
    - [Directory Layout](#directory-layout)
    - [RISC-V toolchain](#risc-v-toolchain)
    - [Verilog module parameters](#verilog-module-parameters)
    - [Native memory interface](#native-memory-interface)
    - [Simulation](#simulation)
        - [Dependencies for simulation](#dependencies-for-simulation)
        - [Compile assembly tests and benchmarks](#compile-assembly-tests-and-benchmarks)
        - [Simulate the CPU](#simulate-the-cpu)
            - [Parameters of the C++ model](#parameters-of-the-c-model)
    - [License](#license)

<!-- markdown-toc end -->

## CPU core details

- RISC-V RV32I ISA.
- Machine [privilege mode](https://riscv.org/specifications/privileged-isa/).
  Current version: v1.10.
- Multi-cycle datapath, with an average Cycles per Instruction (CPI) of 3.8.
- Single memory port using the a native interface.

## Project Details

- Simulation done in C++ using
  [Verilator](https://www.veripool.org/wiki/verilator).
- [Toolchain](http://riscv.org/software-tools/) using gcc.
- [Validation suit](http://riscv.org/software-tools/riscv-tests/) written in
  assembly.
- [Benchmarks](http://riscv.org/software-tools/riscv-tests/) written in C.

## Directory Layout

- `README.md`: This file.
- `hardware`: CPU source files written in Verilog.
- `documentation`: LaTeX source files for the CPU manuals (TODO).
- `scripts`: Scripts for Formal Verification (FV) and synthesis tools.
- `tests`: Test environment for the CPU.
    - `benchmarks`: Basic benchmarks written in C. Taken from
      [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev
      b747a10).
    - `extra_tests`: Aditional test for the software, timer and external interrupt interface.
    - `riscv-tests`: Basic instruction-level tests. Taken from
      [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev
      b747a10).
    - `verilator`: C++ testbench for the CPU validation.

## RISC-V toolchain

The easy way to get the toolchain is to download a pre-compiled version from
the [GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/) project.

The version used to compile the tests is the [Embedded GCC
v7.2.0-4-20180606](https://gnu-mcu-eclipse.github.io/blog/2018/06/07/riscv-none-gcc-v7-2-0-4-20180606-released/)

## Verilog module parameters

The following parameters can be used to configure the cpu core.

- **HART_ID (default = 0)**: This sets the ID of the core (for multi-core applications).
- **RESET_ADDR (default = 0x80000000)**: The start address of the program.
- **ENABLE_COUNTERS (default = 1)**: Add support for the `CYCLE[H]` and
`INSTRET[H]` counters. If set to zero, reading the counters will return zero or
a random number.

## Native memory interface

The native memory interface is just a simple valid-ready interface, one
transaction at a time.

    output reg [31:0] mem_address
    output reg [31:0] mem_wdata
    output reg [3:0]  mem_wsel
    output reg        mem_valid
    input wire [31:0] mem_rdata
    input wire        mem_ready
    input wire        mem_error

The core initiates a memory transfer by asserting `mem_valid`, and stays high
until the slave asserts `mem_ready` or `mem_error`. Over the `mem_valid` period,
the output signals are stable.

In the following image, two bus transactions requests are issued, one read and
one write. In the read transaction, `mem_wsel` must be zero, and `mem_wdata` is
ignored. In write transaction, `mem_wsel` is not zero, and `mem_rdata` is ignored.

![logo](documentation/img/mem_interface.svg)

## Simulation
### Dependencies for simulation

- [Verilator](https://www.veripool.org/wiki/verilator) for simulation. Minimum
  version: 3.884.
- libelf.
- A RISC-V toolchain, to compile the validation tests and benchmarks.

### Compile assembly tests and benchmarks
The instruction-level tests are from the
[riscv-tests](http://riscv.org/software-tools/riscv-tests/) repository.
The original makefile has been modified to use the toolchain from [GNU MCU
Eclipse](https://gnu-mcu-eclipse.github.io/).

To compile the RISC-V instruction-level tests, benchmarks and extra-tests:

> $ make compile-tests

### Simulate the CPU
To perform the simulation, execute the following commands in the root folder of
the project:

- To execute all the tests, without VCD dumps:

> $ make run-tests

- To execute a single `.elf` file:

> $ Algol.exe --file [ELF file] --timeout [max simulation time] --trace

#### Parameters of the C++ model

- **file**: RISC-V ELF file to execute.
- **timeout (optional)**: Maximum simulation time before aborting.
- **trace (optional)**: Enable VCD dumps. Writes the output file to `build/vcd/trace.vcd`.

License
-------
Copyright (c) 2018 Angel Terrones (<angelterrones@gmail.com>).

Release under the [MIT License](MITlicense.md).
