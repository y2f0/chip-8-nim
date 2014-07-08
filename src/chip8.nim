import graphics, sdl, tables, colors, parseopt2

when defined(macosx):
  const
      LibCocoa = "/System/Library/Frameworks/Cocoa.framework/Cocoa"
  proc NSAppLoad*():bool {.cdecl, importc: "NSApplicationLoad", dynlib: LibCocoa.}
  discard NSAppLoad()

include emu

proc main =
  var 
    maxfps = 1000/200
    nextFrame = sdl.GetTicks()
    emu = createEmu()
    filename = ""

  for kind, key, val in getopt():
    case kind:
      of cmdArgument:
        filename = key
      else: discard
  if filename.len > 0:
    emu.loadROM(filename)
  else:
    echo("Usage: chip8 [rom]")
    return
  discard sdl.FillRect(emu.surface.s, nil, 0)

  while true:
    emu.cycle()
    
    if emu.draw:
      emu.updateScreen()
    
    var event: SDL.TEvent
    while SDL.PollEvent(addr(event)) == 1:
      case event.kind:
      of SDL.QUITEV: system.quit()
      else: break 
    
main()
