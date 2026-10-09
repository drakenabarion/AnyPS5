# AnyPS5: Quake (PPSA01881) on Linux

This fork contains an unofficial Linux build of [AnyPS5](https://github.com/boykopovar/AnyPS5) that runs **Quake (PPSA01881)** from your own PS5 dump. It is made and tested for Quake only.

**[Download the AppImage (latest release)](https://github.com/drakenabarion/AnyPS5/releases/latest)**: make it executable, double-click it, and choose your Quake folder (the one containing `eboot.bin`). No game files are included; you need your own, legally obtained dump.

- Requirements: 64-bit Linux with glibc 2.38 or newer, and a Vulkan GPU driver. Tested on NVIDIA (proprietary driver) and on the Steam Deck (AMD, RADV).
- Controls: game controllers through SDL. Fullscreen: F11 or LB + RB + L3 + R3. Quit: hold LB + RB + Start + Select, or hold Guide/PS for 1.5 seconds.
- Online features (Bethesda.net, multiplayer) do not work.

This branch (`quake-0.2`) is upstream AnyPS5 plus the changes Quake needed: graphics driver fixes (draw-time shader preparation, depth, presentation timing), audio (panning, stable playback of queued sound), shutdown and quit handling, controller shortcuts, fullscreen, and the AppImage launcher. Release `v0.2.0-quake` is built from commit `59b72c5b`. Fixes that are useful beyond Quake are being offered upstream.

All credit for AnyPS5 itself goes to boykopovar and the AnyPS5 contributors. Not affiliated with or endorsed by Sony Interactive Entertainment, Bethesda, id Software or the AnyPS5 project.

The original AnyPS5 README follows.

---

# About

Tool for automatic executables porting to Linux and Windows.

Includes a [relinker](core/relinker) that converts executable to the target system's native format and implementations of [system prx libraries](core/libs/prx) suitable for dynamic linking. No emulation or separate runtime process.

[Usage](docs/user/USAGE.md), [Build instructions](docs/dev/BUILD.md), [Architecture](docs/dev/ARCHITECTURE.md), [Technical debt of the project](docs/dev/TechnicalDebt.md), [code style conventions](docs/dev/CONVENTIONS.md), [contributing](CONTRIBUTING.md)

## Status

[![libraries](https://boykopovar.github.io/AnyPS5/badge-libraries.svg)](https://boykopovar.github.io/AnyPS5/) [![shaders](https://boykopovar.github.io/AnyPS5/badge-shaders.svg)](https://boykopovar.github.io/AnyPS5/)

[![progress map](https://boykopovar.github.io/AnyPS5/progress.svg)](https://boykopovar.github.io/AnyPS5/)

<sub>* System libraries: percentage of the functions known to the project so far (declared in [core/libs/prx](core/libs/prx)), not of every PS5 system function. The total grows as more functions are declared.</sub>

[List of verified games](docs/user/COMPATIBILITY.md)

Dreaming Sarah (2D platformer) runs at a stable 60 fps on a GTX 1050 Ti / i5-7500 3.4GHz.

Unsupported or unexpected states strictly throw `std::runtime_error`. `what()` is printed to stderr and the process terminates.

The [shader recompiler](core/shader/recompiler/Recompiler.cpp) successfully produces SPIR-V (validated via [Spirv-Tools](3rdparty/SPIRV-Tools) when built with `ANYPS5_ENABLE_SPIRV_TOOLS`).

## Compatibility

See the [game compatibility list](docs/user/COMPATIBILITY.md) for tested games and known issues.

## Input mapping

SDL-mapped game controllers are supported, including analog sticks and triggers. Keyboard and mouse controls can be configured with an `anyps5-input.ini` file. See [input mapping](docs/user/INPUT_MAPPING.md) for the supported devices and configuration format.

## Disclaimer

This project is intended for interoperability, research, preservation, and compatibility purposes. It does not include, distribute, or require copyrighted software, firmware, cryptographic keys, or proprietary libraries. Users are responsible for ensuring that any binaries used with this project are obtained and used in accordance with applicable laws and their respective license terms.

## License

This project is licensed under the GNU General Public License version 2 only.
