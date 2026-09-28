# Firmware Builder — Future Upgrades Roadmap

Status: **planning only, nothing in this document has been started.**
Last updated: 2026-09-10.

This is the forward-looking roadmap for the Firmware Builder (board detection,
axis/module configuration, in-app compile + flash). It picks up after the
Modules/Plugins/Accessories initiative, which shipped 18 real, verified
accessory modules across uCNC and grblHAL (see git history / commit messages
for that work — this doc only covers what's *next*).

## Baseline: what already works today

Before planning upgrades, it's worth being precise about what's already real,
so the roadmap below only lists genuine gaps:

- **In-app compile and flash already exists.** `TFirmwareBuilderFrame` has a
  real Build button (`BtnBuildClick`, runs `pio run -e <env>`) and Upload
  button (`pio run -e <env> -t upload --upload-port <port>`), both via
  `TProcessRunner`, using the real `pio` binary at `~/.local/bin/pio`. This is
  the exact binary used to verify every feature built so far — it is not a
  mock or a "looks plausible" placeholder.
- **Board selection, axis configuration, and 18 accessory modules** (I2C LCD,
  encoders, relays, shift registers, MCP23017, EEPROM/FRAM, BLTouch, SD card,
  Bluetooth, Trinamic silent drivers, Modbus/VFD, Ethernet) already work
  end-to-end for uCNC and for grblHAL's stm32f1xx/stm32f4xx/esp32 driver
  families — each verified via a real `pio run`, and for grblHAL specifically
  cross-checked with Flash-size or byte-diff comparisons against stock builds.
- So the "pick options, compile, and use it" loop the user wants **already
  exists** for every board currently supported. The gaps below are about
  *which boards/MCUs/configurations* that loop can reach, not whether the
  loop itself exists.

## Item 1 — uCNC RP2040 support (recommended first step)

**Effort: small. Reuses 100% of existing infrastructure.**

- `References/uCNC/uCNC/src/hal/boards/rp2040/rp2040.ini` is real and
  **PlatformIO-based** (arduino-pico framework via
  `platform = https://github.com/maxgerhardt/platform-raspberrypi.git`,
  `board_build.core = earlephilhower`) — the exact same toolchain (`pio`)
  already driven for every other uCNC board.
- First step is simply confirming `ScanUCNCEnvironments` already discovers
  it (it scans `uCNC/src/hal/boards/*/*.ini` generically, so it may already
  appear in the board list, untested as of this writing). If not, that's a
  small, low-risk fix — not a new backend.
- Once discovered, the existing generic DIN/DOUT pin-family module system and
  axis-slot activation (already supports enabling only 2 of N axes) should
  apply with no new mechanism:
  - Display → `fmUCNCi2cLcd` (I2C LCD), already built.
  - MCP23017 → **not yet available for uCNC** (today it's grblHAL-only,
    `fmGrblHALMcp23017`). Would need a small new uCNC module added,
    following the exact same pattern as every other uCNC addon module this
    session (check `References/uCNC-modules/` for a real MCP23017 module
    before assuming one exists).
- As always: verify via a real `pio run`, not assumed to work just because
  the `.ini` looks compatible.

## Item 2 — grblHAL RP2040 support (bigger lift — different build backend)

**Effort: large. Introduces a genuinely new build backend, not just a new board.**

- `References/grblHAL-driver-rp2040/` is real and has real boards
  (`btt_skr_pico_10`, `pico_cnc`, `generic_map.h` /
  `generic_map_4axis.h` / `generic_map_8axis.h`, MCP23017-capable via
  `USE_EXPANDERS`) — but it **builds via `CMakeLists.txt` +
  `pico_sdk_import.cmake` (the Raspberry Pi Pico SDK), not PlatformIO**. No
  `platformio.ini` exists anywhere in that repo.
- This machine currently has **no `cmake`, no `ninja`, and no
  arm-none-eabi toolchain installed** (none on `PATH`, nothing installed via
  `dpkg` as of this writing). PlatformIO manages its own per-platform
  toolchains internally, which is why nothing extra was ever needed for any
  board built so far — a CMake/Pico-SDK path needs its own, separate
  toolchain setup, unrelated to `pio`.
- Two real options if this is ever pursued:
  1. **Native CMake backend**: install `cmake` / `ninja` /
     `arm-none-eabi-gcc`, fetch `pico-sdk`, and add a second
     `TProcessRunner`-driven build path (`cmake -B build -G Ninja && ninja`
     instead of `pio run`) specific to this one driver family. Correct, but
     a genuinely separate "how do I build this" code path.
  2. **Run it under PlatformIO's RP2040 platforms instead** (the same
     `maxgerhardt/platform-raspberrypi` + arduino-pico core uCNC's own
     `rp2040.ini` already uses). This is speculative — grblHAL's RP2040
     driver was written directly against Pico SDK APIs (not the Arduino
     framework), so porting it to build under arduino-pico would likely
     need real upstream changes or a compatibility shim, not just a
     `platformio.ini` written on our side. Needs real investigation before
     committing to it.
