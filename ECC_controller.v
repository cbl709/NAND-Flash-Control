/*
本文件实现与 ECC generation模块的接口配合。启动 ecc_controller (en=1),将32 bits 数据 data_in 转换成8位的data8，产生
ECC generation 模块的控制信号
*/

module ecc_controller(
                   ///input  ///
                   clk,
                   rst_n,
                   data_in, //32 bits
                   en,
                
                   
                   ///output///
                   addr,
                   ecc_gen,
                   reset_gen,
                   data8,   //8 bits
                   count,
                   ecc_load,
                   ecc_ack
                   
                  );
                  
 input            clk;   
 input            rst_n;
 output [8:0]     addr;
 input [31:0]     data_in;
 input            en;
 
 output           reset_gen;
 reg              reset_gen;
 output           ecc_gen;
 reg              ecc_gen;
 output           ecc_load;
 reg              ecc_load;
 
 output           ecc_ack;
 reg              ecc_ack;
 
 output [7:0]      data8;
 reg    [7:0]      data8;
 
 output [10:0]     count;
 reg    [10:0]     count;
 
 reg    [8:0]      addr;
 
 reg [1:0] state;  
 parameter idle      = 2'd0;
 parameter ecc_begin = 2'd1;
 
 reg [3:0]        cycle;
 
 
 always@(posedge clk or negedge rst_n)
 begin
   if(~rst_n) begin
     state   <= idle;
     ecc_gen       <= 0;
     ecc_load      <= 0;
     //reset_gen     <= 1;
     cycle         <= 0;
     addr          <= 0;
     count         <= 0;
   end
   else begin 
   
   case(state)
   idle: begin 
        ecc_gen       <= 0;
        ecc_load      <= 0;
        ecc_ack       <= 0;
        reset_gen     <= 1;
        cycle         <= 0;
        addr          <= 0;
        count         <= 0;
        if(en)
          state       <= ecc_begin;
        
        else
          state      <= idle;
		end
     
   ecc_begin:
      begin
      ecc_load  <= 1;
      case(cycle)
        4'd0: begin
                data8     <= data_in[7:0];
                count     <= {addr,2'b00}; // this signal connect to ECC generation module's count_in ports
                ecc_gen   <= 1;
                reset_gen <= 0;
                //ecc_ack   <= 0;
                cycle     <= cycle+1;
              end
        4'd1: begin
                data8     <= data_in[15:8];
                count     <= {addr,2'b01};
                cycle     <= cycle+1;
              end
        4'd2: begin
                data8     <= data_in[23:16];
                count     <= {addr,2'b10};
                cycle     <= cycle+1;
              end
        4'd3: begin
                data8     <= data_in[31:24];
                count     <= {addr,2'b11};
                cycle     <= cycle+1;
              end   
        4'd4: begin
                  if(count==511) begin
                    ecc_gen   <= 0;
                    ecc_load  <= 1;                 
                    ecc_ack   <= 1;
                    //state     <= idle;
                    cycle     <= cycle+1;
                    end
                  else begin
                    cycle     <= 0;
                    addr      <= addr+1;
                    ecc_gen   <= 0;
                    end
                 
              end  
        4'd5: state <= idle;
       endcase 
       end      
   endcase
    end  // end of else
   
 end // end of always                  
                  
endmodule
                  

                  
