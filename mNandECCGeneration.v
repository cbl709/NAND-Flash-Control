`timescale 1ns/1ns
module NandEccGeneration (
              clk,
              rst_n,
              datain,
              count_in,
              hamming_out0,
              hamming_out1,
              hamming_out2,
              hamming_out3,
              nand_ecc_gen,
              reset_ecc_gen,
	          ecc_load
              );
 input            clk;   
 input            rst_n;
 input            nand_ecc_gen;
 input            reset_ecc_gen;
 input            ecc_load;
 input [7:0]      datain;
 input [10:0]     count_in;

 output[23:0]     hamming_out0;
 output[23:0]     hamming_out1;
 output[23:0]     hamming_out2;
 output[23:0]     hamming_out3;
 reg   [23:0]     hamming_out0;
 reg   [23:0]     hamming_out1;
 reg   [23:0]     hamming_out2;
 reg   [23:0]     hamming_out3;

 reg    [23:0]     hammingcode_tmp;
 wire              rowparity_tmp;

 
assign  rowparity_tmp=datain[0]^datain[1]^datain[2]^datain[3]^datain[4]^datain[5]^datain[6]^datain[7];



always @(negedge rst_n or posedge clk )
 begin 
    if (~rst_n ==1'b1)
         begin 
            hamming_out0     <= 24'b000000; 
            hamming_out1     <= 24'b000000; 
            hamming_out2     <= 24'b000000; 
            hamming_out3     <= 24'b000000; 
         end
    else if(ecc_load)
         begin
           if(count_in==511)  hamming_out0     <= hammingcode_tmp; 
            if(count_in==1023) hamming_out1     <= hammingcode_tmp; 
            if(count_in==1535) hamming_out2     <= hammingcode_tmp; 
            if(count_in==2047) hamming_out3     <= hammingcode_tmp;        
         end
  end

	 
always @(negedge rst_n or posedge clk )
 begin : ParityGEN
   if (!rst_n ==1'b1)
      begin 
        hammingcode_tmp  <= 24'h000000;
      end
   else if(count_in==0)
      begin
        hammingcode_tmp  <= 24'h000000;
      end
   else begin
     if (nand_ecc_gen == 1'b1)
       begin
         hammingcode_tmp[0]<= hammingcode_tmp[0]^datain[0]^ datain[2]^ datain[4]^ datain[6]; //p1'
         hammingcode_tmp[1]<= hammingcode_tmp[1]^datain[1]^ datain[3]^ datain[5]^ datain[7]; //p1
         hammingcode_tmp[2]<= hammingcode_tmp[2]^datain[0]^ datain[1]^ datain[4]^ datain[5]; //p2'
         hammingcode_tmp[3]<= hammingcode_tmp[3]^datain[2]^ datain[3]^ datain[6]^ datain[7]; //p2
         hammingcode_tmp[4]<= hammingcode_tmp[4]^datain[0]^ datain[1]^ datain[2]^ datain[3]; //p4'
         hammingcode_tmp[5]<= hammingcode_tmp[5]^datain[4]^ datain[5]^ datain[6]^ datain[7]; //p4
         hammingcode_tmp[6]<= hammingcode_tmp[6]^(rowparity_tmp & ~(count_in[0])) ;          //p8'
         hammingcode_tmp[7]<= hammingcode_tmp[7]^(rowparity_tmp & count_in[0]) ;             //p8
         hammingcode_tmp[8]<= hammingcode_tmp[8]^(rowparity_tmp & ~(count_in[1])) ;          //p16'
         hammingcode_tmp[9]<= hammingcode_tmp[9]^(rowparity_tmp & count_in[1]) ;             //p16
         hammingcode_tmp[10]<= hammingcode_tmp[10]^(rowparity_tmp & ~(count_in[2])) ;        //p32'
         hammingcode_tmp[11]<= hammingcode_tmp[11]^(rowparity_tmp & count_in[2]) ;           //p32
         hammingcode_tmp[12]<= hammingcode_tmp[12]^(rowparity_tmp & ~(count_in[3])) ;        //p64'
         hammingcode_tmp[13]<= hammingcode_tmp[13]^(rowparity_tmp & count_in[3]) ;           //p64
         hammingcode_tmp[14]<= hammingcode_tmp[14]^(rowparity_tmp & ~(count_in[4])) ;       //p128'
         hammingcode_tmp[15]<= hammingcode_tmp[15]^(rowparity_tmp & count_in[4]) ;          //p128
         hammingcode_tmp[16]<= hammingcode_tmp[16]^(rowparity_tmp & ~(count_in[5])) ;       //p256'
         hammingcode_tmp[17]<= hammingcode_tmp[17]^(rowparity_tmp & count_in[5]) ;          //p256
         hammingcode_tmp[18]<= hammingcode_tmp[18]^(rowparity_tmp & ~(count_in[6])) ;       //p512'
         hammingcode_tmp[19]<= hammingcode_tmp[19]^(rowparity_tmp & count_in[6]) ;          //p512
         hammingcode_tmp[20]<= hammingcode_tmp[20]^(rowparity_tmp & ~(count_in[7])) ;      //p1024'
         hammingcode_tmp[21]<= hammingcode_tmp[21]^(rowparity_tmp & count_in[7]) ;         //p1024
         hammingcode_tmp[22]<= hammingcode_tmp[22]^(rowparity_tmp & ~(count_in[8])) ;      //p2048'
         hammingcode_tmp[23]<= hammingcode_tmp[23]^(rowparity_tmp & count_in[8]) ;         //p2048
       end
    else 
       begin
         hammingcode_tmp[23:0] <= hammingcode_tmp[23:0];
       end
   end
 end
endmodule