- Only worth picking up when there's a concrete need for a board that only
  grblHAL's RP2040 driver supports — Item 1 (uCNC + RP2040 + PlatformIO)
  likely covers most real "RP2040 CNC controller" use cases already.

## Item 3 — Arduino IDE / arduino-cli — realistic role

- Neither uCNC nor grblHAL's currently-buildable driver families need
  Arduino IDE or `arduino-cli` today — everything is PlatformIO-native.
- The two Arduino IDE GUI apps (1.8.19, 2.3.10) add nothing this tool could
  call into programmatically — they aren't built for CLI automation the way
  `pio` / `arduino-cli` are, so there's no reason to extract or wire those up.
- `arduino-cli` **is** scriptable the same way `pio` is
  (`arduino-cli compile --fqbn ...`, `arduino-cli upload ...`), so it's a
  real candidate as a **second build backend** for some future board whose
  only working build path is an Arduino sketch + board-manager core with no
  PlatformIO platform at all (some ESP8266/ESP32 variants, some AVR
  variants, certain hobbyist boards). It is **not** needed for RP2040
  specifically — grblHAL's RP2040 driver isn't an Arduino sketch (see Item
  2), and uCNC's RP2040 board is already reachable via `pio` (Item 1).
- `arduino-cli` 1.5.1 has been extracted to `tools/arduino-cli/` in this repo
  (gitignored, same treatment as `References/`) — "just in case," per the
  user's request, not yet wired into any build path. If a real board is
  found that needs it, add a second backend enum (e.g. `fbPlatformIO` /
  `fbArduinoCli`) to whatever build-invocation code exists at that point,
  pointing at `tools/arduino-cli/arduino-cli`.

## Item 4 — the real "custom board" feature: a from-scratch pin editor

**Biggest item. Most directly answers "make a custom board." Not yet scoped in detail — deserves its own planning pass when picked up.**

- Everything built so far — this whole accessory-module initiative, and the
  board-detection/dual-drive work before it — operates on **existing, named
  board map files already inside the cloned repos**. You pick a board, the
  tool auto-picks free pins within that board's own declared layout. There
  is still no way to start from a **blank MCU** and assign your own
  arbitrary GPIO numbers to STEP/DIR/LIMIT/axes/modules.
- This is the feature that most fully answers "build a custom board" (as
  opposed to "add another existing board to the list") — directly relevant
  for bespoke/breadboard builds (RP2040 or otherwise) where no existing
  board map matches.
- Real scope: a pin-assignment UI (per-axis STEP/DIR/LIMIT GPIO pickers,
  module pin pickers) that writes a brand-new board map file from a blank
  template, rather than editing an existing one. Both ecosystems already
  have generic starting templates to build from (e.g. grblHAL RP2040's own
  `generic_map.h` / `generic_map_4axis.h`).
- Should get its own dedicated planning session when picked up, rather than
  being scoped further here.

## Item 5 — a "universal pendant" (jog/MPG controller box)

User asked (2026-09-10): could this tool build its own universal pendant
board? There turn out to be **three genuinely different real answers already
present in the reference source**, not one — worth distinguishing clearly
before picking one:

### 5a. Wired pendant on the CNC controller's own spare GPIOs — cheapest, mostly already built

A jog wheel + a handful of buttons (feed hold / cycle start / axis select /
E-stop) wired directly to spare pins on the *same* board that runs the CNC
firmware. This is already almost entirely covered by modules built this
session:
- Jog wheel → `fmUCNCEncoder` / `fmGrblHALEncoder` (already built, both
  ecosystems).
- Buttons → `fmGrblHALKeypad` (grblHAL, UART mode) or uCNC's own
  `uCNC-modules/grblhal_keypad` (present in `References/uCNC-modules/`, not
  yet wired into this tool — real, un-verified gap, would follow the exact
  same LOAD_MODULE pattern as every other uCNC addon module).
- Feed-hold/cycle-start/E-stop → already reported (read-only) via the
  control-switch detection built in the original Firmware Builder phase.
- **Limitation**: this makes the pendant *part of* the CNC controller
  board — fine for a fixed control panel, not for a handheld box on a
  cable, since the buttons/wheel are wired directly to the same MCU running
  the motion planner.

### 5b. grblHAL's real MPG interface (`MPG_ENABLE`) — the "proper" detachable pendant architecture

