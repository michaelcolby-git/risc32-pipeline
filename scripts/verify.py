"""Differential retirement checks, memory checks, directed timing checks, fixed-seed random tests."""
import csv,json,os,random,re,subprocess
from pathlib import Path
from isa import r,addi,lw,sw,branch,execute
ROOT=Path(__file__).resolve().parents[1]; BUILD=ROOT/'build'
def run(cmd):
    p=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if p.returncode: raise RuntimeError(p.stdout)
    return p.stdout
def case(name,program,count=None,stall_count=None,fault=False,vcd=False):
    count=count or len(program)
    # NOP padding prevents instruction fetch overrun and allows clean pipeline drain.
    path=BUILD/(name+'.hex')
    path.write_text(''.join(f'{v:08x}\n' for v in program+[addi(0,0,0)]*(4096-len(program))))
    cmd=[os.getenv('VVP','vvp'),'build/core.vvp','+PROGRAM=build/'+path.name,f'+COUNT={count}']
    if fault: cmd+=['+FAULT=1']
    if vcd: cmd+=['+VCD']
    log=run(cmd); (BUILD/(name+'.log')).write_text(log)
    if fault:
        if 'PASS expected fault' not in log: raise AssertionError(log)
        return {'name':name,'expected_fault':True}
    expected,regs,memory=execute(program,count)
    with (BUILD/'trace.csv').open() as f: actual=list(csv.DictReader(f))
    if len(actual)!=count: raise AssertionError((name,'retirement count',len(actual),count))
    for i,(a,e) in enumerate(zip(actual,expected)):
        for key in ('pc','instruction','write','rd','data'):
            if key in ('rd','data') and not e['write']: continue
            value=int(a[key],16 if key in ('pc','instruction','data') else 10)
            if value!=e[key]: raise AssertionError((name,i,key,value,e[key]))
    got=[int(x,16) for x in (BUILD/'memory.hex').read_text().splitlines() if x and not x.startswith('//')]
    if got!=memory: raise AssertionError((name,'data memory mismatch'))
    m=re.search(r'PASS cycles=(\d+) retired=(\d+) stalls=(\d+) flushes=(\d+)',log)
    if not m: raise AssertionError(log)
    cycles,retired,stalls,flushes=map(int,m.groups())
    if stall_count is not None and stalls!=stall_count: raise AssertionError((name,'stalls',stalls,stall_count))
    (BUILD/(name+'.csv')).write_text((BUILD/'trace.csv').read_text())
    return dict(name=name,cycles=cycles,retired=retired,stalls=stalls,flushes=flushes,ipc=retired/cycles)
def main():
    BUILD.mkdir(exist_ok=True)
    run([os.getenv('IVERILOG','iverilog'),'-g2012','-Wall','-s','tb_core','-o','build/core.vvp','rtl/core.v','tests/tb_core.v'])
    tests=[]
    tests.append(case('forwarding',[addi(1,0,7),addi(1,1,3),r('add',2,1,1),r('sub',3,2,1),r('xor',4,2,3),r('and',5,4,3),r('or',6,5,1),sw(6,0,0)],stall_count=0,vcd=True))
    tests.append(case('load_use',[addi(1,0,42),sw(1,0,0),lw(2,0,0),r('add',3,2,2),sw(3,0,4)],stall_count=1))
    tests.append(case('load_store',[addi(1,0,24),sw(1,0,0),lw(2,0,0),sw(2,0,4),lw(3,0,4)],stall_count=1))
    tests.append(case('load_branch',[lw(1,0,0),branch('beq',1,0,12),sw(1,0,0),addi(2,0,99),addi(2,0,5)],count=3,stall_count=1))
    tests.append(case('branch_flush',[addi(1,0,7),branch('beq',1,1,12),sw(1,0,0),0xffffffff,addi(2,0,3),branch('bne',2,1,8),sw(1,0,4),sw(2,0,8)],count=5,stall_count=0))
    tests.append(case('not_taken',[addi(1,0,1),branch('beq',1,0,8),addi(2,0,2),branch('bne',1,1,8),sw(2,0,0)],stall_count=0))
    tests.append(case('zero_register',[addi(0,0,7),lw(0,0,0),r('add',1,0,0),addi(2,0,-1),r('add',3,2,2),sw(3,0,0)],stall_count=0))
    tests.append(case('wb_id',[addi(1,0,13),addi(2,0,2),addi(3,0,3),r('add',4,1,1),sw(4,0,0)],stall_count=0))
    tests.append(case('loop',[addi(1,0,5),addi(2,0,0),r('add',2,2,1),addi(1,1,-1),branch('bne',1,0,-8),sw(2,0,0)],count=18,stall_count=0))
    tests.append(case('offset_sign',[addi(1,0,16),addi(2,0,-2048),sw(2,1,-4),lw(3,1,-4),addi(4,3,2047),sw(4,1,-8)],stall_count=1))
    for seed in range(12):
        rng=random.Random(seed); program=[]
        for _ in range(250):
            choice=rng.randrange(4); rd=rng.randrange(1,16); a=rng.randrange(16); b=rng.randrange(16)
            if choice==0: ins=addi(rd,a,rng.randrange(-2048,2048))
            elif choice==1: ins=r(rng.choice(['add','sub','and','or','xor']),rd,a,b)
            elif choice==2: ins=sw(b,0,4*rng.randrange(32))
            else: ins=lw(rd,0,4*rng.randrange(32))
            program.append(ins)
        tests.append(case('random_'+str(seed),program))
    tests.append(case('illegal',[0xffffffff],fault=True))
    tests.append(case('unaligned_load',[lw(1,0,2)],fault=True))
    tests.append(case('unaligned_store',[sw(0,0,2)],fault=True))
    # Encoder refuses this offset, deliberately inject its legal ISA encoding to test core policy.
    tests.append(case('unaligned_branch',[0x00000163],fault=True))
    report={'clock_period_ns':20,'measurement':'cycles from first post-reset fetch through last requested retirement; includes fill, stalls and flushes','tests':tests}
    (BUILD/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS {len(tests)} processor scenarios; retirement traces and final memory match independent interpreter')
    for t in tests:
        if 'ipc' in t: print(f"{t['name']}: retired={t['retired']} cycles={t['cycles']} stalls={t['stalls']} IPC={t['ipc']:.4f}")
if __name__=='__main__': main()
