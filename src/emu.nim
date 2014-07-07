from math import random, randomize
import strutils

const 
  maxRomSize = 3584
  memorySize = 4096
  dispRows = 32
  dispColumns = 64
  dispSize = 2048

type
  TEmu {.pure, final.} = object
    stack, memory, V, display, keys: seq[int]
    I, PC, vx, vy, delayTimer, soundTimer, opcode: int
    surface: graphics.PSurface
    draw: bool
    fnmap: TTable[int, proc()]
  PEmu = ref TEmu

proc `&=`[T: TOrdinal](x: var T, y: T) =
  x = x and y

proc `|=`[T: TOrdinal](x: var T, y: T) =
  x = x or y

proc `^=`[T: TOrdinal](x: var T, y: T) =
  x = x xor y

proc createEmu(): PEmu =

  math.randomize()

  var 
    emu: PEmu
    fontSet: array[80, int]

  emu = new(TEmu)

  fontSet = [0xF0, 0x90, 0x90, 0x90, 0xF0, #0
             0x20, 0x60, 0x20, 0x20, 0x70, #1
             0xF0, 0x10, 0xF0, 0x80, 0xF0, #2
             0xF0, 0x10, 0xF0, 0x10, 0xF0, #3
             0x90, 0x90, 0xF0, 0x10, 0x10, #4
             0xF0, 0x80, 0xF0, 0x10, 0xF0, #5
             0xF0, 0x80, 0xF0, 0x90, 0xF0, #6
             0xF0, 0x10, 0x20, 0x40, 0x40, #7
             0xF0, 0x90, 0xF0, 0x90, 0xF0, #8
             0xF0, 0x90, 0xF0, 0x10, 0xF0, #9
             0xF0, 0x90, 0xF0, 0x90, 0x90, #A
             0xE0, 0x90, 0xE0, 0x90, 0xE0, #B
             0xF0, 0x80, 0x80, 0x80, 0xF0, #C
             0xE0, 0x90, 0x90, 0x90, 0xE0, #D
             0xF0, 0x80, 0xF0, 0x80, 0xF0, #E
             0xF0, 0x80, 0xF0, 0x80, 0x80] #F    
             
  emu.PC = 0x200
  emu.I = 0
  emu.delayTimer = 0
  emu.soundTimer = 0
  emu.opcode = 0
  emu.vx = 0
  emu.vy = 0
  emu.draw = false
  emu.V = newSeq[int](16)
  emu.keys = newSeq[int](16)
  emu.stack = newSeq[int](16)
  emu.memory = newSeq[int](memorySize)
  emu.display = newSeq[int](dispSize)

  emu.surface = graphics.newScreenSurface(640, 320)
  emu.memory[0..fontSet.len] = fontSet
  
  # table will hold instructions
  var fnmap = initTable[int, proc()]()

  # start the instructions set
  fnmap[0x0000] = proc() =
    var op = emu.opcode and 0xf0ff
    fnmap[op]()
  fnmap[0x00e0] = proc() =
    emu.display = newSeq[int](dispSize)
    emu.draw = true
  fnmap[0x00ee] = proc() =
    emu.PC = emu.stack.pop()
  fnmap[0x1000] = proc() =
    emu.PC = emu.opcode and 0x0fff
  fnmap[0x2000] = proc() =
    emu.stack.add(emu.PC)
    emu.PC = emu.opcode and 0x0fff
  fnmap[0x3000] = proc() =
    if emu.V[emu.vx] == (emu.opcode and 0x00ff):
      emu.PC += 2
  fnmap[0x4000] = proc() =
    if emu.V[emu.vx] != (emu.opcode and 0x00ff):
      emu.PC += 2
  fnmap[0x5000] = proc() =
    if emu.V[emu.vx] == emu.V[emu.vy]:
      emu.PC += 2
  fnmap[0x6000] = proc() =
    emu.V[emu.vx] = emu.opcode and 0x00ff
  fnmap[0x7000] = proc() =
    emu.V[emu.vx] += emu.opcode and 0xff
  fnmap[0x8000] = proc() =
    var op = emu.opcode and 0xf00f
    op += 0xff0
    fnmap[op]()
  fnmap[0x8FF0] = proc() =
    emu.V[emu.vx] = emu.V[emu.vy]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FF1] = proc() =
    emu.V[emu.vx] |= emu.V[emu.vy]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FF2] = proc() =
    emu.V[emu.vx] &= emu.V[emu.vy]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FF3] = proc() =
    emu.V[emu.vx] ^= emu.V[emu.vy]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FF4] = proc() =
    if emu.V[emu.vx] + emu.V[emu.vy] > 0xff: emu.V[0xf] = 1
    else: emu.V[0xf] = 0
    emu.V[emu.vx] += emu.V[emu.vy]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FF5] = proc() =
    if emu.V[emu.vy] > emu.V[emu.vx]: emu.V[0xf] = 0
    else: emu.V[0xf] = 1
    emu.V[emu.vx] = emu.V[emu.vx] - emu.V[emu.vy]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FF6] = proc() =
    emu.V[0xf] = emu.V[emu.vx] and 0x0001
    emu.V[emu.vx] = emu.V[emu.vx] shr 1
  fnmap[0x8FF7] = proc() =
    if emu.V[emu.vx] > emu.V[emu.vy]: emu.V[0xf] = 0
    else: emu.V[0xf] = 1
    emu.V[emu.vx] = emu.V[emu.vy] - emu.V[emu.vx]
    emu.V[emu.vx] &= 0xff
  fnmap[0x8FFE] = proc() =
    emu.V[0xf] = (emu.V[emu.vx] and 0x00f0) shr 7
    emu.V[emu.vx] = emu.V[emu.vx] shl 1
    emu.V[emu.vx] &= 0xff
  fnmap[0x9000] = proc() =
    if emu.V[emu.vx] != emu.V[emu.vy]:
      emu.PC += 2
  fnmap[0xA000] = proc() =
    emu.I = emu.opcode and 0x0fff
  fnmap[0xB000] = proc() =
    emu.PC = (emu.opcode and 0x0fff) + emu.V[0]
  fnmap[0xC000] = proc() =
    var rnd = int(random(1.0) * 0xff)
    emu.V[emu.vx] = rnd and (emu.opcode and 0x00ff)
    emu.V[emu.vx] &= 0xff
  fnmap[0xD000] = proc() =
    emu.V[0xf] = 0
    var
      x = emu.V[emu.vx] and 0xff
      y = emu.V[emu.vy] and 0xff
      height = emu.opcode and 0x000f
      row = 0
    while row < height:
      var 
        curr_row = emu.memory[row + emu.I]
        pixel_offset = 0
      while pixel_offset < 8:
        var loc = x + pixel_offset + ((y + row) * 64)
        pixel_offset += 1
        if (y + row) >= 32 or (x + pixel_offset - 1) >= 64:
          continue
        var 
          mask = 1 shl (8 - pixel_offset)
          curr_pixel = (curr_row and mask) shr (8 - pixel_offset)
        emu.display[loc] ^= curr_pixel
        if emu.display[loc] == 0:
          emu.V[0xf] = 1
        else:
          emu.V[0xf] = 0
      row += 1
    emu.draw = true
  fnmap[0xE000] = proc() = 
    var op = emu.opcode and 0xf00f
    fnmap[op]()
  fnmap[0xE00E] = proc() =
    var key = emu.V[emu.vx] and 0xf
    if emu.keys[key] == 1:
      emu.PC += 2
  fnmap[0xE001] = proc() =
    var key = emu.V[emu.vx] and 0xf
    if emu.keys[key] == 0:
      emu.PC += 2
  fnmap[0xF000] = proc() =
    var op = emu.opcode and 0xf0ff
    fnmap[op]()
  fnmap[0xF007] = proc() =
    emu.V[emu.vx] = emu.delayTimer
  fnmap[0xF00A] = proc() =
    var ret = 0
    if ret >= 0:
      emu.V[emu.vx] = ret
    else:
      emu.PC -= 2
  fnmap[0xF015] = proc() =
    emu.delayTimer = emu.V[emu.vx]
  fnmap[0xF018] = proc() =
    emu.soundTimer = emu.V[emu.vx]
  fnmap[0xF01E] = proc() =
    emu.I += emu.V[emu.vx]
    if emu.I > 0xfff:
      emu.V[0xf] = 1
      emu.I &= 0xfff
    else:
      emu.V[0xf] = 0
  fnmap[0xF029] = proc() =
    emu.I = (5*(emu.V[emu.vx])) and 0xfff
  fnmap[0xF033] = proc() =
    emu.memory[emu.I]   = int(emu.V[emu.vx] / 100)
    emu.memory[emu.I+1] = int((emu.V[emu.vx] mod 100) / 10)
    emu.memory[emu.I+2] = emu.V[emu.vx] mod 10
  fnmap[0xF055] = proc() =
    for i in 0..emu.vx:
      emu.memory[emu.I + i] = emu.V[i]
    emu.I += (emu.vx) + 1
  fnmap[0xF065] = proc() =
    for i in 0..emu.vx:
      emu.V[i] = emu.memory[emu.I + i]
    emu.I += (emu.vx) + 1
  emu.fnmap = fnmap
  return emu
    
