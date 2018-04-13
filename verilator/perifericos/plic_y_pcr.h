

//file: exit peripheral, used to indicate end of simulation.


#include <vector>
#include <string>
#include <cstdint>


class PLIC_PCR{

public:
	PLIC_PCR(const uint32_t interrupt);
	void sim( uint32_t &wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
            const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o, 
                          uint32_t &xinterrupts_i, uint8_t &eip, uint8_t &sip, uint8_t &tip);

private:

	

};