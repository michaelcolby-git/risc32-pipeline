`timescale 1ns/1ps
// Five-stage reference pipeline. See docs/ARCHITECTURE.md for the memory contract.
module core(input clk, reset,
  output [31:0] imem_addr, input [31:0] imem_data,
  output [31:0] dmem_addr, dmem_wdata, output dmem_we,
  input [31:0] dmem_rdata,
  output reg retire_valid, output reg [31:0] retire_pc, retire_insn,
  output reg [4:0] retire_rd, output reg [31:0] retire_data,
  output reg retire_write, output reg fault,
  output reg [31:0] cycles, retired, stalls, flushes);
  reg [31:0] regs[0:31];
  reg [31:0] pc;
  reg id_valid; reg [31:0] id_pc,id_insn;
  reg ex_valid; reg [31:0] ex_pc,ex_insn,ex_a,ex_b,ex_imm;
  reg [4:0] ex_rs1,ex_rs2,ex_rd;
  reg ex_use1,ex_use2,ex_write,ex_load,ex_store,ex_branch,ex_bne,ex_immediate;
  reg [2:0] ex_alu;
  reg mem_valid,mem_write,mem_load,mem_store;
  reg [31:0] mem_pc,mem_insn,mem_result,mem_data;
  reg [4:0] mem_rd;
  reg wb_valid,wb_write;
  reg [31:0] wb_pc,wb_insn,wb_data;
  reg [4:0] wb_rd;
  integer i;

  wire [6:0] opcode=id_insn[6:0];
  wire [2:0] funct3=id_insn[14:12];
  wire [6:0] funct7=id_insn[31:25];
  wire [4:0] rs1=id_insn[19:15],rs2=id_insn[24:20],rd=id_insn[11:7];
  reg dec_use1,dec_use2,dec_write,dec_load,dec_store,dec_branch,dec_bne,dec_immediate,dec_illegal;
  reg [2:0] dec_alu;
  reg [31:0] dec_imm;
  always @* begin
    dec_use1=0; dec_use2=0; dec_write=0; dec_load=0; dec_store=0;
    dec_branch=0; dec_bne=0; dec_immediate=0; dec_illegal=0; dec_alu=0; dec_imm=0;
    case(opcode)
      7'h33: begin
        dec_use1=1; dec_use2=1; dec_write=1;
        case({funct7,funct3})
          {7'h00,3'h0}: dec_alu=0;
          {7'h20,3'h0}: dec_alu=1;
          {7'h00,3'h7}: dec_alu=2;
          {7'h00,3'h6}: dec_alu=3;
          {7'h00,3'h4}: dec_alu=4;
          default: dec_illegal=1;
        endcase
      end
      7'h13: begin
        dec_use1=1; dec_write=1; dec_immediate=1;
        dec_imm={{20{id_insn[31]}},id_insn[31:20]};
        if(funct3!=0) dec_illegal=1;
      end
      7'h03: begin
        dec_use1=1; dec_write=1; dec_load=1; dec_immediate=1;
        dec_imm={{20{id_insn[31]}},id_insn[31:20]};
        if(funct3!=2) dec_illegal=1;
      end
      7'h23: begin
        dec_use1=1; dec_use2=1; dec_store=1; dec_immediate=1;
        dec_imm={{20{id_insn[31]}},id_insn[31:25],id_insn[11:7]};
        if(funct3!=2) dec_illegal=1;
      end
      7'h63: begin
        dec_use1=1; dec_use2=1; dec_branch=1; dec_bne=(funct3==1);
        dec_imm={{19{id_insn[31]}},id_insn[31],id_insn[7],id_insn[30:25],id_insn[11:8],1'b0};
        if(funct3!=0 && funct3!=1) dec_illegal=1;
      end
      default: dec_illegal=1;
    endcase
  end

  // WB-to-ID bypass avoids same-edge register-file visibility assumptions.
  wire [31:0] read1=(rs1==0)?0:((wb_valid&&wb_write&&wb_rd==rs1)?wb_data:regs[rs1]);
  wire [31:0] read2=(rs2==0)?0:((wb_valid&&wb_write&&wb_rd==rs2)?wb_data:regs[rs2]);
  reg [31:0] fa,fb,operand_b,alu_result;
  always @* begin
    fa=ex_a; fb=ex_b;
    if(wb_valid&&wb_write&&wb_rd!=0) begin
      if(ex_use1&&wb_rd==ex_rs1) fa=wb_data;
      if(ex_use2&&wb_rd==ex_rs2) fb=wb_data;
    end
    // Newest producer wins. Loads cannot forward their address as data.
    if(mem_valid&&mem_write&&!mem_load&&mem_rd!=0) begin
      if(ex_use1&&mem_rd==ex_rs1) fa=mem_result;
      if(ex_use2&&mem_rd==ex_rs2) fb=mem_result;
    end
    operand_b=ex_immediate?ex_imm:fb;
    case(ex_alu)
      0: alu_result=fa+operand_b;
      1: alu_result=fa-operand_b;
      2: alu_result=fa&operand_b;
      3: alu_result=fa|operand_b;
      4: alu_result=fa^operand_b;
      default: alu_result=0;
    endcase
  end
  wire [31:0] branch_target=ex_pc+ex_imm;
  wire taken=ex_valid&&ex_branch&&((fa==fb)^ex_bne);
  wire bad_align=ex_valid&&(((ex_load||ex_store)&&(alu_result[1:0]!=0)) || (taken&&(branch_target[1:0]!=0)));
  wire hazard=id_valid&&ex_valid&&ex_load&&ex_rd!=0&&
              ((dec_use1&&rs1==ex_rd)||(dec_use2&&rs2==ex_rd));
  assign imem_addr=pc;
  assign dmem_addr=mem_result;
  assign dmem_wdata=mem_data;
  assign dmem_we=mem_valid&&mem_store&&!fault&&!reset;

  always @(posedge clk) begin
    if(reset) begin
      pc<=0; id_valid<=0; ex_valid<=0; mem_valid<=0; wb_valid<=0;
      fault<=0; cycles<=0; retired<=0; stalls<=0; flushes<=0;
      retire_valid<=0; retire_pc<=0; retire_insn<=0; retire_rd<=0; retire_data<=0; retire_write<=0;
      id_pc<=0; id_insn<=0; ex_pc<=0; ex_insn<=0; ex_a<=0; ex_b<=0; ex_imm<=0;
      ex_rs1<=0; ex_rs2<=0; ex_rd<=0; ex_use1<=0; ex_use2<=0; ex_write<=0;
      ex_load<=0; ex_store<=0; ex_branch<=0; ex_bne<=0; ex_immediate<=0; ex_alu<=0;
      mem_write<=0; mem_load<=0; mem_store<=0; mem_pc<=0; mem_insn<=0; mem_result<=0; mem_data<=0; mem_rd<=0;
      wb_write<=0; wb_pc<=0; wb_insn<=0; wb_data<=0; wb_rd<=0;
      for(i=0;i<32;i=i+1) regs[i]<=0;
    end else if(!fault) begin
      cycles<=cycles+1;
      retire_valid<=wb_valid; retire_pc<=wb_pc; retire_insn<=wb_insn;
      retire_rd<=wb_rd; retire_data<=wb_data; retire_write<=wb_write;
      if(wb_valid) begin
        retired<=retired+1;
        if(wb_write&&wb_rd!=0) regs[wb_rd]<=wb_data;
      end
      regs[0]<=0;
      wb_valid<=mem_valid; wb_pc<=mem_pc; wb_insn<=mem_insn; wb_rd<=mem_rd;
      wb_write<=mem_write; wb_data<=mem_load?dmem_rdata:mem_result;
      mem_valid<=ex_valid; mem_pc<=ex_pc; mem_insn<=ex_insn; mem_rd<=ex_rd;
      mem_write<=ex_write; mem_load<=ex_load; mem_store<=ex_store;
      mem_result<=alu_result; mem_data<=fb;
      if(bad_align) begin
        fault<=1; id_valid<=0; ex_valid<=0; mem_valid<=0;
      end else if(taken) begin
        pc<=branch_target; id_valid<=0; ex_valid<=0; flushes<=flushes+1;
      end else if(hazard) begin
        ex_valid<=0; stalls<=stalls+1;
      end else if(id_valid&&dec_illegal) begin
        fault<=1; id_valid<=0; ex_valid<=0;
      end else begin
        ex_valid<=id_valid; ex_pc<=id_pc; ex_insn<=id_insn;
        ex_a<=read1; ex_b<=read2; ex_rs1<=rs1; ex_rs2<=rs2; ex_rd<=rd;
        ex_use1<=dec_use1; ex_use2<=dec_use2; ex_write<=dec_write;
        ex_load<=dec_load; ex_store<=dec_store; ex_branch<=dec_branch;
        ex_bne<=dec_bne; ex_immediate<=dec_immediate; ex_alu<=dec_alu; ex_imm<=dec_imm;
        id_valid<=1; id_pc<=pc; id_insn<=imem_data; pc<=pc+4;
      end
    end else retire_valid<=0;
  end
endmodule
