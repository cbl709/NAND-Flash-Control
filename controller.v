module controller(
          clk,
          rst_n,
          start,

          nf_addr0,// nand flash address0
          nf_addr1,
          operate,
          page_size,
          r,
          dio,
          
          done,
          
          /////nand flash control signal////////
          nf_cle,
          nf_ale,
          nf_ce_n,
          nf_re_n,
          nf_we_n,
          
          ////flash to dual-ram signal//////////
          Flash2RamDat,
          Flash2RamWe, // flash to ram write enable
          Flash2RamAddr,
          
          /// ram to flash signal////////////
          Ram2FlashDat,
                         
          ecc_en,
          ecc_ack,
          
          status,
          id,
          valid,
          nfecc0,
          
          ////////hamming code //////////
          hamming_out0
          
           );

input           clk;
input           rst_n;
input           start;
input [31:0]    nf_addr0;
input [31:0]    nf_addr1;
input [3:0]     operate;
input [1:0]     page_size;
input           r;
inout [7:0]     dio;
input           ecc_ack;
input [23:0]    hamming_out0;

output          ecc_en;
reg             ecc_en;
output          done;

output          nf_cle;
output          nf_ale;
output          nf_ce_n;
output          nf_re_n;
output          nf_we_n;

output [31:0]   Flash2RamDat;
output          Flash2RamWe;
output [8:0]    Flash2RamAddr;


reg [17:0]      cycle;
reg [11:0]      byte_num;

input  [31:0]   Ram2FlashDat;

reg nf_cle;
reg nf_ale;
reg nf_ce_n;
reg nf_we_n;
wire nf_re_n;
reg done;


output  [7:0]    status;
reg     [7:0]    status;
output  [31:0]   id;

output [31:0]    valid;
reg    [31:0]    valid;

output [31:0]    nfecc0;
//reg    [31:0]    nfecc0;

reg    [31:0]    id;
reg    [4:0]     counter;       
reg              counter_rst;
reg              counter_en;

reg   [7:0]      write_data;
wire  [7:0]      read_data;

reg              io_read;        // 1: read from flash ;0: write to flash 
assign           read_data= dio;
assign           dio=io_read? 8'hzz:write_data;

reg [15:0]       state;

reg [31:0]       Flash2RamDat;
reg              Flash2RamWe;
reg [8:0]        Flash2RamAddr ;


///////////////////
wire             ack;
reg              read_en;
wire [7:0]       read_data_out;
wire             dly_done;
wire [31:0]      dly;
wire             dly_load;

reg [23:0]       ori_hamming;
reg [23:0]       new_hamming;
reg [23:0]       hamming_result;

reg [7:0]        cnt;

////////////state parameter///////////////////////////////

parameter idle               =  16'b0000000000000001,
          flash_rst      	 =  16'b0000000000000010,
          page_read          =  16'b0000000000000100,
          block_erase        =  16'b0000000000001000,
          page_program       =  16'b0000000000010000,
          read_id            =  16'b0000000000100000,
          read_status        =  16'b0000000001000000,  
          copy_back          =  16'b0000000010000000,
          write_ecc          =  16'b0000000100000000,
          read_ecc           =  16'b0000001000000000,
          invalid_block      =  16'b0000010000000000,
          read_block_state   =  16'b0000100000000000;
          
          
////////// cycle parameter////////////////////////////
parameter cycle_1               =  18'b000000000000000001,
          cycle_2      	        =  18'b000000000000000010,
          cycle_3               =  18'b000000000000000100,
          cycle_4               =  18'b000000000000001000,
          cycle_5               =  18'b000000000000010000,
          cycle_6               =  18'b000000000000100000,
          cycle_7               =  18'b000000000001000000,  
          cycle_8               =  18'b000000000010000000,
          cycle_9               =  18'b000000000100000000,
          cycle_10              =  18'b000000001000000000,
          cycle_11              =  18'b000000010000000000,
          cycle_12              =  18'b000000100000000000,
          cycle_13              =  18'b000001000000000000,
          cycle_14              =  18'b000010000000000000,
          cycle_15              =  18'b000100000000000000,
          cycle_16              =  18'b001000000000000000,
          cycle_17              =  18'b010000000000000000,
          cycle_18              =  18'b100000000000000000;
          
task cycle_inc;
begin
  cycle <= (cycle<<1);
end
endtask
             
