

#include <memory>
#include <cstring>
#include "aelf.h"
#include "wbmemory.h"

// -----------------------------------------------------------------------------
// Constructor.
EXIT::EXIT(const uint32_t code){
	exit_code=code;  //set exit code.
	is_end=false;
}


//sim: simulate peripheral´s behavior
void EXIT::sim(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                          const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o){


	wbs_data_o = 0xdeadf00d;
    wbs_ack_o  = 0;
    wbs_err_o  = 0;
	
	if (wbs_cyc_i and wbs_stb_i) {		     
        
        //Support read and write operation      
        if (wbs_we_i) {
                 //It is not necessary to write data.

                //Check if exit code is asserted
				if(wbs_dat_i==exit_code)
					is_end=true;
				else
					is_end=false; 
        }
        
        wbs_ack_o   = 1;
        wbs_err_o   = 0;      
               
    }        
}


//check: allows to get the value of is_end
bool EXIT::check(){
	return is_end;
}
