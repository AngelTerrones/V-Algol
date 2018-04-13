

#include <memory>
#include <cstring>
#include "aelf.h"
#include "wbmemory.h"

// -----------------------------------------------------------------------------
PLIC_PCR::PLIC_PCR(const uint32_t interrupt){
	
}
//periferico
void PLIC_PCR::sim(uint32_t &wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                          const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_dat_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o,
                          uint32_t &xinterrupts_i, uint8_t &eip, uint8_t &sip, uint8_t &tip){

            wbs_ack_o  = 0;
            wbs_err_o  = 0;


            wbs_dat_o = xinterrupts_i;
            wbs_addr_i = 0xF0000004;
            if(eip == 1){
                printf("La interrupcion %d fue atendida correctamente\n",xinterrupts_i);
                wbs_ack_o  = 1;
            }
            
}

