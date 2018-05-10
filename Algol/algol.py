#!/usr/bin/env python3
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>

import myhdl as hdl
from atik.utils import createSignal
from atik.system.interconnect import WishboneMaster
from atik.system.interconnect import WishboneSlave
from atik.utils import Configuration
from Algol.core import Core
from Algol.plic import PLIC
from Algol.pcr import PCR


class AddressMap:
    """
    Definition of memory regions for the Algol core.

    Default regions:
    - region_0_addr_init = 0x00000000 # RAM: 2 GB (external controller)
    - region_0_addr_end  = 0x7FFFFFFF #
    - region_1_addr_init = 0x80000000 # I/O: 1.5 GB (needs external bus)
    - region_1_addr_end  = 0xDFFFFFFF #
    - region_2_addr_init = 0xE0000000 # PLIC: 128 MB (internal module)
    - region_2_addr_end  = 0xE7FFFFFF #
    - region_3_addr_init = 0xE8000000 # PCR: 128 MB (internal module)
    - region_3_addr_end  = 0xEFFFFFFF #
    - region_4_addr_init = 0xF0000000 # (Unimplemented) DEBUG: 256 MB (internal module)
    - region_4_addr_end  = 0xFFFFFFFF #
    """
    # Indexes
    ram_index  = 0
    io_index   = 1
    plic_index = 2
    pcr_index  = 3

    @staticmethod
    def access_ram(address):
        return address[31] == 0

    @staticmethod
    def access_io(address):
        return address[32:30] == 0b10 or address[32:29] == 0b110

    @staticmethod
    def access_plic(address):
        return address[32:27] == 0b11100

    @staticmethod
    def access_pcr(address):
        return address[32:27] == 0b11101

    @staticmethod
    def access_debug(address):
        return address[32:28] == 0b1111


@hdl.block
def Algol(clk_i, rst_i, wbm_mem, wbm_io, xinterrupts_i, config):
    """Algol: Algol SoC"""
    assert isinstance(wbm_mem, WishboneMaster), '[Algol] Error: wbm_mem port must be of type WishboneMaster'
    assert isinstance(wbm_io, WishboneMaster), '[Algol] Error: wbm_io port must be of type WishboneMaster'
    assert isinstance(config, Configuration), '[Algol] Error: config data must be of type Configuration'

    nslaves     = 4  # ignore debug module for now.
    io_master   = WishboneMaster()
    io_slaves   = [WishboneMaster() for _ in range(nslaves)]
    wbs_plic    = WishboneSlave(io_slaves[AddressMap.plic_index])
    wbs_pcr     = WishboneSlave(io_slaves[AddressMap.pcr_index])
    slave_addr  = [io_slaves[i].addr_o for i in range(nslaves)]
    slave_dat_o = [io_slaves[i].dat_o for i in range(nslaves)]
    slave_dat_i = [io_slaves[i].dat_i for i in range(nslaves)]
    slave_sel   = [io_slaves[i].sel_o for i in range(nslaves)]
    slave_cyc   = [io_slaves[i].cyc_o for i in range(nslaves)]
    slave_we    = [io_slaves[i].we_o for i in range(nslaves)]
    slave_stb   = [io_slaves[i].stb_o for i in range(nslaves)]
    slave_ack   = [io_slaves[i].ack_i for i in range(nslaves)]
    slave_err   = [io_slaves[i].err_i for i in range(nslaves)]
    requests    = createSignal(0, nslaves)
    xint_meip   = createSignal(0, 1)
    xint_msip   = createSignal(0, 1)
    xint_mtip   = createSignal(0, 1)
    # instances
    core        = Core(clk_i=clk_i, rst_i=rst_i, wbm=io_master, xint_meip_i=xint_meip, xint_mtip_i=xint_mtip, xint_msip_i=xint_msip, hart_id=0, config=config)  # noqa
    plic        = PLIC(clk_i=clk_i, rst_i=rst_i, wbs_io=wbs_plic, eip_o=xint_meip, xinterrupts_i=xinterrupts_i, config=config)  # noqa
    pcr         = PCR(clk_i=clk_i, rst_i=rst_i, wbs_io=wbs_pcr, sip_o=xint_msip, tip_o=xint_mtip, config=config)  # noqa

    # --------------------------------------------------------------------------
    # bus
    @hdl.always_comb
    def request_access_proc():
        requests.next[AddressMap.ram_index]  = AddressMap.access_ram(io_master.addr_o)
        requests.next[AddressMap.io_index]   = AddressMap.access_io(io_master.addr_o)
        requests.next[AddressMap.plic_index] = AddressMap.access_plic(io_master.addr_o)
        requests.next[AddressMap.pcr_index]  = AddressMap.access_pcr(io_master.addr_o)

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def m2s_assign_proc():
        for ii in range(nslaves):
            slave_addr[ii].next  = io_master.addr_o
            slave_dat_o[ii].next = io_master.dat_o
            slave_sel[ii].next   = io_master.sel_o
            slave_cyc[ii].next   = requests[ii] and io_master.cyc_o and not (io_master.ack_i or io_master.err_i) and not (slave_ack[ii] or slave_err[ii])
            slave_stb[ii].next   = requests[ii] and io_master.stb_o and not (io_master.ack_i or io_master.err_i) and not (slave_ack[ii] or slave_err[ii])
            slave_we[ii].next    = requests[ii] and io_master.we_o
            if requests[ii]:
                io_master.dat_i.next = slave_dat_i[ii]
                io_master.ack_i.next = slave_ack[ii]
                io_master.err_i.next = slave_err[ii]

    @hdl.always_comb
    def mem_port_assign_proc():
        wbm_mem.addr_o.next                    = slave_addr[AddressMap.ram_index]
        wbm_mem.dat_o.next                     = slave_dat_o[AddressMap.ram_index]
        wbm_mem.sel_o.next                     = slave_sel[AddressMap.ram_index]
        wbm_mem.cyc_o.next                     = slave_cyc[AddressMap.ram_index]
        wbm_mem.stb_o.next                     = slave_stb[AddressMap.ram_index]
        wbm_mem.we_o.next                      = slave_we[AddressMap.ram_index]
        slave_dat_i[AddressMap.ram_index].next = wbm_mem.dat_i
        slave_ack[AddressMap.ram_index].next   = wbm_mem.ack_i
        slave_err[AddressMap.ram_index].next   = wbm_mem.err_i

    @hdl.always_comb
    def io_port_assign_proc():
        wbm_io.addr_o.next                    = slave_addr[AddressMap.io_index]
        wbm_io.dat_o.next                     = slave_dat_o[AddressMap.io_index]
        wbm_io.sel_o.next                     = slave_sel[AddressMap.io_index]
        wbm_io.cyc_o.next                     = slave_cyc[AddressMap.io_index]
        wbm_io.stb_o.next                     = slave_stb[AddressMap.io_index]
        wbm_io.we_o.next                      = slave_we[AddressMap.io_index]
        slave_dat_i[AddressMap.io_index].next = wbm_io.dat_i
        slave_ack[AddressMap.io_index].next   = wbm_io.ack_i
        slave_err[AddressMap.io_index].next   = wbm_io.err_i

    return hdl.instances()


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Algol (RISC-V processor).\nConvert to verilog script.', formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-c', '--config_file', help='Algol configuration file', type=str, required=True)
    parser.add_argument('-p', '--path', help='Path to store the verilog output file', type=str, required=True)
    parser.add_argument('-n', '--filename', help='Name for the verilog output file', type=str, required=True)

    args        = parser.parse_args()
    config_file = args.config_file
    path        = args.path
    filename    = args.filename
    clk_i       = createSignal(0, 1)
    rst_i       = hdl.ResetSignal(0, active=True, async=False)
    wbm_mem     = WishboneMaster()
    wbm_io      = WishboneMaster()
    xint        = createSignal(0, 31)
    config      = Configuration(config_file)
    dut         = Algol(clk_i, rst_i, wbm_mem, wbm_io, xint, config)
    dut.convert(path=path, name=filename, trace=False, testbench=False)

# Local Variables:
# flycheck-flake8-maximum-line-length: 300
# flycheck-flake8rc: ".flake8rc"
# End:
