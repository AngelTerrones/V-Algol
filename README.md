![logo](documentation/img/logo.png)

ALGOL - A RISC-V CPU system
===========================

Algol is a CPU core that implements the [RISC-V RV32I Instruction Set](http://riscv.org/).

Algol is free and open hardware licensed under the [MIT license](https://en.wikipedia.org/wiki/MIT_License).

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [ALGOL - A RISC-V CPU system](#algol---a-risc-v-cpu-system)
    - [Dependencies](#dependencies)
    - [Processor details](#processor-details)
    - [Platform details](#platform-details)
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
- Python3 and [Atik](https://github.com/AngelTerrones/Atik).
- [Verilator](https://www.veripool.org/wiki/verilator) for simulation.
- A RISC-V toolchain, to compile the validation tests and benchmarks.

CPU core details
-----------------
- RISC-V RV32I ISA.
- Support for the Machine and User [privilege modes](https://riscv.org/specifications/privileged-isa/). Current version: v1.10.
- Multi-cycle datapath.
- Machine mode have complete access to the whole address space. User mode is restricted to the first 2GB memory region: 0x00000000 to 0x7FFFFFFF.
- Single memory port using the [Wishbone B4](https://www.ohwr.org/attachments/179/wbspec_b4.pdf) Interface.

Platform details
----------------
- Basic interrupt controller based in the PLIC specification described in the [Priviledged Architecture](https://riscv.org/specifications/privileged-isa/) manual.
- Plaform control registers (PCR) implementing the system timer and the software interrupts
- Basic [Wishbone B4](https://www.ohwr.org/attachments/179/wbspec_b4.pdf) bus.
- Memory port for external memory controller.
- Memory port for external I/O bus.

Software Details
----------------
- Simulation done in C++ using [Verilator](https://www.veripool.org/wiki/verilator).
- [Toolchain](http://riscv.org/software-tools/) using gcc.
- [Validation suit](http://riscv.org/software-tools/riscv-tests/) written in assembly.
- [Benchmarks](http://riscv.org/software-tools/riscv-tests/) written in C.

Directory Layout
----------------
- `README.md`: This file.
- `Algol`: Verilog and Python source files for the Algol core system.
- `documentation`: LaTeX source files for the CPU manuals (TODO).
- `tests`: Test environment for the bPersei CPU and Algol system.
    - `benchmarks`: Basic benchmarks written in C. Taken from [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev b747a10**).
    - `riscv-tests`: Basic instruction-level tests. Taken from [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev b747a10**).
    - `settings`: Basic CPU configuration files.
    - `verilator`: C++ testbench for the CPU validation.

Validation
----------
### Compile assembly tests and benchmarks
The instruction-level tests are from the [riscv-tests](http://riscv.org/software-tools/riscv-tests/) repository.
The original makefile has been modified to use the toolchain from [GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/).

To compile the RISC-V instruction-level tests:

> $ make compile-tests

To compile the RISC-V benchmarks:

> $ make compile-benchmarks

### Validate cores
To validate the cores using the [validation suit](http://riscv.org/software-tools/riscv-tests/) (No VCD dumps):

> $ make run-algol-tests

To run the benchmarks (no test output, no dumps):

> $ make run-algol-benchmarks

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
