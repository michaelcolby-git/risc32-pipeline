`timescale 1ns/1ps
module tb_core;
  reg clk=0,reset=1;
  always #10 clk=~clk; // 20 ns simulation period, not synthesized Fmax.
  wire [31:0] ia,da,dw;
  wire we,rv,rw,fault;
  wire [31:0] rp,ri,rd,cycles,retired,stalls,flushes;
  wire [4:0] rr;
  reg [31:0] imem[0:4095],dmem[0:255];
  wire [31:0] instruction=(ia<16384)?imem[ia[13:2]]:32'h00000013;
  wire [31:0] load_data=(da<1024)?dmem[da[9:2]]:32'h00000000;
  core dut(clk,reset,ia,instruction,da,dw,we,load_data,rv,rp,ri,rr,rd,rw,fault,cycles,retired,stalls,flushes);
  integer i,fd,unused,expect_retired,expect_fault;
  reg [1023:0] program_file;
  initial begin
    for(i=0;i<4096;i=i+1) imem[i]=32'h00000013;
    for(i=0;i<256;i=i+1) dmem[i]=0;
    if(!$value$plusargs("PROGRAM=%s",program_file)) $fatal(1,"PROGRAM required");
    if(!$value$plusargs("COUNT=%d",expect_retired)) $fatal(1,"COUNT required");
    expect_fault=0; unused=$value$plusargs("FAULT=%d",expect_fault);
    $readmemh(program_file,imem);
    if($test$plusargs("VCD")) begin $dumpfile("build/pipeline.vcd"); $dumpvars(0,tb_core); end
    fd=$fopen("build/trace.csv","w");
    $fdisplay(fd,"cycle,pc,instruction,write,rd,data");
    repeat(2) @(negedge clk);
    reset=0;
  end
  always @(posedge clk) if(!reset&&we) begin
    if(da[1:0]!=0 || da>=1024) $fatal(1,"Invalid store address %h",da);
    dmem[da[9:2]]<=dw;
  end
  always @(negedge clk) if(!reset) begin
    if(rv) $fdisplay(fd,"%0d,%08h,%08h,%0d,%0d,%08h",cycles,rp,ri,rw,rr,rd);
    if(fault) begin
      if(!expect_fault) $fatal(1,"Unexpected fault");
      $display("PASS expected fault"); $fclose(fd); $finish;
    end
    if(!expect_fault && retired==expect_retired) begin
      $display("PASS cycles=%0d retired=%0d stalls=%0d flushes=%0d",cycles,retired,stalls,flushes);
      $writememh("build/memory.hex",dmem);
      $fclose(fd); $finish;
    end
    if(cycles>20000) $fatal(1,"Timeout");
  end
endmodule
