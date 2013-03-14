///////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////
module  read_byte(
                  clk,
                  rst_n,
                  dly_done,
				  read_data,     //connect to flash IO ports
				  read_data_out,
				  dly,
				  ack,
				  read_en,
				  nf_re_n,
				  dly_load			  
                );
       
       input         clk;
       input         rst_n;
       input         dly_done;
       input         read_en;
	   input  [7:0]  read_data;
                
       output [7:0]  read_data_out;
       output [31:0] dly;
       output        nf_re_n;
       output        dly_load;
       output        ack;
       
       reg    [7:0]  read_data_out;
       reg    [3:0]  dly_counter;
       reg           nf_re_n;
       reg           dly_load;
       reg           ack;
		 reg    [4:0]  cycle;
       
       assign dly[31:0] = {28'b0, dly_counter[3:0]};
       
       reg    [1:0]  state;
       
       parameter idle = 2'd0;
       parameter read = 2'd1;
       
///////////MAX CLK=100MHZ//////////////////////////////////          
parameter TWP   = 4'd3,  //WE low pulse width min=25ns
		  TWC   = 4'd6,  //write cycle width min=50ns;
		  TRP   = 4'd4,  //RE pulse width min=30ns;
		  TRC   = 4'd6,  //read cycle time min=50ns;
		  TREA  = 4'd3,  // re_n access time max=30ns;
		  TWB   = 4'd10; //WE high to busy max=100ns;
//////////////////////////////////////////////////////////////



always@(posedge clk or negedge rst_n)
    begin
       if(~rst_n) begin
                cycle       <= 0;
                nf_re_n     <= 1;
                dly_load    <= 0;
                dly_counter <= 0;
                state       <= idle;
       end
       
       else begin
       case(state)
         idle: begin 
                cycle       <= 0;
                nf_re_n     <= 1;
                dly_load    <= 0;
                dly_counter <= 0;
                ack         <= 0;
                if(read_en)
                 state <= read;
                else
                 state <= idle;
               end
   /////////generate read time sequence////////////////////////
         read:    
               case(cycle)
                  5'd0: begin
                        nf_re_n       <= 1'b0;
	                    dly_load      <= 1;            //load wait time:TREA
	                    dly_counter   <= TREA;
	                    cycle         <= cycle+1;
                        end
             
                  5'd1: begin
                        dly_load      <= 0;            // disable load wait time,start time counter
	                   if(dly_done)                    //reach the dly time
	                   begin
	                     read_data_out   <= read_data; //we should wait TREA clks after nf_re_n==0, or we may read a wrong data 
	                     cycle           <= cycle+1;
	                     dly_load        <= 1;
	                     dly_counter     <= TRP-TREA;
	                   end
	                  end
	         
	             5'd2: begin
	                  dly_load       <= 0;
	                  if(dly_done)
	                    begin
	                    nf_re_n     <= 1;
	                    cycle       <= cycle+1;
	                    dly_load    <= 1;
	                    dly_counter <= TRC-TRP;
	                    end
	                 end  
	         
	            5'd3: begin
	                 dly_load       <= 0;
	                 if(dly_done)
	                   begin
	                    ack         <= 1;
	                    state       <= idle;
	                   end
	                 end    
	           
                 endcase
       endcase       
       end
     end
     
     
	
endmodule
