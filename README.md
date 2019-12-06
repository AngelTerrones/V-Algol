![logo](documentation/img/logo.png)

Algol is a CPU core that implements the [RISC-V RV32IM Instruction Set][1].

Algol is free and open hardware licensed under the [MITlicense](https://en.wikipedia.org/wiki/MIT_License).

**Table of Contents**
<!-- TOC -->

- [CPU core details](#cpu-core-details)
- [Project Details](#project-details)
- [Directory Layout](#directory-layout)
- [RISC-V toolchain](#risc-v-toolchain)
- [Verilog module parameters](#verilog-module-parameters)
- [Native memory interface](#native-memory-interface)
- [Simulation](#simulation)
    - [Dependencies for simulation](#dependencies-for-simulation)
    - [Download the compliance tests](#download-the-compliance-tests)
    - [Define `RVGCC_PATH`](#define-rvgcc_path)
    - [Generate the C++ model and compile it](#generate-the-c-model-and-compile-it)
    - [Run the compliance tests](#run-the-compliance-tests)
    - [Simulate execution of a single ELF file](#simulate-execution-of-a-single-elf-file)
        - [Parameters of the C++ model](#parameters-of-the-c-model)

<!-- /TOC -->

## CPU core details

- RISC-V RV32I[M] ISA.
- Machine [privilege mode][2], version: v1.11.
- Multi-cycle datapath, with an average Cycles per Instruction (CPI) of 3.8.
- Single memory port using the a native interface.

## Project Details

- Simulation done in C++ using [Verilator][4]
- [Toolchain][7] using gcc.
- [Validation suit][5] written in assembly.

## Directory Layout

- `documentation`: laTeX source files for the CPU manuals (TODO).
- `rtl`: CPU source files written in Verilog.
- `scripts`: scripts for installation of compliance tests, and setup development environment.
- `simulator`: verilator testbench, written in C++.
- `soc`: source files, written in Verilog, for a simple SoC demo.
- `software`: support files for the SoC (bootloader, loader), and the dhrystone benchmark.
- `tests`: assembly test environment for the CPU.
  - `extra_tests`: aditional test for the software, timer and external interrupt interface.
- `LICENSE`: MIT license.
- `README.md`: this file.

## RISC-V toolchain

The easy way to get the toolchain is to download a prebuilt version from [SiFive][6].

The version used to compile the tests is [riscv64-unknown-elf-gcc-8.3.0-2019.08.0][7]

## Verilog module parameters

The following parameters can be used to configure the cpu core.

- `HART_ID`: (default = 0) This sets the ID of the core (for multi-core applications).
- `RESET_ADDR`: (default = 0x80000000) The start address of the program.
- `FAST_SHIFT`: (default = 0) Enable the use of a barrel shifter.
- `ENABLE_RV32M`: (default = 0) Enable the hardware multiplier and divider.
- `ENABLE_COUNTERS`: (default = 1) Add support for the `CYCLE[H]` and
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

- [Verilator][4]. Minimum version: 4.0.
- libelf.
- The official RISC-V [toolchain][7].

### Download the compliance tests

To download the [riscv-compliance][5] repository:
> make install-compliance

This downloads a fork of [riscv-compliance][5] with added support for this core.

### Define `RVGCC_PATH`
Before running the compliance test suit, benchmarks and extra-tests, define the variable `RVGCC_PATH` to the `bin` folder of the toolchain:
> export RVGCC_PATH=/path/to/bin/folder/of/riscv-gcc

### Generate the C++ model and compile it
To compile the verilator testbench, execute the following command in the root folder of
the project:
> $ make build-core

### Run the compliance tests
To perform the simulation, execute the following command in the root folder of
the project:
> $ make core-sim-compliance

All tests should pass, with exception of the `breakpoint` test: no debug module has been implemented.

### Simulate execution of a single ELF file
To perform the simulation, execute the following commands in the root folder of
the project:

To execute a single `.elf` file:

> $ ./build/core.exe --file [ELF file] --timeout [max time] --signature [signature file] --trace

#### Parameters of the C++ model

- `file`: RISC-V ELF file to execute.
- `timeout`: (Optional) Maximum simulation time before aborting.
- `signature`: (Optional) Write memory dump to a file. For verification purposes.
- `trace`: (Optional) Enable VCD dumps. Writes the output file to `build/trace_core.vcd`.

[1]: https://riscv.org/specifications/
[2]: https://riscv.org/specifications/privileged-isa/
[3]: MITlicense.md
[4]: https://www.veripool.org/wiki/verilator
[5]: https://github.com/riscv/riscv-compliance
[6]: https://www.sifive.com/boards
[7]: https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14.tar.gz
