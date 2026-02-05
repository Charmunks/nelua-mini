# Nelua-Mini

A library for developing Pokemon Mini homebrew in [Nelua](https://nelua.io/), targeting the Epson S1C88 8-bit CPU. Nelua source compiles to C89 via an intermediate conversion step, then builds into a `.min` ROM using the TASKING E0C88 toolchain.

## Prerequisites

- **TASKING E0C88 Toolchain** -- Install via [c88-pokemini](https://github.com/pokemon-mini/c88-pokemini):
  ```powershell
  cd C:\Users\isaac\c88-pokemini
  .\install.ps1
  ```
- **Nelua** -- [nelua.io](https://nelua.io/)
- **PokeMini Emulator** -- For testing ROMs

## Getting Started

Build and run an example from its directory:

```powershell
cd examples\demo
.\build.ps1                  # Build ROM
.\build.ps1 run              # Build and run in emulator
```

Or build any source file directly from the project root:

```powershell
.\tools\build.ps1 -Source examples\demo\main.nelua
.\tools\build.ps1 run -Source examples\sqaure\main.nelua
```

The output ROM is written to `build\<name>.min`.

Build targets:

| Target | Description |
|--------|-------------|
| `all` | Full build (default) |
| `run` | Build and launch in emulator |
| `clean` | Remove build artifacts |
| `rebuild` | Clean, then full build |

## Project Structure

```
src/
  pmhw.nelua              Hardware abstraction layer (the library)
examples/
  demo/
    main.nelua             Example application
tools/
  build.ps1               Build script
  c99_to_c89.ps1          C99 to C89 converter for TASKING cc88
toolchain/
  crt0.asm                Startup assembly (vectors, ROM header)
  pokemini.dsc            TASKING software description
  s1c88_pokemini.cpu      TASKING CPU description
  s1c88.mem               TASKING memory description
neluacfg.lua              Nelua compiler configuration
```

## Build Pipeline

The build process chains several tools:

1. **nelua** -- Compile Nelua source to C99
2. **c99_to_c89.ps1** -- Convert C99 to C89 (TASKING cc88 only supports C89)
3. **as88** -- Assemble startup code (`crt0.asm`)
4. **cc88** -- Compile C89 to object files
5. **lk88** -- Link objects with the TASKING runtime library
6. **lc88** -- Locate code/data at target memory addresses
7. **srec_cat** -- Convert S-record output to binary ROM

## Library Usage

The hardware abstraction layer (`src/pmhw.nelua`) provides:

### Display

| Function | Description |
|----------|-------------|
| `init_hw()` | Initialize hardware (clock, PRC, framebuffer) |
| `clear_screen()` | Clear the framebuffer |
| `fill_screen(pattern)` | Fill framebuffer with a byte pattern |
| `set_pixel(x, y, color)` | Set a single pixel (bounds-checked) |
| `get_pixel(x, y)` | Read a single pixel |
| `flip_buffer()` | Trigger LCD refresh from GDDRAM |
| `wait_vsync()` | Block until PRC frame complete |

### Drawing

| Function | Description |
|----------|-------------|
| `draw_hline(x, y, w, color)` | Horizontal line |
| `draw_vline(x, y, h, color)` | Vertical line |
| `draw_rect(x, y, w, h, color)` | Rectangle outline |
| `fill_rect(x, y, w, h, color)` | Filled rectangle |

### Input

| Function | Description |
|----------|-------------|
| `poll_input()` | Returns bitmask of pressed keys |

Key constants: `KEY_A`, `KEY_B`, `KEY_C`, `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`, `KEY_POWER`.

### Fixed-Point Math

Two fixed-point types are provided for arithmetic without floating point:

- **Fixed8_8** -- 8.8 format (8 integer bits, 8 fractional bits). Supports add, sub, mul, div, comparison.
- **Fixed12_4** -- 12.4 format (12 integer bits, 4 fractional bits). Supports add, sub, mul.

## Writing Your Own Program

Create a new `.nelua` file (or modify `examples/demo/main.nelua`):

```lua
## pragma{nogc = true, nochecks = true}

require 'pmhw'

local function main(): void <entrypoint>
  init_hw()
  clear_screen()
  fill_rect(10, 10, 20, 20, 1)

  while true do
    wait_vsync()
  end
end
```

Update the `$NeluaSource` path in `tools/build.ps1` to point to your file, then run the build.

## Development Constraints

- **No garbage collector.** All Nelua files must include `## pragma{nogc = true}`.
- **No static initializers.** The `__copytable` routine is stubbed. Initialize data at runtime.
- **C89 target.** The TASKING cc88 compiler does not support C99. The converter script handles the translation automatically.
- **16-bit int.** The S1C88 has 16-bit `int` and 32-bit `long`.

## Memory Map

| Address | Size | Description |
|---------|------|-------------|
| 0x0000--0x0FFF | 4 KB | BIOS (reserved) |
| 0x1000--0x12FF | 768 B | GDDRAM (framebuffer, 96x64 1bpp) |
| 0x1300--0x1FFF | 3.25 KB | General-purpose RAM |
| 0x2000--0x20FF | 256 B | I/O registers |
| 0x2100+ | up to 2 MB | Cartridge ROM |

## TASKING Assembler Notes

The TASKING as88 assembler uses different mnemonics than standard S1C88 documentation:

| TASKING | Standard S1C88 | Description |
|---------|---------------|-------------|
| `LD` | `MOV` | Load/move |
| `CARL` | `CALL` | Call (relative long) |
| `JRL` | `JMP` | Jump (relative long) |
| `RETE` | `RETI` | Return from interrupt |

## Resources

- [Pokemon Mini Hardware Documentation](https://www.pokemon-mini.net/documentation/)
- [S1C88 Instruction Set](https://www.pokemon-mini.net/documentation/instruction-set/)
- [c88-pokemini Toolchain](https://github.com/pokemon-mini/c88-pokemini)
- [Nelua Language](https://nelua.io/)

## License

MIT
