![logo](documentation/img/logo.png)

ALGOL - A RISC-V CPU
====================

Algol is a set of CPU cores that implement the [RISC-V RV32I Instruction Set](http://riscv.org/).

Algol is free and open hardware licensed under the [MIT license](https://en.wikipedia.org/wiki/MIT_License).

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [ALGOL - A RISC-V CPU](#algol---a-risc-v-cpu)
    - [Dependencies](#dependencies)
    - [Processor details](#processor-details)
        - [Core A: Beta Persei Aa1.](#core-a-beta-persei-aa1)
        - [Core B: Beta Persei Aa2.](#core-b-beta-persei-aa2)
    - [Software Details](#software-details)
    - [Directory Layout](#directory-layout)
    - [Validation](#validation)
        - [Compile assembly tests](#compile-assembly-tests)
        - [Validate cores](#validate-cores)
    - [RISC-V toolchain](#risc-v-toolchain)
    - [TODO](#todo)
    - [License](#license)

<!-- markdown-toc end -->
Dependencies
------------
- Python 3.
- pytest.
- [myhdl](https://github.com/myhdl/myhdl).
- [Icarus Verilog](http://iverilog.icarus.com).
- [Atik](https://github.com/AngelTerrones/Atik).
- RISC-V toolchain, to compile the validation tests.

Processor details
-----------------
- RISC-V RV32I ISA.
- Support for the Machine and User [privilege modes](https://riscv.org/specifications/privileged-isa/). Current version: v1.10.
- Multi-cycle datapath.
- Single memory port using the [Wishbone B4](https://www.ohwr.org/attachments/179/wbspec_b4.pdf) Interface.
- Single verilog file with the core implementation.

Software Details
----------------
- Simulation done in python using [MyHDL](http://myhdl.org/) and [Icarus Verilog](http://iverilog.icarus.com).
- [Toolchain](http://riscv.org/software-tools/) using gcc.
- [Validation suit](http://riscv.org/software-tools/riscv-tests/) written in assembly

Directory Layout
----------------
- `algol.v`: Verilog file describing the CPU.
- `README.md`: This file.
- `documentation`: LaTeX source files for the CPU manuals (TODO).
- `tests`: Test environment for the Algol CPU.
    - `python`: Python testbench for the CPU validation.
    - `riscv-tests`: Basic instruction-level tests. Taken from [riscv-tests](http://riscv.org/software-tools/riscv-tests/) (git rev b747a10**).
    - `settings`: Basic CPU configuration files.

Validation
----------
### Compile assembly tests
The instruction-level tests are from the [riscv-tests](http://riscv.org/software-tools/riscv-tests/) repository.
The original makefile has been modified to use the toolchain from [GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/).

To compile the RISC-V instruction-level tests:

> $ make compile-tests

### Validate cores
To validate the cores using the [validation suit](http://riscv.org/software-tools/riscv-tests/) (No VCD dumps):

> $ make run-riscv-tests-all

To validate using a single ISA test:

> $ python3 tests/python/test_core.py \--elf tests/riscv-tests/[elf file] \--config-file tests/settings/[ini file]

To enable dump of VCD files (single ISA test), add the `--trace` flag.

RISC-V toolchain
----------------
The easy way to get the toolchain is to download a pre-compiled version from the
[GNU MCU Eclipse](https://gnu-mcu-eclipse.github.io/) project.

The version used to validate this core is the [Embedded GCC v7.2.0-1-20171109](https://gnu-mcu-eclipse.github.io/blog/2017/11/09/riscv-none-gcc-v7-2-0-1-20171109-released/)

TODO
----
- RV32M ISA.
- Basic memory protection (Configurable Machine and User memory regions).
- Debug module.

License
-------
Copyright (c) 2017 Angel Terrones (<angelterrones@gmail.com>).

Release under the [MIT License](MITlicense.md).
