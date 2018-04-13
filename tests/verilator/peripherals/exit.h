

//file: exit peripheral, used to indicate end of simulation.


#include <vector>
#include <string>
#include <cstdint>


class EXIT{

public:
	EXIT(const uint32_t code);
	void sim(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
            const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o);
	bool check();

private:

	uint32_t data; //data stored
	uint32_t exit_code;  //Code which indicates end of simulation
	bool is_end;  //indicate end of simulation if true

};