#!/usr/bin/env python3
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>

import re
import myhdl as hdl
from atik.utils import Configuration
from atik.system.interconnect import WishboneMaster


def get_template(file):
    with open(file) as fp:
        text = re.findall("\/\/ BEGIN MYHDL TEMPLATE(.*?)\/\/ END MYHDL TEMPLATE", fp.read(), re.S)
    body = ''.join(text)
    # replace text. ORDER IS IMPORTANT
    body = body.replace('$', '$$')
    body = body.replace('clk_i', '$clk_i')
    body = body.replace('rst_i', '$rst_i')
    body = body.replace('wbm_', '$wbm_')
    body = body.replace('xint_', '$xint_')
    body = body.replace('HART_ID', '$hart_id')
    body = body.replace('RESET_ADDR', '$rst_addr')
    body = body.replace('ENABLE_COUNTERS', '$en_counter')
    return body


@hdl.block
def algol(clk_i,
          rst_i,
          wbm,
          xint_meip_i,
          xint_mtip_i,
          xint_msip_i,
          hart_id,
          config):
    """myhdl module using user-defined code.
    """
    assert isinstance(wbm, WishboneMaster), "[Algol] Error: wbm port must be of type WishboneMaster"
    assert isinstance(config, Configuration), '[Algol] Error: config data must be of type Configuration'
    assert hart_id >= 0, '[Algol] Error: HART_ID must be >= 0'

    rst_addr   = config.getOption('Core', 'start_address')  # noqa
    en_counter = config.getOption('Core', 'enable_counters')  # noqa
    wbm_addr_o = wbm.addr_o
    wbm_dat_o  = wbm.dat_o
    wbm_sel_o  = wbm.sel_o
    wbm_cyc_o  = wbm.cyc_o
    wbm_stb_o  = wbm.stb_o
    wbm_we_o   = wbm.we_o
    wbm_dat_i  = wbm.dat_i
    wbm_ack_i  = wbm.ack_i
    wbm_err_i  = wbm.err_i

    # check if the rest of the module is needed.
    @hdl.always(clk_i, rst_i, wbm_dat_i, wbm_ack_i, wbm_err_i, xint_meip_i,  xint_mtip_i, xint_msip_i)
    def logic():
        pass

    # mark ports as used/driven. Avoid warnings.
    wbm_addr_o.driven = "reg"
    wbm_dat_o.driven  = "reg"
    wbm_sel_o.driven  = "reg"
    wbm_cyc_o.driven  = "reg"
    wbm_stb_o.driven  = "reg"
    wbm_we_o.driven   = "reg"

    return hdl.instances()


algol.verilog_code = get_template('algol.v')

# Local Variables:
# flycheck-flake8-maximum-line-length: 200
# flycheck-flake8rc: ".flake8rc"
# End:
