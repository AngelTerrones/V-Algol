![logo](documentation/img/logo.png)

# ALGOL - A RISC-V CPU


Algol is a CPU core that implements the [RISC-V RV32I Instruction
Set](http://riscv.org/).

Algol is free and open hardware licensed under the [MIT
license](https://en.wikipedia.org/wiki/MIT_License).

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [ALGOL - A RISC-V CPU](#algol---a-risc-v-cpu)
    - [Dependencies](#dependencies)
    - [CPU core details](#cpu-core-details)
    - [Software Details](#software-details)
    - [Directory Layout](#directory-layout)
    - [Validation](#validation)
        - [Compile assembly tests and benchmarks](#compile-assembly-tests-and-benchmarks)
        - [Validate cores](#validate-cores)
    - [RISC-V toolchain](#risc-v-toolchain)
    - [License](#license)

<!-- markdown-toc end -->

## CPU core details

- RISC-V RV32I ISA.
- Machine [privilege mode](https://riscv.org/specifications/privileged-isa/).
  Current version: v1.10.
- Multi-cycle datapath.
- Single memory port using the [Wishbone
  B4](https://www.ohwr.org/attachments/179/wbspec_b4.pdf) Interface.

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
- `tests`: Test environment for the CPU.
    - `benchmarks`: Basic benchmarks written in C. Taken from
      [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev
      b747a10).
    - `riscv-tests`: Basic instruction-level tests. Taken from
      [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev
      b747a10).
    - `verilator`: C++ testbench for the CPU validation.

## RISC-V toolchain

The easy way to get the toolchain is to download a pre-compiled version from
the [GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/) project.

The version used to simulate the design is the [Embedded GCC
v7.2.0-3-20180506](https://gnu-mcu-eclipse.github.io/blog/2018/05/06/riscv-none-gcc-v7-2-0-3-20180506-released/)

## Verilog module parameters

The following parameters can be used to configure the cpu core.

- **HART_ID (default = 0)**: This sets the ID of the core (for multi-core applications).
- **RESET_ADDR (default = 0x80000000)**: The start address of the program.
- **ENABLE_COUNTERS (default = 1)**: Add support for the `CYCLE[H]` and `INSTRET[H]` counters. If set to zero,
reading the counters will return zero or a random number.

## Simulation
### Dependencies for simulation

- [Verilator](https://www.veripool.org/wiki/verilator) for simulation. Minimum
  version: 3.884.
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

- To execute the C++ model with a single `.elf` file:

> $ Algol.exe --file [ELF file] --timeout [max simulation time] --trace

#### Parameters of the C++ model

- **file**: RISC-V ELF file to execute.
- **timeout**: Maximum simulation time before aborting.
- **trace (optional)**: Enable VCD dumps. Writes the output file to `build/vcd/trace.vcd`.

License
-------
Copyright (c) 2018 Angel Terrones (<angelterrones@gmail.com>).

Release under the [MIT License](MITlicense.md).
