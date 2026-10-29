`include "uvm_macros.svh"
import uvm_pkg::*;
`include "axi_lite_transaction.sv"
`include "coverage.sv"
class enhanced_item extends uvm_sequence_item;
 `uvm_object_utils(enhanced_item)
 int op; // 0 write, 1 read, 2 reset, 3 wait
 bit [3:0] addr; bit [31:0] data; bit [3:0] strb=15;
 int order=0,gap=0,stall=0,cycles=0;
 function new(string name="enhanced_item"); super.new(name); endfunction
endclass
class enhanced_scoreboard extends uvm_component;
 `uvm_component_utils(enhanced_scoreboard)
 virtual axi_lite_if v; virtual spi_if s;
 spi_axi_coverage legacy;
 logic [31:0] cr=32'h6400, tx=0;
 logic [7:0] rx=0;
 bit done=0; int done_delay=0;
 int checks=0, passes=0, fails=0, writes=0, reads=0, spi_transfers=0,resets=0,aborted_spi=0;
 int accepted_aw=0,accepted_w=0,accepted_ar=0,completed_b=0,completed_r=0;
 int reset_aborted_aw=0,reset_aborted_w=0,reset_aborted_ar=0;
 logic [3:0] awq[$]; logic [31:0] wq[$]; logic [3:0] strbq[$];
 logic [31:0] readq[$];
 logic [3:0] readaddrq[$];
 int legacy_done_forwarded=0,legacy_non_sr_rejected=0;
 logic [7:0] expected_mosi[$]; logic [7:0] expected_miso[$];
 int cov_order,cov_strobe,cov_addr,cov_rw,cov_stall,cov_gap;
 int order_counts[3], strobe_counts[16], address_counts[4], stall_counts[3];
 covergroup protocol_cg with function sample(int ordering,int strobe,int address,int rw,int stallclass);
  option.per_instance=1;
  ordering_cp: coverpoint ordering {bins simultaneous={0}; bins aw_before_w={1}; bins w_before_aw={2}; ignore_bins reads={-1};}
  strobe_cp: coverpoint strobe {bins zero={0}; bins full={15}; bins partial[]={[1:14]}; ignore_bins reads={-1};}
  addr_cp: coverpoint address {bins cr={0};bins tx={1};bins rx={2};bins sr={3};}
  rw_cp: coverpoint rw {bins write={0}; bins read={1};}
  stall_cp: coverpoint stallclass {bins none={0}; bins short_stall={1};bins long_stall={2};}
  address_rw: cross addr_cp,rw_cp;
 endgroup
 function new(string name,uvm_component parent);super.new(name,parent);protocol_cg=new();endfunction
 function void build_phase(uvm_phase phase);
  if(!uvm_config_db#(virtual axi_lite_if)::get(this,"","axi_vif",v)) `uvm_fatal("VIF","AXI VIF missing")
  if(!uvm_config_db#(virtual spi_if)::get(this,"","spi_vif",s)) `uvm_fatal("VIF","SPI VIF missing")
 endfunction
 function void verify(bit condition,string text);
  checks++; if(condition) passes++; else begin fails++; `uvm_error("CHECK",text) end
 endfunction
 function void reset_model();
  cr=32'h6400; tx=0;rx=0;done=0;done_delay=0;resets++;
  reset_aborted_aw=accepted_aw-completed_b;reset_aborted_w=accepted_w-completed_b;reset_aborted_ar=accepted_ar-completed_r;
  awq.delete();wq.delete();strbq.delete();readq.delete();readaddrq.delete();
  if(expected_mosi.size()) aborted_spi+=expected_mosi.size();
  expected_mosi.delete();expected_miso.delete();
 endfunction
 function void write_model(logic[3:0] a,logic[31:0] d,logic[3:0] st);
  axi_lite_transaction tr; logic[31:0] merged;
  writes++;
  verify(!$isunknown({a,d,st}),"X/Z write address/data/strobe");
  merged=(a[3:2]==0)?cr:tx;
  for(int b=0;b<4;b++) if(st[b]) merged[b*8+:8]=d[b*8+:8];
  case(a[3:2])
   0:begin
    cr=merged;
    if(st[0] && d[0]) begin
     done=0;
     if(s.cs_n===1'b1) begin expected_mosi.push_back(tx[7:0]);expected_miso.push_back(s.slave_tx_data);end
    end
    if(st[0] && d[1]) done=0;
   end
   1:tx=merged;
  endcase
  tr=new();tr.kind=AXI_LITE_ITEM_WRITE;tr.addr=a;tr.data=d;
  legacy.axi_fifo.write(tr);
 endfunction
 function logic [31:0] expected_read(logic [3:0] a);
  case(a[3:2])
   0:return cr;1:return tx;2:return {24'd0,rx};3:return {30'd0,done,~s.cs_n};
  endcase
 endfunction
 task run_phase(uvm_phase phase);
  bit inreset=0; logic[3:0] a,st;logic[31:0] d,exp;
  forever begin
   @(posedge v.ACLK);
   if(!v.ARESETN) begin if(!inreset)reset_model();inreset=1;end
   else begin
    inreset=0;
    if(done_delay>0) begin done_delay--; if(done_delay==0)done=1;end
    if(v.AWVALID&&v.AWREADY)begin awq.push_back(v.AWADDR);accepted_aw++;end
    if(v.WVALID&&v.WREADY)begin wq.push_back(v.WDATA);strbq.push_back(v.WSTRB);accepted_w++;end
    if(awq.size()&&wq.size())begin a=awq.pop_front();d=wq.pop_front();st=strbq.pop_front();write_model(a,d,st);end
    if(v.ARVALID&&v.ARREADY)begin
     verify(!$isunknown(v.ARADDR),"X/Z AR address");readq.push_back(expected_read(v.ARADDR));readaddrq.push_back(v.ARADDR);accepted_ar++;
    end
    if(v.BVALID&&v.BREADY)begin completed_b++;verify(v.BRESP===0,"BRESP not OKAY/known");end
    if(v.RVALID&&v.RREADY)begin
     completed_r++;reads++;
     verify(readq.size()>0&&readaddrq.size()>0,"Unexpected/duplicate R response or missing paired AR address");
     if(readq.size()&&readaddrq.size())begin
      exp=readq.pop_front();a=readaddrq.pop_front();
      verify(v.RDATA===exp,$sformatf("Read mismatch addr=%h expected=%08h actual=%08h",a,exp,v.RDATA));
      // Forward legacy DONE only for the actual paired status-register read.
      if(v.RDATA[1]&&done)begin
       if(a==SPI_AXI_SR_ADDR)begin
        axi_lite_transaction tr;tr=new();tr.kind=AXI_LITE_ITEM_READ;tr.addr=a;tr.rdata=v.RDATA;legacy.axi_fifo.write(tr);legacy_done_forwarded++;
       end else legacy_non_sr_rejected++;
      end
     end
     verify(v.RRESP===0,"RRESP not OKAY/known");
    end
   end
  end
 endtask
 task pin_monitor();
  logic[7:0] mo,mi,e;int bits;bit aborted;
  forever begin
   @(negedge s.cs_n);mo=0;mi=0;bits=0;aborted=0;
   while(s.cs_n===0 && v.ARESETN)begin
    @(posedge s.sclk or posedge s.cs_n or negedge v.ARESETN);
    if(!v.ARESETN)begin aborted=1;break;end
    if(!s.cs_n)begin verify(!$isunknown({s.mosi,s.miso}),"X/Z SPI pins");mo={mo[6:0],s.mosi};mi={mi[6:0],s.miso};bits++;end
   end
   if(!aborted && v.ARESETN)begin
    axi_lite_transaction tr;
    verify(bits==8,$sformatf("SPI rising edge count=%0d",bits));
    verify(expected_mosi.size()>0,"Unexpected SPI transfer");
    if(expected_mosi.size())begin e=expected_mosi.pop_front();verify(mo===e,$sformatf("MOSI expected=%02h actual=%02h",e,mo));end
    if(expected_miso.size())begin e=expected_miso.pop_front();verify(mi===e,$sformatf("MISO expected=%02h actual=%02h",e,mi));end
    rx=mi;done_delay=1;spi_transfers++;
    tr=new();tr.kind=AXI_LITE_ITEM_SPI;tr.spi_complete=1;legacy.spi_fifo.write(tr);
   end
  end
 endtask
 function void sample_protocol(enhanced_item tr);
  int st;st=tr.stall==0?0:(tr.stall<5?1:2);
  if(tr.op==0)begin order_counts[tr.order]++;strobe_counts[tr.strb]++;end
  address_counts[tr.addr[3:2]]++;stall_counts[st]++;
  protocol_cg.sample(tr.op==0?tr.order:-1,tr.op==0?int'(tr.strb):-1,tr.addr[3:2],tr.op,st);
 endfunction
 function void report_phase(uvm_phase phase);
  verify(awq.size()==0&&wq.size()==0&&readq.size()==0&&readaddrq.size()==0&&expected_mosi.size()==0,"Pending queue at end of test");
  verify(accepted_aw-reset_aborted_aw==completed_b,"AW/B count mismatch excluding reset abort");
  verify(accepted_w-reset_aborted_w==completed_b,"W/B count mismatch excluding reset abort");
  verify(accepted_ar-reset_aborted_ar==completed_r,"AR/R count mismatch excluding reset abort");
  `uvm_info("SUMMARY",$sformatf("AXI_RESULT writes=%0d reads=%0d aw=%0d w=%0d b=%0d ar=%0d r=%0d spi=%0d aborted_spi=%0d checks=%0d passes=%0d fails=%0d pending=%0d resets=%0d protocol_cov=%0.4f",writes,reads,accepted_aw,accepted_w,completed_b,accepted_ar,completed_r,spi_transfers,aborted_spi,checks,passes,fails,awq.size()+wq.size()+readq.size()+expected_mosi.size(),resets,protocol_cg.get_inst_coverage()),UVM_NONE)
  `uvm_info("COLLECTOR",$sformatf("COLLECTOR_RESULT sr_done_samples=%0d rejected_non_sr_bit1=%0d",legacy_done_forwarded,legacy_non_sr_rejected),UVM_NONE)
  for(int i=0;i<3;i++)`uvm_info("DIST",$sformatf("order[%0d]=%0d stall[%0d]=%0d",i,order_counts[i],i,stall_counts[i]),UVM_NONE)
  for(int i=0;i<16;i++)`uvm_info("DIST",$sformatf("strobe[%0d]=%0d",i,strobe_counts[i]),UVM_NONE)
 endfunction
endclass
class enhanced_driver extends uvm_driver#(enhanced_item);
 `uvm_component_utils(enhanced_driver)
 virtual axi_lite_if v;virtual spi_if s;int issued=0,completed=0;enhanced_scoreboard scb;
 function new(string name,uvm_component p);super.new(name,p);endfunction
 function void build_phase(uvm_phase phase);
  if(!uvm_config_db#(virtual axi_lite_if)::get(this,"","axi_vif",v))`uvm_fatal("VIF","no AXI")
  if(!uvm_config_db#(virtual spi_if)::get(this,"","spi_vif",s))`uvm_fatal("VIF","no SPI")
 endfunction
 task reset_bus();
  @(negedge v.ACLK);v.ARESETN=0;v.AWVALID=0;v.WVALID=0;v.ARVALID=0;v.BREADY=0;v.RREADY=0;
  repeat(5)@(negedge v.ACLK);v.ARESETN=1;repeat(3)@(negedge v.ACLK);
 endtask
 task aw(enhanced_item t,int delay_cycles);
  repeat(delay_cycles)@(negedge v.ACLK);v.AWADDR=t.addr;v.AWVALID=1;
  begin int n=0;do begin @(posedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","AWREADY timeout")end while(v.AWREADY!==1);end
  @(negedge v.ACLK);v.AWVALID=0;
 endtask
 task wd(enhanced_item t,int delay_cycles);
  repeat(delay_cycles)@(negedge v.ACLK);v.WDATA=t.data;v.WSTRB=t.strb;v.WVALID=1;
  begin int n=0;do begin @(posedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","WREADY timeout")end while(v.WREADY!==1);end
  @(negedge v.ACLK);v.WVALID=0;
 endtask
 task ar_only(bit[3:0]address);
  v.ARADDR=address;v.ARVALID=1;
  begin int n=0;do begin @(posedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","pipelined AR timeout")end while(v.ARREADY!==1);end
  @(negedge v.ACLK);v.ARVALID=0;
 endtask
 task retire_r();
  begin int n=0;while(v.RVALID!==1)begin @(negedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","pipelined R lost/timeout")end end
  v.RREADY=1;@(posedge v.ACLK);@(negedge v.ACLK);v.RREADY=0;
 endtask
 task retire_b();
  begin int n=0;while(v.BVALID!==1)begin @(negedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","pipelined B timeout")end end
  v.BREADY=1;@(posedge v.ACLK);@(negedge v.ACLK);v.BREADY=0;
 endtask
 task drive(enhanced_item t);
  if(t.op==2)begin reset_bus();return;end
  if(t.op==3)begin repeat(t.cycles)@(negedge v.ACLK);return;end
  if(t.op inside {[4:7]})begin
   @(negedge v.ACLK);
   if(t.op==4)aw(t,0);
   if(t.op==5)wd(t,0);
   if(t.op==6)begin fork aw(t,0);wd(t,0);join repeat(4)@(negedge v.ACLK);end
   if(t.op==7)begin ar_only(4);repeat(4)@(negedge v.ACLK);end
   reset_bus();return;
  end
  if(t.op==8)begin
   issued+=2;@(negedge v.ACLK);ar_only(0);
   // Hold the first R while a second AR is offered; second AR must not be lost.
   fork
    begin ar_only(4);end
    begin repeat(8)@(negedge v.ACLK);retire_r();end
   join
   retire_r();completed+=2;return;
  end
  if(t.op==9)begin
   enhanced_item t2;t2=new();t2.addr=4;t2.data=32'h76543210;t2.strb=15;
   issued+=2;@(negedge v.ACLK);fork aw(t2,0);wd(t2,0);join
   repeat(3)@(negedge v.ACLK);t2.data=32'habcdef98;
   fork
    begin fork aw(t2,0);wd(t2,0);join end
    begin repeat(8)@(negedge v.ACLK);retire_b();end
   join
   retire_b();completed+=2;return;
  end
  issued++;@(negedge v.ACLK);
  if(t.op==0)begin
   fork aw(t,t.order==2?t.gap:0);wd(t,t.order==1?t.gap:0);join
   begin int n=0;while(v.BVALID!==1)begin @(negedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","BVALID timeout")end end
   repeat(t.stall)@(negedge v.ACLK);v.BREADY=1;@(posedge v.ACLK);@(negedge v.ACLK);v.BREADY=0;
  end else begin
   v.ARADDR=t.addr;v.ARVALID=1;
   begin int n=0;do begin @(posedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","ARREADY timeout")end while(v.ARREADY!==1);end
   @(negedge v.ACLK);v.ARVALID=0;
   begin int n=0;while(v.RVALID!==1)begin @(negedge v.ACLK);n++;if(n>128)`uvm_fatal("TIMEOUT","RVALID timeout")end end
   repeat(t.stall)@(negedge v.ACLK);v.RREADY=1;@(posedge v.ACLK);@(negedge v.ACLK);v.RREADY=0;
  end
  completed++;scb.sample_protocol(t);
 endtask
 task run_phase(uvm_phase phase);
  enhanced_item t;forever begin seq_item_port.get_next_item(t);drive(t);seq_item_port.item_done();end
 endtask
endclass
class enhanced_sequence extends uvm_sequence#(enhanced_item);
 `uvm_object_utils(enhanced_sequence)
 int nrandom=0;string mode="directed";virtual spi_if s;
 function new(string name="enhanced_sequence");super.new(name);endfunction
 task access(int op,bit[3:0]addr=0,bit[31:0]data=0,bit[3:0]strb=15,int order=0,int gap=0,int stall=0,int cycles=0);
  enhanced_item t;t=new();start_item(t);t.op=op;t.addr=addr;t.data=data;t.strb=strb;t.order=order;t.gap=gap;t.stall=stall;t.cycles=cycles;finish_item(t);
 endtask
 task transfer(bit[7:0]tx,bit[7:0]miso,int divider,int order,int stall,bit busy_start=0);
  s.slave_tx_data=miso;
  access(0,4,tx,15,order,3,stall);access(0,0,(divider<<8)|1,15,order,3,stall);
  if(busy_start)begin access(1,12);access(0,0,(divider<<8)|1);end
  access(3,0,0,15,0,0,0,16*(divider+1)+20);
  access(1,8,0,15,0,0,stall);access(1,12,0,15,0,0,stall);
  access(0,0,(divider<<8)|2);access(1,12);
 endtask
 task body();
  int a,d,st,o,g,b,div;bit[7:0] pat[4]='{8'h00,8'hff,8'ha5,8'h5a};
  access(2);for(int i=0;i<4;i++)access(1,i*4);
  if(mode=="read_capacity")begin access(8);return;end
  // Exact zero/partial strobe reproducer before any large regression.
  access(0,4,32'h11223344);access(0,4,32'hdeadbeef,0);access(1,4);
  access(0,4,32'hcafebabe,5);access(1,4);
  if(mode=="baseline")return;
  if(mode=="strobe_sideeffects")begin
   // Masked START must not start; masked CLR_STATUS must not clear DONE.
   access(0,0,32'h00000200);access(0,0,32'h00000201,0);access(3,0,0,15,0,0,0,100);access(1,0);access(1,12);
   access(0,0,32'h00000201,2);access(3,0,0,15,0,0,0,100);access(1,0);access(1,12);
   s.slave_tx_data=8'h3c;access(0,4,8'hc3);access(0,0,32'h00000201);access(3,0,0,15,0,0,0,100);access(1,8);access(1,12);
   access(0,0,32'h00000202,0);access(1,12);access(0,0,32'h00000202,2);access(1,12);
   access(0,0,32'h00000202,1);access(1,12);return;
  end
  if(mode=="smoke")begin transfer(8'ha5,8'h5a,2,0,0);return;end
  // Every byte mask, ordering and stall category exercises all register word addresses.
  for(int i=0;i<16;i++)begin
   access(0,4,32'h10203040^i,i,i%3,2+(i%4),i%7);access(1,4,0,15,0,0,i%7);
   access(0,0,32'h00000a00,i,i%3,3,i%7);access(1,0);
   access(0,8,32'hffffffff,i,i%3,3,i%7);access(1,8);
   access(0,12,32'hffffffff,i,i%3,3,i%7);access(1,12);
  end
  for(int i=0;i<4;i++)transfer(pat[i],pat[3-i],2+i,i%3,i%7,i==3);
  // Reset while SPI is active, followed by reset-default and recovery checks.
  s.slave_tx_data=8'h69;access(0,4,8'h96);access(0,0,32'h1401);access(3,0,0,15,0,0,0,8);access(2);
  for(int i=0;i<4;i++)access(1,i*4);transfer(8'h55,8'haa,3,1,6);
  // Reset aborts unmatched AW, unmatched W, stalled B and stalled R separately.
  access(8);access(9);access(1,4);
  for(int r=4;r<=7;r++)begin access(r,4,32'h12345678);for(int a=0;a<4;a++)access(1,a*4);end
  transfer(8'h81,8'h18,0,2,8); // recovery and minimum programmable divider
  // Random writes/reads include all byte masks and independently delayed AW/W.
  for(int j=0;j<nrandom;j++)begin
   a=$urandom_range(0,3);d=$urandom;st=$urandom_range(0,15);o=$urandom_range(0,2);g=$urandom_range(1,8);b=$urandom_range(0,9);
   // Avoid undocumented free-running START: directed transfers check START separately.
   if(a==0)d=(d&32'hffff0000)|($urandom_range(0,31)<<8);
   access(0,a*4,d,st,o,g,b);access(1,a*4,0,15,0,0,$urandom_range(0,9));
   if((j%100)==99)transfer($urandom,$urandom,$urandom_range(1,15),o,b);
  end
 endtask
endclass
class enhanced_env extends uvm_env;
 `uvm_component_utils(enhanced_env)
 uvm_sequencer#(enhanced_item) seqr;enhanced_driver drv;enhanced_scoreboard scb;spi_axi_coverage cov;
 function new(string name,uvm_component p);super.new(name,p);endfunction
 function void build_phase(uvm_phase phase);
  seqr=new("seqr",this);drv=enhanced_driver::type_id::create("drv",this);scb=enhanced_scoreboard::type_id::create("scb",this);cov=spi_axi_coverage::type_id::create("legacy_coverage",this);
 endfunction
 function void connect_phase(uvm_phase phase);drv.seq_item_port.connect(seqr.seq_item_export);drv.scb=scb;scb.legacy=cov;endfunction
 task run_phase(uvm_phase phase);scb.pin_monitor();endtask
endclass
class enhanced_test extends uvm_test;
 `uvm_component_utils(enhanced_test)
 enhanced_env e;
 function new(string name,uvm_component p);super.new(name,p);endfunction
 function void build_phase(uvm_phase phase);e=enhanced_env::type_id::create("e",this);endfunction
 task run_phase(uvm_phase phase);
  enhanced_sequence seq;seq=new();void'($value$plusargs("MODE=%s",seq.mode));void'($value$plusargs("N=%d",seq.nrandom));
  if(!uvm_config_db#(virtual spi_if)::get(this,"","spi_vif",seq.s))`uvm_fatal("VIF","no SPI")
  phase.raise_objection(this);seq.start(e.seqr);repeat(10)@(negedge e.drv.v.ACLK);
  `uvm_info("DRIVER",$sformatf("DRIVER_RESULT issued=%0d completed=%0d",e.drv.issued,e.drv.completed),UVM_NONE)
  phase.drop_objection(this);
 endtask
endclass
