`timescale 1ns/1ps
// Testbench Mode-0 pin responder. MISO changes only on CS assertion or falling SCLK.
// No system-clock synchronizer latency is introduced by the verification model.
module spi_pin_responder(input clk,reset,sclk,mosi,cs_n,input[7:0]tx_data,
 output logic miso,output logic[7:0]rx_data,output logic rx_done,tx_busy);
 logic[7:0]tx_shift,rx_shift;int bits;
 initial begin miso=0;rx_data=0;rx_done=0;tx_busy=0;bits=0;tx_shift=0;rx_shift=0;end
 always @(negedge cs_n)begin tx_shift=tx_data;miso=tx_data[7];rx_shift=0;bits=0;rx_done=0;tx_busy=1;end
 always @(negedge sclk)if(!cs_n&&!reset)begin tx_shift={tx_shift[6:0],1'b0};miso=tx_shift[7];end
 always @(posedge sclk)if(!cs_n&&!reset)begin rx_shift={rx_shift[6:0],mosi};bits++;if(bits==8)begin rx_data=rx_shift;rx_done=1;end end
 always @(posedge cs_n or posedge reset)begin miso=0;tx_busy=0;if(reset)begin rx_data=0;rx_done=0;end end
endmodule