proc loadROM(emu: var PEmu, path = "./roms/PONG") =
  var f = open(path)
  var ar = newSeq[int8](maxRomSize)
  var size = f.readBytes(ar, 0, maxRomSize)
  for i, b in ar[0..size]:
    emu.memory[0x200 + i] = int(uint8(b))
  close(f)

proc cycle(emu: var PEmu) =
  for t in 0..10:
    emu.opcode = ((emu.memory[emu.PC] shl 8) or (emu.memory[emu.PC + 1]))
    emu.PC += 2
    emu.vx = (emu.opcode and 0x0f00) shr 8
    emu.vy = (emu.opcode and 0x00f0) shr 4
    emu.fnmap[emu.opcode and 0xf000]()
    if emu.soundTimer > 0: emu.soundTimer-= 1
    if emu.delayTimer > 0: emu.delayTimer-= 1


proc updateScreen(emu: var PEmu) =
  var 
    surface = emu.surface

  discard sdl.FillRect(surface.s, nil, 0)
  if sdl.MustLock(surface.s):
    discard sdl.LockSurface(surface.s)

  for i in 0.. <2048:
    if emu.display[i] == 1:
      graphics.FillRect(surface, ((i mod 64) * 10, (int(i/64) * 10), 10, 10), colWhite)

  if sdl.MustLock(surface.s):
    sdl.UnlockSurface(surface.s)    
  sdl.UpdateRect(surface.s, 0, 0, 0, 0);

  emu.draw = false