- `MPG_ENABLE` (1 or 2) is real, documented, and used
  (`grblHAL-core/driver_opts2.h`, `pin_bits_masks.h`): "Enable MPG interface.
  Requires a serial stream and means to switch between normal and MPG mode."
  Mode 1 uses a dedicated serial port + a physical mode-switch pin
  (`MPG_MODE_PIN` — confirmed real and required: `#if MPG_ENABLE == 1 &&
  !defined(MPG_MODE_PIN) #error "MPG_MODE_PIN must be defined!" #endif`).
  Mode 2 shares the primary I/O stream instead (simpler, not yet checked in
  detail).
- 6 real boards across stm32f4xx/stm32f1xx already declare `MPG_MODE_PIN`
  (`st_morpho_map.h`, `longboard32_map.h`, `mks_robin_nano_v3.0_map.h`,
  `stm32f407vet6_dev_board.h`, `flexi_hal_map.h`, `mach3_bob_map.h`) — real
  hardware support already exists to gate a future `fmGrblHALMpg` module on,
  following the exact same "only offer where the board declares the pin"
  discipline used for every other module this session.
- **This only covers the controller side.** The pendant *device* itself (a
  separate box with its own MCU, wheel, buttons, connected over the second
  serial port) needs its own, genuinely separate firmware — not grblHAL or
  uCNC, just something that reads the wheel/buttons and writes standard
  GRBL realtime/jog bytes (`?`, `!`, `~`, `$J=...`) out a UART. This is
  small, real, new scope — a natural fit for a lightweight AVR/RP2040
  sketch, and exactly the kind of board `arduino-cli` (staged in
  `tools/arduino-cli/`, see Item 3) could become a second build backend
  for, if/when this is picked up. uCNC has no equivalent to grblHAL's
  `MPG_ENABLE` — not found in a search of `uCNC/src`.

### 5c. uCNC's `web_pendant` — arguably the most "universal" pendant of all: your phone

- `References/uCNC-modules/web_pendant/` is real: a touchscreen-optimized
  web UI (`index.html.gz`) served directly by the CNC controller over its
  own WiFi — its own README states it's "direcly usable in 3.2 inches touch
  screens" and works on any WiFi-capable uCNC MCU (ESP32/ESP8266). No
  separate pendant hardware or firmware needed at all — any phone, tablet,
  or cheap touchscreen browser becomes the pendant.
- **Real, different integration mechanics than any module built so far**:
  the README's own steps require building a filesystem image (LittleFS/
  SPIFFS) containing `index.html.gz` and uploading it separately (typically
  `pio run -t uploadfs`) — today's `TFirmwareBuilderFrame` only drives
  `pio run` (build) and `pio run -t upload` (firmware flash), not a
  filesystem-image build/upload step. Real, scoped, but new capability
  needed in the Build/Upload UI before this module could be offered.
- Would also need confirming a WiFi-capable uCNC board (ESP32/ESP8266) is
  actually discoverable via `ScanUCNCEnvironments` today — not yet checked.

**Recommendation if this is picked up**: start with 5a (cheapest, reuses
everything, good for a fixed control panel), evaluate 5c next (uniquely
"universal" — no pendant hardware to build at all, just real new
build-mechanics work), and treat 5b as the "proper detachable hardware
pendant" path once there's a concrete reason to build a standalone box
rather than use a phone.

## Item 6 — a coil winder controller

Real, grounded finding: **coil winding is mathematically the same problem as
lathe thread-cutting** (a linear traverse axis whose position is locked to
spindle rotation angle, at a fixed pitch — wire-width-per-turn instead of
thread-pitch) — and grblHAL already has real, working support for exactly
that:

- `SPINDLE_SYNC_ENABLE` (`grblHAL-core/config.h`) enables G33 (spindle-
  synchronized motion) and G76 (threading canned cycle). Confirmed
  non-vestigial by real usage in `stepper.c` (4 references) and
  `settings.c`, plus a real `hal.driver_cap.spindle_sync` check in
  `report.c` — this is not a documented-but-dead option like the earlier
  `DISPLAY_ENABLE`/`BLTOUCH_ENABLE` findings.
- Its own doc comment is explicit about the prerequisite: "require driver
  and board support for spindle encoder input" — i.e. a real quadrature
  encoder with an index pulse mounted on the spindle shaft, not just any
  encoder. **8 real stm32f4xx boards already wire `SPINDLE_INDEX_PIN` and
  `SPINDLE_PULSE_PIN`**: `blackpill_map.h`, `blackpill_alt2_map.h`,
  `longboard32_map.h`, `st_morpho_map.h`, `Devtronic_CNC_Controller_map.h`,
  `protoneer_3.xx_map.h`, `Devtronic_CNC_Controller_V2_map.h`,
  `stm32f407vet6_dev_board.h`.
