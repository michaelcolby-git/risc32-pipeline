"""Checked encoders and an independent sequential interpreter for the supported subset."""
MASK=0xffffffff
def reg(x):
    if not isinstance(x,int) or not 0<=x<32: raise ValueError('Register outside x0..x31')
    return x
def imm(x,bits):
    if not isinstance(x,int) or not -(1<<(bits-1))<=x<(1<<(bits-1)): raise ValueError('Immediate out of range')
    return x&((1<<bits)-1)
def r(op,rd,rs1,rs2):
    f7,f3={'add':(0,0),'sub':(32,0),'and':(0,7),'or':(0,6),'xor':(0,4)}[op]
    return f7<<25|reg(rs2)<<20|reg(rs1)<<15|f3<<12|reg(rd)<<7|0x33
def addi(rd,rs1,value): return imm(value,12)<<20|reg(rs1)<<15|reg(rd)<<7|0x13
def lw(rd,rs1,offset): return imm(offset,12)<<20|reg(rs1)<<15|2<<12|reg(rd)<<7|3
def sw(rs2,rs1,offset):
    v=imm(offset,12)
    return (v>>5)<<25|reg(rs2)<<20|reg(rs1)<<15|2<<12|(v&31)<<7|0x23
def branch(op,rs1,rs2,offset):
    if offset%4: raise ValueError('This core requires word-aligned branch targets')
    v=imm(offset,13); f3={'beq':0,'bne':1}[op]
    return (v>>12)<<31|((v>>5)&63)<<25|reg(rs2)<<20|reg(rs1)<<15|f3<<12|((v>>1)&15)<<8|((v>>11)&1)<<7|0x63
def signed(v,bits): return v-(1<<bits) if v&(1<<(bits-1)) else v
def execute(program,count):
    regs=[0]*32; memory=[0]*256; pc=0; trace=[]
    for _ in range(count):
        if pc%4 or not 0<=pc//4<len(program): raise ValueError('PC outside program')
        ins=program[pc//4]; opc=ins&127; rd=(ins>>7)&31; f3=(ins>>12)&7
        rs1=(ins>>15)&31; rs2=(ins>>20)&31; a,b=regs[rs1],regs[rs2]
        nxt=(pc+4)&MASK; value=0; write=False
        if opc==0x33:
            f7=ins>>25
            if (f7,f3)==(0,0): value=a+b
            elif (f7,f3)==(32,0): value=a-b
            elif (f7,f3)==(0,7): value=a&b
            elif (f7,f3)==(0,6): value=a|b
            elif (f7,f3)==(0,4): value=a^b
            else: raise ValueError('Unsupported R instruction')
            write=True
        elif opc==0x13 and f3==0:
            value=a+signed(ins>>20,12); write=True
        elif opc in (3,0x23) and f3==2:
            offset=signed(ins>>20,12) if opc==3 else signed(((ins>>25)<<5)|rd,12)
            addr=(a+offset)&MASK
            if addr%4 or addr>=1024: raise ValueError('Invalid data address')
            if opc==3: value=memory[addr//4]; write=True
            else: memory[addr//4]=b
        elif opc==0x63 and f3 in (0,1):
            offset=signed(((ins>>31)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&63)<<5)|(((ins>>8)&15)<<1),13)
            if (a==b) != bool(f3): nxt=(pc+offset)&MASK
        else: raise ValueError('Unsupported instruction')
        value &= MASK
        if write and rd: regs[rd]=value
        trace.append({'pc':pc,'instruction':ins,'write':int(write),'rd':rd,'data':value})
        pc=nxt
    return trace,regs,memory
