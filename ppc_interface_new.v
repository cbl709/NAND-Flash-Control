`timescale 1ns / 1ps
// PowerPC addr 0x2200,0000~0x2200,0fff  used by FPGA_UART ;
//			  
//				0x2200,1000~0x2200,17fc  2kb ram room
//				0x2200,2000 read/write nand flash address register NFADDR
//				0x2200,2004 Nand Flash Control Register NFCR
`define NFADDR0       14'b00100000000000 // ebi_addr==0x2200,2000
`define NFADDR1       14'b00100000000100 // 0x2200,2010
`define NFCR          14'b00100000000001 // 0x2200,2004
`define ID            14'b00100000000010 // 0x2200,2008
`define STATUS        14'b00100000000011 // 0x2200,200c
`define VALID         14'b00100000000101 // 0x2200,2014
`define NFECC0        14'b00100000000110 // 0x2200,2018
`define PAGE_BEGIN    14'b00010000000000 // 0x2200,1000
`define PAGE_END      14'b00010111111111 // 0x2200,17fc


module ppc_interface(
					clk,
					rst_n,
					cs_n,
					oe_n,
					we_n,
					rd_wr,
					ebi_data,
					id,
                    valid,         // valid used to indentify invalid block. if valid==0xff, the block is valid 
                    nfecc0,        // store the ecc result. nfecc= new_hamming^ori_hamming
					status,
					buffer,
					ebi_addr,
					operate,
					page_size,
					Ahb2RamWENB_d,
					Ahb2RamOENB,
					Ram2AhbQB,		//32bit
					start,
					nfaddr0,
					nfaddr1,
					done,
					Ahb2RamAddr
					
					);
	 
//////IO///////////////////
    input clk;
	input rst_n;
    input cs_n;
    input oe_n;
    input [3:0] we_n;
    input rd_wr;
    input [31:0] Ram2AhbQB;		//32bit
    inout [31:0] ebi_data;
    input [31:0] id;
    input  [31:0] valid;
    input  [31:0] nfecc0;
    input [7:0] status;
	input done;
	output [31:0] nfaddr0;
	output [31:0] nfaddr1;
	input [15:0] ebi_addr; // connect to A31~
	output [3:0] operate;
	output 		 start;
	output [1:0] page_size;
	output Ahb2RamWENB_d;
	output Ahb2RamOENB;
	output [8:0] Ahb2RamAddr;
	output [31:0] buffer;
   
/////////////////////////////	  
reg [31:0] nfcr;
reg [31:0] nfaddr0;
reg [31:0] nfaddr1;

wire [3:0] operate;
wire [1:0] page_size;

wire re_o;
wire we_o;

wire [13:0] match_addr;
assign match_addr=ebi_addr[15:2]; // notice: The aoe pc-fpga board A31 and A30 do not connect to the mpc5554
								  // so A31,A30 pin are floating,DO NOT use them !

reg Ahb2RamWENB;
reg Ahb2RamWENB_d;
wire Ahb2RamOENB;

wire wdt_en;                     // ebable watch dog timer

assign {start,wdt_en,page_size,operate}= nfcr[7:0];
assign Ahb2RamAddr = match_addr[8:0]; 
	 

assign we_o =  ~rd_wr & ~cs_n&(we_n!=4'b1111); //&&(~we_n); //& wre ; //WE for registers	
assign re_o = rd_wr & ~cs_n&(we_n==4'b1111)  ; //RE for registers



wire flash_cr_wr; // nand flash control register write enable
wire flash_addr0_wr; // nand flash addr register
wire flash_addr1_wr; // nand flash addr register

wire flash_cr_re;
wire flash_addr0_re;
wire flash_addr1_re;

wire id_read;
wire status_read;
wire valid_read;
wire nfecc0_read;


assign flash_cr_wr	 = we_o&&(match_addr == `NFCR); //NFCR: the address of Nand Flash Control Status Register
assign flash_addr0_wr = we_o&&(match_addr == `NFADDR0); 
assign flash_addr1_wr = we_o&&(match_addr == `NFADDR1); 
assign flash_cr_re	 = re_o&&(match_addr == `NFCR); //NFCR: the address of Nand Flash Control Status Register
assign flash_addr0_re = re_o&&(match_addr == `NFADDR0); 
assign flash_addr1_re = re_o&&(match_addr == `NFADDR1); 
assign valid_read = re_o&&(match_addr == `VALID); 
assign nfecc0_read = re_o&&(match_addr == `NFECC0); 


assign id_read       = re_o&&(match_addr == `ID);
assign status_read   = re_o&&(match_addr == `STATUS);


assign Ahb2RamOENB=re_o&&(match_addr>=`PAGE_BEGIN)&&(match_addr<=`PAGE_END);
//assign Ahb2RamWENB=we_o&&(match_addr>=`PAGE_BEGIN)&&(match_addr<=`PAGE_END);

reg  [31:0] read_data;
wire [31:0] write_data;
assign ebi_data= re_o ? read_data: 32'hzzzzzzzz;
assign write_data = ebi_data;
reg [31:0] wdt;    // WatchDog timer     

reg [31:0] buffer; // buffer between CPU and FPGA inner dual-ram, to synsynchronized

always@( posedge clk or negedge rst_n)
begin
	if(~rst_n) begin
		nfcr =0;
		nfaddr0 =0;
		nfaddr1 =0;
		nfcr    =0;
		buffer  =0;
        Ahb2RamWENB <=0;
       
    
	end
	else begin
    
   Ahb2RamWENB<=we_o&&(match_addr>=`PAGE_BEGIN)&&(match_addr<=`PAGE_END);
   Ahb2RamWENB_d <= Ahb2RamWENB; //延时1clk是为了在buffer稳定时在将数据写入dual-ram

    
   if(Ahb2RamWENB)
    buffer= write_data[31:0];
    
  if(we_o)
   begin
   case(match_addr)
   `NFCR:      nfcr=write_data[31:0];
   `NFADDR0:   nfaddr0=write_data[31:0];
   `NFADDR1:   nfaddr1=write_data[31:0];
    endcase
   end
   
    if(done||(wdt_en&&(wdt==1000000))) // a command has been finished or watchdog time up
      nfcr[7] = 0; // disable start signal		
	end
end



always@ *
begin
  if(re_o)
   begin
   case(match_addr)
   `NFCR:     read_data = nfcr;
   `NFADDR0:  read_data = nfaddr0;
   `ID:       read_data = id;
   `STATUS:   read_data = status;
   `NFADDR1:  read_data = nfaddr1;
   `VALID:    read_data = valid;
   `NFECC0:   read_data = nfecc0;
    default:  read_data= 32'hffff0000;
             
   endcase
   end
   
   if(Ahb2RamOENB)
    read_data= Ram2AhbQB; 
  
   
end


always@(posedge clk or negedge rst_n)
begin
  if(~rst_n)
     wdt <=0;
  else
     begin
       if(nfcr[7])
        wdt <= wdt+1;
       else
        wdt <= 0;
     end
end

endmodule