- **A real, un-investigated nuance found while checking this**:
  `driver_opts.h` has `#if SPINDLE_SYNC_ENABLE && !(SPINDLE_ENABLE & (1 <<
  SPINDLE_STEPPER))`, suggesting spindle-sync may also need the spindle
  configured in "stepper" mode (a spindle driven as a controlled axis, not
  just PWM speed control) rather than being a simple additive define like
  Bluetooth or MCP23017 were. This needs real investigation — reading
  `driver_opts.h` around that line in full, and a real `pio` compile
  attempt — before treating a future `fmGrblHALSpindleSync` module as
  "just one define," the same discipline every other module in this
  project has been held to.
- **uCNC has no equivalent** — a real search of `uCNC/src/core` for G33/G76/
  threading/spindle-sync found nothing. This would be grblHAL-only, same
  situation as Ethernet and Bluetooth.
- A dedicated coil-winder *controller* (as opposed to just "a grblHAL board
  with spindle sync turned on") would likely also want: a 2-axis minimum
  config (spindle "axis" via G33 + one real linear traverse axis — already
  fully supported by existing axis-slot selection), and possibly a simpler
  G-code/macro layer on the sender (Lazarus app) side for "wind N turns at
  pitch P" — that's app-side scope, not firmware-side, and out of this
  roadmap's frame.

## Item 7 — a camera slider controller (incl. pan/tilt)

**Good news: this needs no new firmware-side work at all.** A camera slider
is, mechanically, a 1–2 axis GRBL/uCNC machine (linear traverse, optionally
pan/tilt) with no spindle — already fully within what the Firmware Builder
generates today: pick a board, activate only the axes actually wired (the
axis-slot selection already supports enabling a subset), skip
spindle-related modules entirely. No new module or board work is implied by
"camera slider" as a *firmware* problem.

The only genuinely new-hardware angle is **fully bespoke/breadboard slider
electronics that don't match any existing board map file** (e.g. a hand-
wired RP2040 + a couple of stepper drivers on a custom PCB) — that's not a
slider-specific gap, it's the same general gap as Item 4 (the from-scratch
pin editor). Once Item 4 exists, it covers camera sliders, coil winders, and
any other bespoke motion-control box equally, not just "CNC mills."

### 7a. Pan/tilt slider (rail + pan + tilt, 3 axes)

User asked (2026-09-10): can this be a rail slider with pan/tilt, plus a
manual controller? Yes — it's a 3-axis machine (1 linear rail axis + 2
rotational pan/tilt axes), still within already-supported axis-slot
selection, no spindle. Two real caveats worth checking before assuming it
"just works" the same way a mill's X/Y/Z does, not yet investigated in
source:

- **Continuous pan rotation** (spinning past 360°, no hard end-stops) is a
  genuinely different case than the homed, limit-switch-bounded axes this
  tool assumes by default for every other axis built so far — needs
  checking grblHAL/uCNC's soft-limits and homing config specifically for an
  unbounded rotational axis before assuming default axis setup covers it.
- **Motion smoothness for video** matters more here than for cutting —
  grblHAL's planner is smoother than plain GRBL, which helps, but
  acceleration/jerk tuning for smooth camera moves is its own real tuning
  pass, not just "enable the axis."
- **Manual controller**: any of Item 5's three options apply, but 5c (uCNC's
  `web_pendant`, your phone as the controller) is a particularly good fit
  for camera work specifically — framing the shot live from the same screen
  used to jog, rather than a separate box.

## Suggested order

1. **uCNC RP2040** (Item 1) — smallest, reuses everything proven.
2. **Generic pin editor / real custom-board support** (Item 4) — the actual
   "build a custom board" feature; most valuable long-term, most work, and
   the same underlying gap behind bespoke pendant/coil-winder/slider
   electronics (Items 5–7) that don't match an existing board file.
3. **Wired pendant modules** (Item 5a: uCNC keypad module +
   `fmGrblHALMpg`/`fmGrblHALSpindleSync` style board-gated modules,
   following the established module pattern) — cheap, reuses proven
   infrastructure, real hardware already exists on several boards to gate
   on.
4. **uCNC `web_pendant`** (Item 5c) — needs new filesystem-image build/
   upload capability in the Build/Upload UI first; otherwise no pendant
   hardware to build at all.
5. **grblHAL spindle sync / coil winder support** (Item 6) — needs the
   `SPINDLE_ENABLE`/`SPINDLE_STEPPER` nuance investigated for real before
   committing to "just a define."
6. **grblHAL RP2040 CMake backend** (Item 2) — only if a specific board
   needs grblHAL specifically on RP2040.
7. **arduino-cli backend** (Item 3) — only if a specific future board (or a
   standalone MPG pendant device, Item 5b) has no PlatformIO path at all.

Nothing here has been started. Revisit when there's a concrete board or
feature from this list to actually work on.
