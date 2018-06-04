![logo](documentation/img/logo.png)

ALGOL - A RISC-V CPU
====================

Algol is a CPU core that implements the [RISC-V RV32I Instruction Set](http://riscv.org/).

Algol is free and open hardware licensed under the [MIT license](https://en.wikipedia.org/wiki/MIT_License).

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
    - [TODO](#todo)
    - [License](#license)

<!-- markdown-toc end -->

Dependencies
------------
- [Verilator](https://www.veripool.org/wiki/verilator) for simulation.
- A RISC-V toolchain, to compile the validation tests and benchmarks.

CPU core details
-----------------
- RISC-V RV32I ISA.
- Machine [privilege mode](https://riscv.org/specifications/privileged-isa/). Current version: v1.10.
- Multi-cycle datapath.
- Single memory port using the [Wishbone B4](https://www.ohwr.org/attachments/179/wbspec_b4.pdf) Interface.

Software Details
----------------
- Simulation done in C++ using [Verilator](https://www.veripool.org/wiki/verilator).
- [Toolchain](http://riscv.org/software-tools/) using gcc.
- [Validation suit](http://riscv.org/software-tools/riscv-tests/) written in assembly.
- [Benchmarks](http://riscv.org/software-tools/riscv-tests/) written in C.

Directory Layout
----------------
- `README.md`: This file.
- `hardware`: CPU source files written in Verilog.
- `documentation`: LaTeX source files for the CPU manuals (TODO).
- `software`: Support libraries for the CPU, in C.
- `tests`: Test environment for the CPU.
    - `benchmarks`: Basic benchmarks written in C. Taken from [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev b747a10**).
    - `extra-tests`: Tests for the support libraries, and external interrupts.
    - `riscv-tests`: Basic instruction-level tests. Taken from [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev b747a10**).
    - `verilator`: C++ testbench for the CPU validation.

Validation
----------
### Compile assembly tests and benchmarks
The instruction-level tests are from the [riscv-tests](http://riscv.org/software-tools/riscv-tests/) repository.
The original makefile has been modified to use the toolchain from [GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/).

To compile the RISC-V instruction-level tests, benchmarks and extra-tests:

> $ make compile-tests

### Validate cores
To validate the cores using the [validation suit](http://riscv.org/software-tools/riscv-tests/) (No VCD dumps):

> $ make run-algol-tests

To run the model with a single `.elf` file:

> $ ./build/Algol.exe --frequency [core frequency] --timeout [max simulation time] --file [ELF file]

To enable dump of VCD files, add the `--trace` flag.

RISC-V toolchain
----------------
The easy way to get the toolchain is to download a pre-compiled version from the
[GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/) project.

The version used to validate this core is the [Embedded GCC v7.2.0-1-20171109](https://gnu-mcu-eclipse.github.io/blog/2017/11/09/riscv-none-gcc-v7-2-0-1-20171109-released/)

TODO
----
- RV32M ISA.
- Debug module.

License
-------
Copyright (c) 2018 Angel Terrones (<angelterrones@gmail.com>).

Release under the [MIT License](MITlicense.md).