///////////MAX CLK=100MHZ//////////////////////////////////          
parameter TWP   = 4'd3,  //WE low pulse width min=25ns
          TWC   = 4'd6,  //write cycle width min=50ns;
          TRP   = 4'd4,  //RE pulse width min=30ns;
          TRC   = 4'd6,  //read cycle time min=50ns;
          TREA  = 4'd3,  // re_n access time max=30ns;
          TWB   = 4'd10; //WE high to busy max=100ns;
          
///////////page size define//////////////////////////
 reg[11:0]     PageSize;
 reg[7:0]      spare_area; // PageSize+spare size

 always @*
     begin
        case(page_size)
        2'b00: PageSize = 12'd256;
        2'b01: PageSize = 12'd512;
        2'b10: PageSize = 12'd1024;
        2'b11: PageSize = 12'd2048;
       endcase
     end
 //////////////////////////////////////////////////
 
 reg hamming_en;
 hamming_xor hamming_xor(
                        .clk(clk),
                        .hamming_en(hamming_en),
                        .hamming_result(hamming_result),
                        .nfecc(nfecc0)
 
                        );
 
 
always@(posedge clk or negedge rst_n)
begin
    if(~rst_n) begin
        state<= idle;
        id          <= 0;
        status      <=0;
        cycle       <= 0;
        nf_ce_n     <=0;       // flash always enable, important!
        nf_cle      <=0;
        nf_ale      <=0;
        nf_we_n     <=0;    
        cnt         <=0;
        done        <=0;
        byte_num    <=0;      // read or write byte number during the read/write page operation
        counter_en  <=0;      // enable the counter 
        counter_rst <=1;      // reset the counter to 0
        Flash2RamWe =0;       // disable the flash write dual-ram
        Flash2RamAddr <= 0;
        hamming_en     <=0;
        
        new_hamming     <=0;
        ori_hamming     <=0;
        hamming_result  <=0;
        
        valid           <=0;
    end
    else begin
    
    case(state)
    idle: begin
            nf_ce_n <=0; // flash always enable
            nf_cle  <=0;
            nf_ale  <=0;
            nf_we_n <=0;
            cycle   <=cycle_1;
            done    <=0;
            cnt     <=0;
            
        
            byte_num     <=0;      // read or write byte number during the read/write page operation
            counter_en   <=0;     // enable the counter 
            counter_rst  <=1;   // reset the counter to 0
            Flash2RamWe  =0;    // disable the flash write dual-ram
            Flash2RamAddr <= 0;
            
            hamming_en <=0;
          
            if(start) begin
                case(operate)
                4'b0000: state <= idle;
                4'b0001: state <= page_read;
                4'b0010: state <= page_program;
                4'b0011: state <= block_erase;
                4'b0100: state <= write_ecc;
                4'b0101: state <= read_ecc;
                4'b0110: state <= flash_rst;
                4'b0111: state <= read_id;
                4'b1000: state <= copy_back;
                4'b1001: state <= read_status;
                4'b1010: state <= invalid_block; 
                4'b1011: state <= read_block_state;  
               
                default: state <= idle;
                endcase
            end
            
          end
          
