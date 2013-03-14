module hamming_xor( clk,
                   hamming_en,
                   hamming_result,
                   nfecc
                  );
input clk;     
input hamming_en;      
       
input [23:0] hamming_result;

output [23:0]nfecc;
reg    [23:0]nfecc;

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
      0: nfecc <= 24'ha0;
      12: begin
          nfecc[0] <= tmp[1]; 
          nfecc[1] <= tmp[3];
          nfecc[2] <= tmp[5];
          nfecc[3] <= tmp[7];
          nfecc[4] <= tmp[9];
          nfecc[5] <= tmp[11];
          nfecc[6] <= tmp[13];
          nfecc[7] <= tmp[15];
          nfecc[8] <= tmp[17];
          nfecc[9] <= tmp[19];
          nfecc[11] <= tmp[21];
          nfecc[12] <= tmp[23];
          end
          
     default: nfecc <=24'hababab;
    endcase
    
    end
  
end


                  
                  
endmodule
