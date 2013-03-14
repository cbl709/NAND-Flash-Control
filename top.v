`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:33:52 01/07/2013 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
					clk,
					rst_n,
					cs_n,
					oe_n,
					we_n,
					rd_wr,
					ebi_data,
					ebi_addr,
					r,
					nf_cle,
					nf_ale,
					nf_ce_n,
					nf_re_n,
					nf_we_n,
					
					dio
				//	nf_wp_n
					
    );
	 
	 input clk;
	 input rst_n;
    input cs_n;
    input oe_n;
    input [3:0] we_n;
    input rd_wr;
	 inout [31:0] ebi_data;
	 inout [7:0] dio;
	 input [15:0] ebi_addr;
	 input r;
	 
	 output nf_cle;
	 output nf_ale;
	 output nf_ce_n;
	 output nf_re_n;
	 output nf_we_n;
	//output nf_wp_n;
	wire [3:0] operate;
	wire [31:0] nfaddr0;
	wire [31:0] nfaddr1;
	wire [1:0]	page_size;
	wire [8:0]	Ahb2RamAddr;
	wire [31:0] buffer;
	wire [31:0] Ram2AhbQB;
	wire [31:0] id;
    wire [31:0] valid;
    wire [31:0] nfecc0;
	wire [7:0]  status;
	wire        done;
	
	wire [31:0] Flash2RamDat;
    wire        Flash2RamWe;
    wire [8:0]  Flash2RamAddr;
          
          /// ram to flash signal////////////
    wire [31:0] Ram2FlashDat;
    
wire [10:0] count_in;
wire ecc_load;
wire [7:0]  datain;		
wire nand_ecc_gen;		
wire ecc_ack;
wire reset_ecc_gen;
wire [8:0] ecc_addr;
wire ecc_en;
wire [23:0] hamming_out0;


ppc_interface interface (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(cs_n),
        .oe_n(oe_n),
        .we_n(we_n),
        .rd_wr(rd_wr),
        .ebi_data(ebi_data),
		  .buffer(buffer),
		  .id(id),
          .valid(valid),
          .nfecc0(nfecc0),
		  .status(status),
        .ebi_addr(ebi_addr),
        .operate(operate),
        .page_size(page_size),
        .Ahb2RamWENB_d(Ahb2RamWENB),
        .Ahb2RamOENB(Ahb2RamOENB),
        .Ram2AhbQB(Ram2AhbQB),
        .start(start),
        .nfaddr0(nfaddr0),
        .nfaddr1(nfaddr1),
		  .done(done),
        .Ahb2RamAddr(Ahb2RamAddr));
        
        
controller nf_controller(
	      .clk(clk),
          .rst_n(rst_n),
          .start(start),

          .nf_addr0(nfaddr0),// nand flash address0
          .nf_addr1(nfaddr1),
          .operate(operate),
          .page_size(page_size),
          .r(r),
          .dio(dio),
          
          .done(done),
          
          .nf_cle(nf_cle),
          .nf_ale(nf_ale),
          .nf_ce_n(nf_ce_n),
          .nf_re_n(nf_re_n),
          .nf_we_n(nf_we_n),
          
            ////flash to dual-ram signal//////////
          .Flash2RamDat(Flash2RamDat),
          .Flash2RamWe(Flash2RamWe),
          .Flash2RamAddr(Flash2RamAddr),
          
          /// ram to flash signal////////////
          .Ram2FlashDat(Ram2FlashDat),
          
          .ecc_en(ecc_en),
          .ecc_ack(ecc_ack),
          
          .status(status),
          .id(id),
          .valid(valid),
          .nfecc0(nfecc0),
          
          ///hamming code///
          .hamming_out0(hamming_out0)
	       );
	
reg [8:0] addra;	
dualram Ram_U0(
				.addra(addra),
				.addrb(Ahb2RamAddr),
				.clka(clk),
				.clkb(clk),
				.dina(Flash2RamDat),
				.dinb(buffer),
				.douta(Ram2FlashDat),
				.doutb(Ram2AhbQB),
				.wea(Flash2RamWe),
				.web(Ahb2RamWENB)
				);
				
				
always@(ecc_addr or ecc_en or Flash2RamAddr)
begin
   case(ecc_en)
     1: addra= ecc_addr;
     0: addra= Flash2RamAddr;
   endcase
end

ecc_controller ecc_controller(
                   ///input  ///
                   .clk(clk),
                   .rst_n(rst_n),
                   .data_in(Ram2FlashDat), //32 bits
                   .en(ecc_en&(~ecc_ack)),
                   
                   
                   ///output///
                   .addr(ecc_addr),
                   .ecc_gen(nand_ecc_gen),
                   .reset_gen(reset_ecc_gen),
                   .data8(datain),   //8 bits
                   .count(count_in),
                   .ecc_load(ecc_load),
				   .ecc_ack(ecc_ack)
                   
                  );
                  
                  
NandEccGeneration ecc_generation(
                .clk(clk),
                .rst_n(rst_n),
                .datain(datain),
                .count_in(count_in),
                .hamming_out0(hamming_out0),
                .hamming_out1(hamming_out1),
                .hamming_out2(hamming_out2),
                .hamming_out3(hamming_out3),
                .nand_ecc_gen(nand_ecc_gen),
                .reset_ecc_gen(reset_ecc_gen),
	            .ecc_load(ecc_load)
	            
              );
		  

		  

endmodule
