module hamming_xor( clk,
                   hamming_en,
                   hamming_result,
                   nfecc
                  );
input clk;     
input hamming_en;      
       
input [23:0] hamming_result;

output [23:0]nfecc;
reg    [11:0]nfecc_r;
reg     [1:0] state;
assign  nfecc[23:0]={10'b0,state,nfecc_r};

wire [23:0] tmp;
assign tmp=hamming_result;

wire [7:0]  cnt;
assign cnt = (((tmp[0]+tmp[1]+tmp[2])+(tmp[3]+tmp[4]+tmp[5]))+((tmp[6]+tmp[7]+tmp[8])+(tmp[9]+
           tmp[10]+tmp[11])))+(((tmp[12]+tmp[13]+tmp[14])+(tmp[15]+tmp[16]+tmp[17]))+((tmp[18]+tmp[19]+tmp[20])+
           (tmp[21]+tmp[22]+tmp[23])));


			  
always@(posedge clk)
begin
    
  if(hamming_en) begin
    case(cnt)
      0:  begin
           state   <= 2'b00;
           nfecc_r <= 12'h0000;
          end
      12: begin
          state      <= 2'b01;
          nfecc_r[0] <= tmp[1]; 
          nfecc_r[1] <= tmp[3];
          nfecc_r[2] <= tmp[5];
          nfecc_r[3] <= tmp[7];
          nfecc_r[4] <= tmp[9];
          nfecc_r[5] <= tmp[11];
          nfecc_r[6] <= tmp[13];
          nfecc_r[7] <= tmp[15];
          nfecc_r[8] <= tmp[17];
          nfecc_r[9] <= tmp[19];
          nfecc_r[10] <= tmp[21];
          nfecc_r[11] <= tmp[23];
          end
          
     default: begin
            state <= 2'b10; 
            nfecc_r <=12'h000;
             end
    endcase
   end
  
end


                  
                  
endmodule
