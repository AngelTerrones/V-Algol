#!/usr/bin/env python3
# Copyright (c) 2017 Angel Terrones <angelterrones@gmail.com>

import os
import struct
import argparse
import myhdl as hdl
from atik.system import Clock
from atik.system import Reset
from atik.system import Timeout
from atik.utils import createSignal
from atik.utils import Configuration
from atik.utils import run_parser
from atik.utils import run_testbench
from atik.system.interconnect import WishboneIntercon
from atik.models.Memory import WBMemory


def syscall_print(memory, base_addr):
    int2byte = struct.Struct('<I').pack
    dat_addr = (memory[base_addr + 4] + 3) >> 2  # data MUST BE aligned (64)
    size     = memory[base_addr + 6]
    data     = bytes()
    for ii in range((size + 3) >> 2):
        data = data + int2byte(memory[dat_addr + ii])
    return data[:size].decode('ascii')


def generate_testbench(filename, params):
    with open('tests/python/tb_core_template.v', 'r') as f:
        tb = f.read()

    with open('build/tb_{}.v'.format(filename), 'w') as f:
        f.write(tb.format(**params))


def test_core(elf, config_file):
    """Stub for pytest
    """
    args = argparse.Namespace(elf=elf, config_file=config_file, trace=False)
    core_testbench(args)


def core_testbench(args=None):
    config       = Configuration(args.config_file)
    timescale    = 1e-9
    freq         = 10e6
    rst_addr     = config.getOption('Core', 'start_address')
    memsize      = config.getOption('Simulation', 'mem_size')
    tohost       = config.getOption('Simulation', 'tohost_address')
    fromhost     = config.getOption('Simulation', 'fromhost_address')
    syscall_code = config.getOption('Simulation', 'syscall_code')
    clk          = Clock(0, freq=freq, timescale=timescale)
    rst          = Reset(0, active=True, async=False)
    timeout      = Timeout(1e9)

    @hdl.block
    def tb_core():
        wb_port    = WishboneIntercon()
        meip       = createSignal(0, 1)
        mtip       = createSignal(0, 1)
        msip       = createSignal(0, 1)
        clkgen     = clk.clk_gen()  # noqa
        tout       = timeout.timeout_gen()  # noqa
        memory     = WBMemory(size=memsize, elf_file=args.elf)
        test_mem   = memory.WBMemorySP(clk_i=clk, rst_i=rst, io_port=wb_port)  # noqa
        bname      = os.path.splitext(os.path.basename(args.config_file))[0]
        vname      = 'core_{}'.format(bname)
        trace      = '-DTRACE' if args.trace else ''
        cmd1       = 'iverilog {trace} -o ./build/dut.o ./algol.v ./build/tb_{0}.v'.format(vname, trace=trace)
        cmd2       = 'vvp -m myhdl ./build/dut.o'
        os.makedirs('./build/', exist_ok=True)
        generate_testbench(vname, dict(HART_ID=0, RESET_ADDR=rst_addr))

        def core_compilation(clk, rst, io_port, meip, mtip, msip):
            os.system(cmd1)
            return hdl.Cosimulation(cmd2,
                                    clk_i=clk,
                                    rst_i=rst,
                                    wbm_addr_o=io_port.addr,
                                    wbm_dat_o=io_port.dat_o,
                                    wbm_dat_i=io_port.dat_i,
                                    wbm_sel_o=io_port.sel,
                                    wbm_cyc_o=io_port.cyc,
                                    wbm_we_o=io_port.we,
                                    wbm_stb_o=io_port.stb,
                                    wbm_ack_i=io_port.ack,
                                    wbm_err_i=io_port.err,
                                    xint_meip_i=meip,
                                    xint_mtip_i=mtip,
                                    xint_msip_i=msip)

        @hdl.instance
        def rst_pulse():
            yield rst.pulse(300)

        @hdl.always(clk.posedge)
        def to_host_check():
            if wb_port.addr == tohost and wb_port.cyc and wb_port.stb and wb_port.we and wb_port.ack:
                if wb_port.dat_o != 1:
                    # check for syscall.
                    data0 = wb_port.dat_o >> 2
                    data1 = data0 + 2
                    if memory.memory[data0] == syscall_code and memory.memory[data1] == 1:
                        memory.memory[fromhost >> 2] = 1
                        print('--------------------------------------------------------------------------------')
                        print('[SYSCALL]\n{}'.format(syscall_print(memory.memory, data0)))
                        print('--------------------------------------------------------------------------------')
                    else:
                        raise hdl.Error(" Test failed. to_host = {0}. Time = {1} ".format(wb_port.dat_o, hdl.now()))
                else:
                    print("Simulation OK. Simulation time: {0}".format(hdl.now()))
                    raise hdl.StopSimulation

        return hdl.instances(), core_compilation(clk, rst, wb_port, meip, mtip, msip)

    run_testbench(tb_core, args=args, cosim=True, timescale=timescale)


if __name__ == '__main__':
    args = run_parser(extra_ops=[('--elf', dict(required=True)), ('--config-file', dict(required=True))])
    core_testbench(args)
    print('[TEST-ALGOL {}] Test: Ok'.format(os.path.basename(args.elf)))

# Local Variables:
# flycheck-flake8-maximum-line-length: 200
# flycheck-flake8rc: ".flake8rc"
# End:
