#!/usr/bin/env python3
# Copyright (c) 2016 Angel Terrones <angelterrones@gmail.com>

"""Platform-Level Interrupt Controller (PLIC)"""

import myhdl as hdl
from atik.utils import createSignal
from atik.system.interconnect import WishboneSlave
from atik.utils import Configuration


class PLICAddressMap:
    # maximum size: 64 MB
    ADDR_MASK    = 0x0000_0FFF
    BASE_PENDING = 0x0000_0000  # 1 register
    BASE_ENABLE  = 0x0000_0004  # 1 register
    BASE_CLAIM   = 0x0000_0008  # 1 register
    LAST_ADDR    = 0x0000_0FFF


@hdl.block
def PLIC(clk_i, rst_i, wbs_io, eip_o, xinterrupts_i, config):
    """
    Platform-Level Interrupt Controller

    Hard-wired threshold to 0: no interrupts masked.
    Hard-wired priority to 1: priority is the interrupt ID.
    """
    assert isinstance(wbs_io, WishboneSlave), "[PLIC] Error: wbs_io must be of type WishboneSlave."
    assert isinstance(config, Configuration), "[PLIC] Error: config must be of type Configuration."
    assert len(xinterrupts_i) == 31, "[PLIC] Error: xinterrupts_i length must be 31."
    assert len(eip_o) == 1, "[PLIC] Error: Support for single core only."

    # PLIC registers
    nsources  = 32
    idxBits   = 5  # needs 5 bits to address 31 interrupt sources + 0 (no interrupts)
    ip        = createSignal(0, nsources)
    ie        = createSignal(0, nsources)
    claim     = createSignal(0, idxBits)
    # aux
    is_ip     = createSignal(0, 1)
    is_ie     = createSignal(0, 1)
    is_claim  = createSignal(0, 1)
    gate_xint = createSignal(0, nsources)
    _xint     = createSignal(0, nsources)
    _claim    = createSignal(0, idxBits)
    _eip      = createSignal(0, 1)
    # wishbone
    _we       = createSignal(0, 1)
    _ack      = createSignal(0, 1)
    _err      = createSignal(0, 1)
    _dat_o    = createSignal(0, 32)

    @hdl.always_comb
    def wb_assign_proc():
        wbs_io.ack_o.next = _ack
        wbs_io.err_o.next = _err
        wbs_io.dat_o.next = _dat_o

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def ack_err_proc():
        _ack.next = wbs_io.cyc_i and wbs_io.stb_i and not _ack and (is_ip or is_ie or is_claim)
        _err.next = wbs_io.cyc_i and wbs_io.stb_i and not _err and not (is_ip or is_ie or is_claim)

    @hdl.always_comb
    def we_assign_proc():
        _we.next = wbs_io.cyc_i and wbs_io.stb_i and wbs_io.we_i and wbs_io.sel_i == 0b1111

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def gateway_proc():
        # latch only if no previous interrupt, and interrupt completion
        """ verilator lint_off WIDTH """
        _xint.next = hdl.concat(xinterrupts_i, False)
        for ii in range(nsources):
            if not gate_xint[ii]:
                gate_xint.next[ii] = _xint[ii]
            elif is_claim and _we and ii == wbs_io.dat_i:
                gate_xint.next[ii] = False
        """ verilator lint_off WIDTH """

    @hdl.always_comb
    def x_access_proc():
        is_ip.next    = (wbs_io.addr_i & PLICAddressMap.ADDR_MASK) == PLICAddressMap.BASE_PENDING and not wbs_io.we_i
        is_ie.next    = (wbs_io.addr_i & PLICAddressMap.ADDR_MASK) == PLICAddressMap.BASE_ENABLE
        is_claim.next = (wbs_io.addr_i & PLICAddressMap.ADDR_MASK) == PLICAddressMap.BASE_CLAIM

    # read registers
    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def read_proc():
        if is_ip:
            _dat_o.next = ip
        elif is_ie:
            _dat_o.next = ie
        elif is_claim:
            _dat_o.next = hdl.concat(hdl.modbv(0)[32 - len(claim):], claim)
        else:
            _dat_o.next = 0

    # write registers
    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def ip_write_proc():
        # this register is RO to user.
        if is_claim and not _we:
            ip.next[claim] = False
        else:
            ip.next = gate_xint

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def ie_write_proc():
        if is_ie and _we:
            ie.next = hdl.concat(wbs_io.dat_i[31:1], False)

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def claim_write_proc():
        if is_claim and _we:
            if claim == wbs_io.dat_i:
                claim.next = 0
        else:
            claim.next = _claim

    # get the interrupt source
    @hdl.always_comb
    def get_interrupt_source_proc():
        _id = 0
        for source in range(nsources):
            if ip[source] and ie[source]:
                _id = source
        _eip.next   = _id
        _claim.next = _id

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def eip_assign_proc():
        eip_o.next = _eip

    return hdl.instances()

# Local Variables:
# flycheck-flake8-maximum-line-length: 300
# flycheck-flake8rc: ".flake8rc"
# End:
