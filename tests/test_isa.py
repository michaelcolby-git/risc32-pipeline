import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from isa import addi,branch,r,lw,sw,execute
class ISA(unittest.TestCase):
    def test_known_encodings(self):
        self.assertEqual(addi(0,0,0),0x13)
        self.assertEqual(addi(1,0,-1),0xfff00093)
        self.assertEqual(r('add',3,1,2),0x002081b3)
        self.assertEqual(lw(1,0,0),0x2083)
        self.assertEqual(sw(1,0,0),0x00102023)
        self.assertEqual(branch('beq',0,0,0),0x63)
    def test_boundaries(self):
        for offset in (-4096,4092): branch('bne',1,2,offset)
        for offset in (-4097,4096,2):
            with self.assertRaises(ValueError): branch('beq',0,0,offset)
        for value in (-2049,2048):
            with self.assertRaises(ValueError): addi(1,0,value)
        with self.assertRaises(ValueError): addi(32,0,0)
    def test_wrap_and_x0(self):
        _,regs,_=execute([addi(1,0,-1),addi(2,1,1),addi(0,0,7),r('add',3,0,0)],4)
        self.assertEqual(regs[:4],[0,0xffffffff,0,0])
    def test_invalid_data_address(self):
        with self.assertRaises(ValueError): execute([lw(1,0,2)],1)
if __name__=='__main__': unittest.main()
