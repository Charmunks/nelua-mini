# Nelua-Mini Development Guide

## Project Overview

Nelua-Mini is a library and toolchain for developing Pokemon Mini homebrew using the Nelua programming language. It targets the Epson S1C88 8-bit CPU via the TASKING E0C88 compiler toolchain (cc88, as88, lk88, lc88).

## Build Commands

```powershell
# From an example directory (e.g., examples\demo):
.\build.ps1                 # Build ROM (default: all)
.\build.ps1 run             # Build and run in emulator

# From project root with explicit source:
.\tools\build.ps1 -Source examples\demo\main.nelua
.\tools\build.ps1 run -Source examples\demo\main.nelua
.\tools\build.ps1 clean     # Clean build artifacts
.\tools\build.ps1 rebuild   # Clean and rebuild
```

Output ROM: `build\<name>.min`

## Project Structure

```
src/              Library source (Nelua)
  pmhw.nelua      Hardware abstraction layer
examples/demo/    Example application
  main.nelua      Demo game entry point
tools/            Build tooling (PowerShell)
  build.ps1       Main build script
  c99_to_c89.ps1  C99 to C89 converter for TASKING cc88
toolchain/        TASKING toolchain configuration
  crt0.asm        Startup assembly (interrupt vectors, ROM header)
  pokemini.dsc    Software description file
  s1c88_pokemini.cpu  CPU description file
  s1c88.mem       Memory description file
neluacfg.lua      Nelua compiler configuration
```

## Build Pipeline

1. `nelua` compiles `.nelua` sources to C99
2. `c99_to_c89.ps1` converts C99 to C89 (TASKING cc88 only supports C89)
3. `as88` assembles `crt0.asm`
4. `cc88` compiles the C89 code
5. `lk88` links objects with runtime library
6. `lc88` locates code at correct memory addresses
7. `srec_cat` converts S-record output to binary `.min` ROM

## Key Constraints

- **No garbage collector**: `pragma{nogc = true}` is required in all Nelua files.
- **No runtime checks**: `pragma{nochecks = true}` to minimize code size.
- **No static initializers**: The `__copytable` function is stubbed out in crt0.asm. All data must be initialized at runtime (use `<comptime>` for constants, init functions for arrays).
- **C89 only**: Nelua generates C99 but cc88 requires C89. The converter handles for-loop declarations, mid-block declarations, designated initializers, compound literals, and bool/true/false.
- **16-bit int, 32-bit long**: The S1C88 uses 16-bit `int` and 32-bit `long`. stdint types are typedef'd in the converter output.
- **Hardware registers**: Access via comptime addresses cast to pointers. See `src/pmhw.nelua` for the pattern.

## Code Style

- Use camelCase for local variables and functions.
- Use UPPER_CASE for constants and hardware register names.
- Use `<comptime>` for all compile-time constants to avoid static initializer dependencies.
- Use `<inline>` for small hardware accessor functions.
- Use `<noinline>` sparingly for functions that must not be inlined (e.g., `init_hw`).
- Mark pure functions with `<nosideeffect>`.
- All Nelua files must start with `## pragma{nogc = true, nochecks = true}`.

## Hardware Notes

- Screen: 96x64 pixels, 1bpp, stored in GDDRAM at 0x1000 (768 bytes).
- Framebuffer layout: column-major, 8 pixels per byte (LSB = top pixel).
- Input: Read from KEY_PAD register (0x2052), active low (invert to get pressed state).
- VSync: Poll IRQ_ACT1 bit 7 for PRC frame complete.

## Prerequisites

- TASKING E0C88 toolchain installed via [c88-pokemini](https://github.com/pokemon-mini/c88-pokemini)
- Nelua compiler
- PokeMini emulator (for testing)