/*/////////////page read operation/////////////////////////*/
  
    page_read: begin            
                case(cycle)
                cycle_1: sendCmd(8'h00); 
                cycle_2: sendAddr(nf_addr0[7:0],0);
                cycle_3: sendAddr(nf_addr0[16:9],0);       //Be careful: address is [16:9], not [15:8]
                cycle_4: sendAddr(nf_addr0[24:17],0);
                cycle_5: sendAddr({7'b0,nf_addr0[25]},1);
                cycle_6: begin
                       cnt <= cnt+1;
                       if(cnt==7'd5)
                        cycle_inc;
                        //delay(TWB); from WE high to busy  max=100ns
                      end
                cycle_7: if(r) cycle_inc;//cycle<= cycle+1;            // wait until not busy
                
                //////cycle 7 to cycle 10: read 4 bytes flash data, and write to dual-ram /////////
                cycle_8: begin
                        read_byte_task(Flash2RamDat[7:0],1);                                                                     
                      end
                cycle_9:begin
                        read_byte_task(Flash2RamDat[15:8],1);                                                 
                    end
                    
                cycle_10:begin                        
                        read_byte_task(Flash2RamDat[23:16],1);                               
                    end
                cycle_11:begin
                        read_byte_task(Flash2RamDat[31:24],1);                  
                    end
/////////////////////////////////////////////////////////////////////////////////////////////           
                    
              cycle_12:begin
                        Flash2RamWe=1;      //after read 4 bytes from flash, write Flash2RamDat to dual-ram, enable Flash2RamWe
                        //cycle<= cycle+1;
                        cycle_inc;
                        end
              cycle_13:begin
                        Flash2RamWe=0;     // disable the Flash2RamWe, ensure the Flash2RamWe enable not more than 1 clk
                        Flash2RamAddr <= Flash2RamAddr+1;
                        cycle_inc;
                        end 
              cycle_14: begin
                        if(byte_num==PageSize)
                            cycle_inc;
                        else
                            cycle<= cycle_8;
                      end   
                      
             cycle_15: begin
                      opdone;
                      
                     end//opdone;   
              default: state <= idle;   
                    
            endcase 
        end
                
    page_program: begin
          
                 case(cycle)
                  cycle_1: begin                               
                        ecc_en <= 1;
                        if(ecc_ack) begin
                         cycle_inc;
                         ecc_en <=0;                    
                         end
                       end  
                  cycle_2:begin                         
                         sendCmd(8'h00);
                       end
                  cycle_3:sendCmd(8'h80);
                  cycle_4: sendAddr(nf_addr0[7:0],0);
                  cycle_5: sendAddr(nf_addr0[16:9],0);
                  cycle_6: sendAddr(nf_addr0[24:17],0);
                  cycle_7: sendAddr({7'b0,nf_addr0[25]},1);
                  cycle_8: sendByte(Ram2FlashDat[7:0],1);
                  cycle_9: sendByte(Ram2FlashDat[15:8],1);
                  cycle_10: sendByte(Ram2FlashDat[23:16],1);
                  cycle_11: sendByte(Ram2FlashDat[31:24],1); // write 4 bytes 
                  cycle_12: begin
                        Flash2RamAddr <= Flash2RamAddr+1;
                        if(byte_num==PageSize)
                          cycle_inc;
                        else cycle <=cycle_8;   
                        end
                  cycle_13: sendCmd(8'h10);
                  cycle_14: begin
                       cnt <= cnt+1;
                       if(cnt==8'd5)
                        cycle_inc;
                        //delay(TWB); from WE high to busy  max=100ns
                      end
                  cycle_15: if(r) cycle_inc; // wait until not busy 
                  cycle_16: sendCmd(8'h70);
                  cycle_17: read_byte_task(status[7:0],1); 
                  
                  cycle_18: begin
                          opdone;
                          end//opdone;
                  default: state<= idle;
                 endcase    
                    end
                    
    write_ecc: begin
                  case(cycle)
                  cycle_1:sendCmd(8'h50);
                  cycle_2:sendCmd(8'h80);
                  cycle_3: sendAddr(nf_addr0[7:0],0);
                  cycle_4: sendAddr(nf_addr0[16:9],0);
                  cycle_5: sendAddr(nf_addr0[24:17],0);
                  cycle_6: sendAddr({7'b0,nf_addr0[25]},1);
                  cycle_7: sendByte(hamming_out0[7:0],1);
                  cycle_8: sendByte(hamming_out0[15:8],1);
                  cycle_9: sendByte(hamming_out0[23:16],1);          
                  cycle_10: sendCmd(8'h10);
                  cycle_11: begin
                       cnt <= cnt+1;
                       if(cnt==8'd5)
                        cycle_inc;
                    //delay(TWB); from WE high to busy  max=100ns
                      end
                  cycle_12: if(r) cycle_inc;//cycle  <= cycle+1; // wait until not busy 
                  cycle_13: sendCmd(8'h70);
                  cycle_14: read_byte_task(status[7:0],1);             
                  cycle_15: opdone;
                  default: state<= idle;
                  endcase
               end
               
    invalid_block: 
               begin
                  case(cycle)
                  cycle_1:sendCmd(8'h50);
                  cycle_2:sendCmd(8'h80);
                  cycle_3: sendAddr(nf_addr0[7:0],0);
                  cycle_4: sendAddr(nf_addr0[16:9],0);
                  cycle_5: sendAddr(nf_addr0[24:17],0);
                  cycle_6: sendAddr({7'b0,nf_addr0[25]},1);
                  cycle_7: sendByte(8'hab,1);                        
                  cycle_8: sendCmd(8'h10);
                  cycle_9: begin
                       cnt <= cnt+1;
                       if(cnt==8'd5)
                        cycle_inc;
                       //delay(TWB); from WE high to busy  max=100ns
                      end
                  cycle_10: if(r) cycle_inc;//cycle  <= cycle+1; // wait until not busy          
                  cycle_11: opdone;
                  default: state<= idle;
                  endcase  
             end
                         
               
    read_ecc: begin
                case(cycle)
                cycle_1: begin                                                                                
                      ecc_en <= 1;
                      if(ecc_ack) begin
                         cycle_inc;
                         ecc_en          <= 0;
                         new_hamming     <= hamming_out0;
                      end                                                                             
                     end        
                cycle_2: sendCmd(8'h50); 
                cycle_3: sendAddr(nf_addr0[7:0],0);
                cycle_4: sendAddr(nf_addr0[16:9],0);       //Be careful: address is [16:9], not [15:8]
                cycle_5: sendAddr(nf_addr0[24:17],0);
                cycle_6: sendAddr({7'b0,nf_addr0[25]},1);
                cycle_7: begin
                       cnt <= cnt+1;
                       if(cnt==8'd10)
                        cycle_inc;
                    //delay(TWB); from WE high to busy  max=100ns
                      end
                cycle_8: if(r) cycle_inc;//cycle<= cycle+1;            // wait until not busy
                cycle_9: read_byte_task(ori_hamming[7:0],1);
                cycle_10: read_byte_task(ori_hamming[15:8],1);
                cycle_11: read_byte_task(ori_hamming[23:16],1);    
                                                             
                cycle_12: begin
                          hamming_result <= new_hamming^ori_hamming;
                          hamming_en <= 1;
                          cycle_inc;
                          end
                cycle_13: begin
                           cycle_inc;
                           end
                cycle_14: opdone;
                default: state <= idle;
                  endcase
                  end
                
    read_block_state: 
                  begin
                  case(cycle)
                  cycle_1:sendCmd(8'h50);                 
                  cycle_2: sendAddr(nf_addr0[7:0],0);
                  cycle_3: sendAddr(nf_addr0[16:9],0);
                  cycle_4: sendAddr(nf_addr0[24:17],0);
                  cycle_5: sendAddr({7'b0,nf_addr0[25]},1);
                  cycle_6: begin
                       cnt <= cnt+1;
                       if(cnt==8'd5)
                        cycle_inc;
                       //delay(TWB); from WE high to busy  max=100ns
                      end
                  cycle_7: if(r) cycle_inc;//cycle<= cycle+1;            // wait until not busy
                  cycle_8: read_byte_task(valid[7:0],1);       
                  cycle_9: opdone;
                  default: state<= idle;
                  endcase  
             end
              
                    
    read_id: begin
                case(cycle)
                cycle_1: sendCmd(8'h90);
                cycle_2: sendAddr(8'h00,1);
                cycle_3: read_byte_task(id[31:24],1);
                cycle_4: read_byte_task(id[23:16],1);
                cycle_5: read_byte_task(id[15:8],1);
                cycle_6: read_byte_task(id[7:0],1);
                cycle_7: opdone;
                default: state <= idle;                     
                endcase         
             end
             
    block_erase: begin
                    case(cycle)
                    cycle_1: sendCmd(8'h60);
                    cycle_2: sendAddr(nf_addr0[16:9],0);
                    cycle_3: sendAddr(nf_addr0[24:17],0);
                    cycle_4: sendAddr({7'b0,nf_addr0[25]},1);
                    cycle_5: sendCmd(8'hd0);
                    cycle_6: begin
                       cnt <= cnt+1;
                       if(cnt==8'd5)
                        cycle_inc;
                     //delay TWB. from WE high to busy time max=100ns
                      end
                    cycle_7: if(r) cycle_inc;//cycle<= cycle+1;    // wait until not busy
                    cycle_8: sendCmd(8'h70);
                    cycle_9: read_byte_task(status[7:0],1);
                    cycle_10: opdone;
                    default: state<= idle;
                    endcase
                end
                
    flash_rst: begin
                case(cycle)
                cycle_1:sendCmd(8'hff);
                cycle_2: begin
                       cnt <= cnt+1;
                       if(cnt==8'd5)
                       cycle_inc;
                     //delay TWB. from WE high to busy time max=100ns
                      end
                cycle_3: if(r) cycle_inc;    // wait until not busy
                cycle_4:opdone;
                default:state <= idle;
                endcase
               end
               
    read_status: begin
                    case(cycle)
                    cycle_1: sendCmd(8'h70);
                    cycle_2: cycle_inc;//cycle <= cycle+1;
                    cycle_3: read_byte_task(status[7:0],1);
                    cycle_4: begin
                          opdone;
                          end
                    default: state <=idle;
                    endcase
                  end
    default: state <= idle;
    endcase 
 end
end

////////////////////////////////////////////////////
          //////***  Counter  ***/////
////////////////////////////////////////////////////

always@(posedge clk or negedge rst_n)
  begin
    if(~rst_n)
      begin
            counter =0;
      end
    else
        begin
          if(counter_rst)//1 reset
                counter=0;
          else if(counter_en)
                counter = counter + 1'b1;
      end
  end


///////////////////////////////////////////////////////
//  delay(T)   generate T clks delay                //
//  and jump to the next operate Cycle              //
//////////////////////////////////////////////////////
task  delay;
      input[7:0]  Tdelay;
      begin
      counter_rst <= 0;
      counter_en  <= 1;
     
          if(counter==Tdelay)
           begin
               counter_rst   <= 1'b1;
               counter_en    <= 1'b0;
                cycle        <= cycle+1;
           end
      end
endtask  


///////////////////////////////////////////////////////////////////////////////////////////
//   sendAddr(addr0,0)   send the address "addr0"  , oAle doesnot need to be pull down  //
//   sendAddr(addr1,1)   send the last address "addr1"  oAle needs to be pull down      //
/////////////////////////////////////////////////////////////////////////////////////////
task  sendAddr;
    input[7:0] address;
    input      last_addr;
     begin
     io_read     <= 0; // write to flash
      nf_we_n    <= 0;
      nf_ale     <= 1;
      write_data <= address;    
      counter_rst<= 0;
      counter_en <= 1;  
     
        if( (counter>=TWP) && (counter<TWC))
         begin
           nf_we_n <= 1'b1; 
         end
       else if ( counter==TWC )
           begin
             nf_we_n  <= 1'b1;
             if(last_addr) 
             nf_ale <= 1'b0;
             counter_rst <= 1'b1;
             counter_en  <= 1'b0;
             //cycle       <= cycle+1;
             cycle_inc;
           end
     end
endtask

///////////////////////////////////////////////////////////////////////////////////////////
//   sendCmd(cmd0)   send the command "cmd0" ,and jump to the next operate Cycle        //
/////////////////////////////////////////////////////////////////////////////////////////
task  sendCmd;
       input[7:0]  command;
       begin
           write_data      <= command;
           io_read         <= 1'b0;
           nf_cle          <= 1'b1;
           nf_we_n         <= 1'b0;
           counter_rst     <= 0;
           counter_en      <= 1;

       if( (counter>=TWP) && (counter<TWC))
       begin
              nf_we_n      <= 1'b1; 
         end
     else if ( counter==TWC )
       begin
             nf_cle        <= 1'b0;
             nf_we_n       <= 1'b1;
             counter_rst   <= 1'b1;
             counter_en    <= 1'b0;
             //cycle         <= cycle+1;
             cycle_inc;
            end
   end
endtask


///////////////////////////////////////////////////////////////////////////////////////////
//   sendByte(data0,1)   send the last data "data0" ,and jump to the next operate Cycle  //
//////////////////////////////////////////////////////////////////////////////////////////
task  sendByte;
       input[7:0]  data;
       input       last_data;
       begin
       counter_rst   <= 0;
       counter_en    <= 1;
       io_read       <= 1'b0;// write
       nf_we_n       <= 1'b0;
       
       write_data    <= data;
       
         if( (counter>=TRP) && (counter<TRC) )
            begin
           nf_we_n <= 1'b1; 
            end
       else if ( counter==TRC )
            begin
             nf_we_n     <= 1'b1;
             counter_rst <= 1'b1;
             counter_en  <= 1'b0;
             byte_num    <= byte_num+1;
             if(last_data)
                begin   
               //cycle <= cycle+1;
               cycle_inc;
                 end
        end
       end
endtask

task opdone;
      begin
        state <= idle;
         done <= 1;
         
      end
endtask

////////////////read byte module signal ///////////////////
read_byte read_byte(
           .clk(clk),
           .rst_n(rst_n),
           .dly_done(dly_done),
           .read_data(read_data),
           .read_data_out(read_data_out),
           .dly(dly),
           .ack(ack),
           .read_en(read_en),
           .nf_re_n(nf_re_n),
           .dly_load(dly_load)        
         );


delay_counter  #(.counter_width(32)) 
delay_counter (
    .clk   ( clk ),
    .rst_n ( rst_n ),
    .count (dly),
    .load  ( dly_load),
    .done  ( dly_done)
);  

task  read_byte_task;
       output[7:0]  data;
       input        last_data;
       begin
       io_read       <= 1'b1;//
       read_en       <= 1;
       if(ack) begin
        read_en      <= 0; 
        data         <= read_data_out;
        byte_num     <= byte_num+1;
        if(last_data)
        //cycle        <= cycle+1;
        cycle_inc;
       end
       
      end
endtask


/////////////////////////////////////////////////////////

endmodule
