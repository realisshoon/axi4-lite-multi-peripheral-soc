module protocol_assertions(axi_lite_if a);
 int attempts=0,failures=0,b_stalls=0,r_stalls=0,aw_stalls=0,w_stalls=0,ar_stalls=0;
 // Nonvacuous counters record the antecedent at each active clock.
 always @(posedge a.ACLK) if(a.ARESETN) begin
  if(a.BVALID&&!a.BREADY)begin attempts++;b_stalls++;end
  if(a.RVALID&&!a.RREADY)begin attempts++;r_stalls++;end
  if(a.AWVALID&&!a.AWREADY)begin attempts++;aw_stalls++;end
  if(a.WVALID&&!a.WREADY)begin attempts++;w_stalls++;end
  if(a.ARVALID&&!a.ARREADY)begin attempts++;ar_stalls++;end
 end
 ap_b:assert property(@(posedge a.ACLK) disable iff(!a.ARESETN) a.BVALID&&!a.BREADY |=> a.BVALID&&$stable(a.BRESP))else begin failures++;$error("ASSERT B stable");end
 ap_r:assert property(@(posedge a.ACLK) disable iff(!a.ARESETN) a.RVALID&&!a.RREADY |=> a.RVALID&&$stable({a.RDATA,a.RRESP}))else begin failures++;$error("ASSERT R stable");end
 ap_aw:assert property(@(posedge a.ACLK) disable iff(!a.ARESETN) a.AWVALID&&!a.AWREADY |=> a.AWVALID&&$stable({a.AWADDR,a.AWPROT}))else begin failures++;$error("ASSERT AW stable");end
 ap_w:assert property(@(posedge a.ACLK) disable iff(!a.ARESETN) a.WVALID&&!a.WREADY |=> a.WVALID&&$stable({a.WDATA,a.WSTRB}))else begin failures++;$error("ASSERT W stable");end
 ap_ar:assert property(@(posedge a.ACLK) disable iff(!a.ARESETN) a.ARVALID&&!a.ARREADY |=> a.ARVALID&&$stable({a.ARADDR,a.ARPROT}))else begin failures++;$error("ASSERT AR stable");end
 final $display("ASSERT_RESULT attempts=%0d failures=%0d b_stalls=%0d r_stalls=%0d aw_stalls=%0d w_stalls=%0d ar_stalls=%0d",attempts,failures,b_stalls,r_stalls,aw_stalls,w_stalls,ar_stalls);
endmodule
