#!/usr/bin/env python3
# Copyright (c) 2017 Angel Terrones <angelterrones@gmail.com>

"""Platform Control Registers."""

import myhdl as hdl
from atik.utils import log2up
from atik.utils import createSignal
from atik.system.interconnect import WishboneSlave
from atik.utils import Configuration


class PCRAddressMap:
    # maximum size: 64 MB
    ADDR_MASK  = 0x0000_00FF
    BASE_SIP   = 0x0000_0000  # 1 register
    BASE_TCMPL = 0x0000_0010  # 1 register
    BASE_TCMPH = 0x0000_0014  # 1 register
    BASE_TIMEL = 0x0000_0020  # 1 register
    BASE_TIMEH = 0x0000_0024  # 1 register
    LAST_ADDR  = 0x0000_00FF


@hdl.block
def PCR(clk_i, rst_i, wbs_io, sip_o, tip_o, config):
    """
    Platform Control Registers
    """
    assert isinstance(wbs_io, WishboneSlave), "[PCR] Error: wbs_io must be of type WishboneSlave."
    assert isinstance(config, Configuration), "[PCR] Error: config must be of type Configuration."
    assert len(sip_o) == 1, "[PCR] Error."
    assert len(tip_o) == 1, "[PCR] Error."

    clock_divider = config.getOption('PCR', 'clock_divider')
    _counter      = createSignal(0, log2up(clock_divider))
    # PCR registers
    _sip          = createSignal(0, 1)
    _timecmp      = createSignal(0, 64)
    _timer        = createSignal(0, 64)
    # aux
    _tip          = createSignal(0, 1)
    is_sip        = createSignal(0, 1)
    is_tcmpl      = createSignal(0, 1)
    is_tcmph      = createSignal(0, 1)
    is_timerl     = createSignal(0, 1)
    is_timerh     = createSignal(0, 1)
    valid_access  = createSignal(0, 1)
    # wishbone
    _we           = createSignal(0, 1)
    _ack          = createSignal(0, 1)
    _err          = createSignal(0, 1)
    _dat_o        = createSignal(0, 32)

    # timer interrupt
    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def clock_div_proc():
        if _counter == clock_divider - 1:
            _counter.next = 0
            _timer.next   = _timer + 1
        else:
            _counter.next = _counter + 1

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def timer_interrupt_proc():
        if (is_tcmpl or is_tcmph) and _we:
            _tip.next = False
        else:
            _tip.next = _timer >= _timecmp

    @hdl.always_comb
    def wb_assign_proc():
        wbs_io.ack_o.next = _ack
        wbs_io.err_o.next = _err
        wbs_io.dat_o.next = _dat_o

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def ack_err_proc():
        _ack.next = wbs_io.cyc_i and wbs_io.stb_i and not _ack and valid_access
        _err.next = wbs_io.cyc_i and wbs_io.stb_i and not _err and not valid_access

    @hdl.always_comb
    def we_assign_proc():
        _we.next = wbs_io.cyc_i and wbs_io.stb_i and wbs_io.we_i and wbs_io.stb_i == 0b1111

    @hdl.always_comb
    def valid_access_proc():
        valid_access.next = is_sip or is_tcmpl or is_tcmph or is_timerl or is_timerh

    @hdl.always_comb
    def x_access_proc():
        is_sip.next    = (wbs_io.addr_i & PCRAddressMap.ADDR_MASK) == PCRAddressMap.BASE_SIP
        is_tcmpl.next  = (wbs_io.addr_i & PCRAddressMap.ADDR_MASK) == PCRAddressMap.BASE_TCMPL
        is_tcmph.next  = (wbs_io.addr_i & PCRAddressMap.ADDR_MASK) == PCRAddressMap.BASE_TCMPH
        is_timerl.next = (wbs_io.addr_i & PCRAddressMap.ADDR_MASK) == PCRAddressMap.BASE_TIMEL and not wbs_io.we_i
        is_timerh.next = (wbs_io.addr_i & PCRAddressMap.ADDR_MASK) == PCRAddressMap.BASE_TIMEH and not wbs_io.we_i

    # read registers
    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def read_proc():
        if is_sip:
            _dat_o.next = _sip
        elif is_tcmpl:
            _dat_o.next = _timecmp[32:0]
        elif is_tcmph:
            _dat_o.next = _timecmp[64:32]
        elif is_timerl:
            _dat_o.next = _timer[32:0]
        elif is_timerh:
            _dat_o.next = _timer[64:32]
        else:
            _dat_o.next = 0

    # write registers
    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def sip_write_proc():
        if is_sip and _we:
            _sip.next = wbs_io.dat_i[0]

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def timercmp_write_proc():
        if is_tcmpl and _we:
            _timecmp.next[32:0] = wbs_io.dat_i
        elif is_tcmph and _we:
            _timecmp.next[64:32] = wbs_io.dat_i

    @hdl.always_seq(clk_i.posedge, reset=rst_i)
    def xip_assign_proc():
        sip_o.next = _sip
        tip_o.next = _tip

    return hdl.instances()

# Local Variables:
# flycheck-flake8-maximum-line-length: 300
# flycheck-flake8rc: ".flake8rc"
# End:
