unit ufirmwaremodules;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ufirmwareboards;

const
  // Same marker text ufirmwarebuildconfig.pas uses for its own override
  // block - reused here for module.c's LOAD_MODULE splice too (a different
  // file, so there's no collision; SpliceOverrideBlock is generic on
  // whatever text it's given).
  MODULE_LOAD_MARKER_START = '// === GRBL-Controller-Sender Firmware Builder overrides - regenerated on every Generate, do not hand-edit ===';
  MODULE_LOAD_MARKER_END = '// === end Firmware Builder overrides ===';

type
  // fmNone is not a real module - it exists only so TFirmwareModuleId has a
  // "nothing selected" value distinct from a real (0-based) module index.
  TFirmwareModuleId = (
    fmNone,
    fmUCNCi2cLcd,       // uCNC addon module: I2C LCD status display
    fmUCNCEncoder,      // uCNC built-in: ENCODERS>0 (module.c's own LOAD_MODULE(encoder), gated
                         // purely by cnc_hal_config.h defines - no file copy needed)
    fmGrblHALEncoder,   // grblHAL Plugin_encoder (already-vendored submodule): quadrature jog/override encoder
    fmGrblHALKeypad,    // grblHAL Plugin_keypad, UART mode (KEYPAD_ENABLE=2): I2C mode needs a board-
                         // specific strobe pin most boards don't break out, UART mode doesn't
    fmUCNCRelay,        // uCNC addon module: M62-M65 generic digital output (relay) control -
                         // takes its pin number as a GCode parameter at runtime, not a compile-time
                         // config, so this module needs no pin selection at all (see ModuleConfigLines)
    fmUCNCShiftRegisterOut, // uCNC built-in (src/modules/shift_register.c, always present - no file
                         // copy needed): IC74HC595 output shift register, giving up to 56 extra
                         // DOUT-family output pins beyond what the board's own GPIOs break out.
                         // Needs 3 real DOUT control pins (SDO/CLK/LATCH), auto-picked + activated
                         // like i2c_lcd's DIN pins (see ufirmwareboards.pas's
                         // FindFreeGenericInputSlot's APrefix='DOUT' use).
    fmGrblHALMcp23017, // grblHAL core plugin (plugins/mcp23017.c, already vendored - no file
                         // copy needed): MCP23017 I2C 16-channel GPIO expander, mode 1 (port A
                         // outputs, port B inputs). No pin config needed - uses the board's
                         // existing I2C bus, default address 0x40. Needs BOTH of the 2 real,
                         // verified WriteProjectCopy fixes below to actually take effect
                         // (StripOverrideMyMachineFlag) - unlike the shift-register/relay uCNC
                         // modules, grblHAL's own PlatformIO packaging silently no-ops
                         // my_machine.h edits unless that flag is stripped.
    fmUCNCEeprom,       // uCNC addon module (uCNC-modules/i2c_eeprom): external I2C EEPROM/FRAM
                         // for persistent settings storage. Forces software I2C (2 auto-picked
                         // DIN pins) rather than trusting hardware-I2C availability, reusing the
                         // exact same DIN-pin resolution + DISABLE_HAL_CONFIG_PROTECTION
                         // mechanism already proven for i2c_lcd. Enable flag is
                         // ENABLE_SETTINGS_MODULES - a third, distinct flag from
                         // ENABLE_MAIN_LOOP_MODULES (i2c_lcd) and ENABLE_PARSER_MODULES (relay).
    fmGrblHALEeprom,    // grblHAL core (EEPROM_ENABLE, no plugin file needed): external I2C
                         // EEPROM/FRAM for persistent settings. Pure define, no pin config -
                         // uses the board's existing I2C bus like MCP23017.
    fmUCNCBltouch,      // uCNC addon module (uCNC-modules/bltouch): BLTouch probe support via
                         // M280 on a SERVO-family pin (default SERVO0, already active on most
                         // RAMPS-style boards - not offered on a board without it, same "no
                         // pin activation attempted" caution as control switches). Enable flag
                         // is ENABLE_IO_MODULES - a fourth distinct enable flag. NOTE:
                         // grblHAL's own BLTOUCH_ENABLE has ZERO implementation anywhere in any
                         // of our 3 buildable driver repos (confirmed via a real, empty grep) -
                         // same vestigial-template-comment pattern as the earlier DISPLAY_ENABLE
                         // finding - so there is no fmGrblHALBltouch id; offering one would
                         // silently do nothing.
    fmGrblHALSdCard,    // grblHAL core (SDCARD_ENABLE, no plugin file needed - FatFs/sdcard
                         // already real, populated submodules already in [common].lib_deps, no
                         // "curl+unzip FatFS manually" needed despite the platformio.ini
                         // comment describing that as if still required). Only offered when the
                         // board's own map file already defines SD_CS_PIN or SDCARD_SDIO -
                         // confirmed real: `#if SDCARD_ENABLE && !SDCARD_SDIO &&
                         // !defined(SD_CS_PIN) #error SD card plugin not supported! #endif` in
                         // grbl/driver_opts2.h, so offering this everywhere would fail loudly
                         // (safely) on boards that never break out an SD chip-select pin.
                         // uCNC's own equivalent module (sd_card_v2) needs subdirectory copying
                         // (fat_fs/, petit_fat_fs/) that ApplyUCNCModuleFiles doesn't support
                         // yet, plus more complex pin/enable-flag requirements than any module
                         // built so far - deliberately deferred rather than rushed.
    fmGrblHALBluetooth, // grblHAL core plugin (bluetooth/hc_05.c, already vendored, already in
                         // [common].lib_deps): HC-05 Bluetooth serial module support. Pure
                         // `BLUETOOTH_ENABLE 2` define, no pin config at all - the module's own
                         // README confirms it auto-picks "the highest numbered usable free
                         // port" at runtime and auto-configures itself, so no board-specific
                         // gating is needed here (always available once the ecosystem matches).
    fmGrblHALTrinamic,  // grblHAL core (trinamic/*, already vendored, already in
                         // [common].lib_deps): silent Trinamic stepper driver support, TMC2209
                         // (UART mode, `TRINAMIC_ENABLE 2209`) - the most common real chip in
                         // this class. Confirmed real via `grbl/driver_opts.h`: setting
                         // TRINAMIC_ENABLE=2209 auto-derives TRINAMIC_UART_ENABLE=1, and boards
                         // that support it already wire the needed UART/SPI pins conditionally
                         // on that same flag (confirmed in btt_skr_pro_v1_1_map.h) - so a single
                         // global define is genuinely sufficient, no per-motor pin config needed
                         // for grblHAL (unlike uCNC's per-stepper tmc_driver module below). Only
                         // offered where the board's own map file mentions "TRINAMIC" at all.
    fmUCNCTrinamicX,    // uCNC addon module (uCNC-modules/tmc_driver): silent Trinamic driver
                         // for STEPPER0 (the X axis primary motor) ONLY, in UART mode
                         // (STEPPER0_TMC_INTERFACE TMC_UART, driver type 2209) - the module's
                         // own header confirms it must be enabled "per stepper", a materially
                         // bigger feature (multi-axis, multi-interface-mode) than anything else
                         // built so far; this covers the single most common real case (silent
                         // X-axis driver) using the same proven DIN(RX)+DOUT(TX) auto-pick
                         // mechanism, rather than building a full per-axis picker UI. Enable
                         // flags: ENABLE_MAIN_LOOP_MODULES + ENABLE_PARSER_MODULES (for the
                         // M350/M906/etc M-codes) - two flags together, a first for this project.
    fmUCNCSdCard,       // uCNC addon module (uCNC-modules/sd_card_v2): run GCode files from an
                         // SD/MMC card via `$run`/`$ls`/`$cd`/`$sdmnt` system commands. First
                         // module needing real SUBDIRECTORY copying (fat_fs/, petit_fat_fs/) -
                         // CopySourceFilesOnly/ApplyUCNCModuleFiles extended to recurse. Real,
                         // confirmed requirement (diskio.h): `SD_CARD_INTERFACE` defaults to
                         // `SD_CARD_HW_SPI` (hardware SPI) - same class of risk as i2c_lcd's
                         // original hardware-I2C-by-default issue, so this forces
                         // `SD_CARD_INTERFACE SD_CARD_SW_SPI` and auto-picks + activates 4 real
                         // pins (3 DOUT: CLK/SDO/CS, 1 DIN: SDI) rather than trusting the
                         // module's own DOUT29/30/SPI_CS defaults. Enable flag:
                         // ENABLE_MAIN_LOOP_MODULES (the README's other two - PARSER_MODULES,
                         // SETTINGS_MODULES - are documented as optional and not needed for the
                         // core `$run`/`$ls` system commands, so left out to keep this minimal).
                         // Real, second upstream gap found via a real pio compile failure:
                         // diskio.c's mmcsd_spi_speed() references SD_CARD_SPI_DMA
                         // unconditionally, but the module only ever gives it a default inside
                         // the HW_SPI/HW_SPI2 branches - never for SW_SPI. Fixed by also
                         // defining `SD_CARD_SPI_DMA false` (semantically correct for software
                         // SPI, not just a workaround value).
    fmGrblHALModbus,    // grblHAL core (MODBUS_ENABLE 1 - auto direction, no board-specific pin
                         // needed): generic Modbus RTU support, real and auto-derived from
                         // VFD_ENABLE when a Modbus-based VFD spindle is configured, but also
                         // independently enable-able on its own. Mode 2 (explicit direction pin
                         // on an aux output) was considered but mode 1 is simpler and doesn't
                         // require picking/verifying a board-specific pin, so used as the
                         // default here.
    fmUCNCModbusVfd,    // uCNC core tool driver (src/hal/tools/tools/vfd_modbus.c, already
                         // compiled - no file copy needed, confirmed via real successful pio
                         // compile): Huanyang VFD spindle over Modbus RS485. Selected by
                         // overriding TOOL1 (`#undef TOOL1` + `#define TOOL1 vfd_modbus` - the
                         // real, confirmed mechanism from cnc_hal_config.h's own "Tool pallete"
                         // documentation: "Set TOOL1 as laser_pwm" example). Uses 2 auto-picked,
                         // real DOUT(TX)/DIN(RX) softuart pins rather than the module's own
                         // DOUT27/DIN27 defaults.
    fmGrblHALEthernet   // grblHAL core (Plugin_networking, already vendored, `_WIZCHIP_ 5500`):
                         // WIZnet W5500 Ethernet - streaming, Telnet, WebSocket. Single define,
                         // auto-derives ETHERNET_ENABLE/TELNET_ENABLE/WEBSOCKET_ENABLE (confirmed
                         // in Inc/my_machine.h). No pin config - WIZNET_CS_PORT/PIN are already
                         // board-declared where present, so only offered when the board's own map
                         // file defines WIZNET_CS_PORT (5 of 24 stm32f4xx boards, 0/9 stm32f1xx).
                         // Real dependency chain found via two real pio compile failures, not
                         // guessed (see AddNetworkingSupport in ufirmwarebuildconfig.pas): needs
                         // `-I networking/wiznet` plus the full lwIP include path set, and
                         // `networking`/`Middlewares/Third_Party/LwIP` lib_deps - none of which
                         // are in platformio.ini's [common] section by default (only its own
                         // unused [wiznet_networking] env-group has them). Defaults to DHCP
                         // (grbl/driver_opts.h's NETWORK_IPMODE default is 1 = DHCP), so no
                         // static-IP config is needed from this tool. No uCNC equivalent built
                         // this pass - uCNC's wiznet_eth module requires USE_STATIC_IP (a
                         // materially different, network-address kind of config vs. every pin-based
                         // module built so far), deliberately deferred rather than guessing at a
                         // default IP.
  );

  TFirmwareModuleIdArray = array of TFirmwareModuleId;

  TModuleInfo = record
    Id: TFirmwareModuleId;
    Ecosystem: TFirmwareEcosystem;
    DisplayName: string;
    Description: string;
    RequiresFileCopy: Boolean; // True only for uCNC addon modules (uCNC-modules/<SourceDirName>)
    SourceDirName: string;     // uCNC-modules/<SourceDirName> - also the module's LOAD_MODULE(name) name
  end;

// Fixed, real modules in scope for this pass (see the approved Firmware
// Builder plan's "Modules, Plugins & General Pin Editing" phase) - each one
// verified against real cloned source before being added here, same
// discipline as every other part of the Firmware Builder:
//   - fmUCNCi2cLcd: References/uCNC-modules/i2c_lcd/README.md's own 4-step
//     integration process (copy dir, LOAD_MODULE in module.c, define
//     ENABLE_MAIN_LOOP_MODULES - functionally equivalent to putting it in
//     cnc_hal_config.h since cnc_hal_config_helper.h #includes cnc_config.h
//     and cnc_hal_config.h back-to-back, both before anything that
//     #ifdef-checks it).
//   - fmUCNCEncoder: uCNC/src/module.c's mod_init() already unconditionally
//     contains `#if ENCODERS > 0 LOAD_MODULE(encoder); #endif` - pure
//     cnc_hal_config.h defines (ENCODERS, ENC0_PULSE, ENC0_DIR), zero file
//     copying, module.c already handles it with no changes needed.
//   - fmGrblHALEncoder / fmGrblHALKeypad: real Plugin_encoder/Plugin_keypad
//     submodules already vendored inside our 3 buildable grblHAL driver
//     repos (confirmed via .gitmodules + populated directory contents),
//     enabled purely via ENCODER_ENABLE/KEYPAD_ENABLE defines in
//     my_machine.h - no file copying needed for grblHAL at all.
//   - fmUCNCRelay: References/uCNC-modules/m62_m65/README.md's own 3-step
//     process (copy dir, LOAD_MODULE in module.c, define
//     ENABLE_PARSER_MODULES). Adds M62-M65 GCode (LinuxCNC-style generic
//     digital output control) to the parser - the pin to control is a
//     GCode parameter (`M62 P5`) chosen at run time, not compile time, so
//     unlike i2c_lcd/the built-in encoder this module needs no pin
//     selection at Generate time at all. Verified real `pio` compile
//     success (unlike the DIN-input-pin modules, DOUT pins' output macros
//     in io_hal.h are NOT gated behind DISABLE_HAL_CONFIG_PROTECTION - that
//     restriction is specific to the DIN/generic-INPUT pin family).
//     grblHAL has no equivalent module: M62-M65 is core grblHAL
//     functionality (grbl/gcode.c, unconditionally compiled), operating on
//     whatever AUXOUTPUTn pins the board declares free - no firmware
//     config needed there at all, so there's no fmGrblHALRelay id.
function GetModuleInfo(AId: TFirmwareModuleId): TModuleInfo;

// All real module ids for AEcosystem, in a fixed display order (excludes fmNone).
function ModulesForEcosystem(AEcosystem: TFirmwareEcosystem): TFirmwareModuleIdArray;

// Whether AId can actually be enabled for AEnv, checked against the real,
// as-cloned board/map file content (not a guess):
//   - fmGrblHALEncoder needs the board's own map file to already define
//     QEI_A_PORT (quadrature input pins) - confirmed only 2 of the 65 board
//     maps across our 3 buildable grblHAL repos do (st_morpho_map.h,
//     stm32f407vet6_dev_board.h, both stm32f4xx). Most boards simply don't
//     break out the needed pins, so offering this everywhere would silently
//     produce firmware that compiles but can't actually use an encoder.
//   - fmGrblHALKeypad (UART mode) is unavailable only on the one board
//     that explicitly rejects it: halcyon_v1_map.h's own
//     `#if KEYPAD_ENABLE == 2 #error "UART KEYPAD connection is not
//     supported!" #endif`. Every other board map in our 3 buildable repos
//     has no such block, so UART-mode keypad is offered by default.
//   - uCNC modules (fmUCNCi2cLcd, fmUCNCEncoder) have no such per-board
//     hardware prerequisite - i2c_lcd uses software I2C on any 2 generic
//     DIN pins, and the built-in encoder's DIN pins are user-chosen (see
//     TFirmwareSetup.EncoderPulsePin/EncoderDirPin) - so both are always
//     available once the ecosystem matches.
function ModuleAvailableForBoard(AId: TFirmwareModuleId; const AEnv: TBoardEnv): Boolean;

// The module's own #define line(s) to append to the shared override block.
// AEncPulsePin/AEncDirPin are only consulted for fmUCNCEncoder; ALcdSclPin/
// ALcdSdaPin only for fmUCNCi2cLcd; ASrSdoPin/ASrClkPin/ASrLatchPin only for
// fmUCNCShiftRegisterOut; AEepromClkPin/AEepromDataPin only for
// fmUCNCEeprom; ATmcTxPin/ATmcRxPin only for fmUCNCTrinamicX;
// ASdClkPin/ASdSdoPin/ASdSdiPin/ASdCsPin only for fmUCNCSdCard;
// AVfdTxPin/AVfdRxPin only for fmUCNCModbusVfd. All are
// real DIN/DOUT pin numbers that must already have been resolved (auto-picked
// or user-chosen) AND activated on the target board's own map file by the
// caller - i2c_lcd's own documented default pins (DIN30/DIN31) are NOT
// safely board-independent (a real `pio` compile against a real board
// where those pins are merely "available", not active, failed with
// "io0_config_input undeclared" - see ufirmwareboards.pas's
// FindFreeGenericInputSlot), so this unit never invents a default pin
// number itself.
function ModuleConfigLines(AId: TFirmwareModuleId; AEncPulsePin, AEncDirPin,
  ALcdSclPin, ALcdSdaPin, ASrSdoPin, ASrClkPin, ASrLatchPin,
  ATmcTxPin, ATmcRxPin,
  AEepromClkPin, AEepromDataPin,
  ASdClkPin, ASdSdoPin, ASdSdiPin, ASdCsPin,
  AVfdTxPin, AVfdRxPin: Integer): TStringArray;

// Copies every selected uCNC module that RequiresFileCopy from
// <AModulesRepoRoot>/<SourceDirName> (only .c/.h files - each module dir
// also has README.md/CHANGELOG.md which don't belong in the firmware
// source tree) into <ADestDir>/uCNC/src/modules/<SourceDirName>/, then
// splices `LOAD_MODULE(<name>);` calls into
// <ADestDir>/uCNC/src/module.c's load_modules() body, marker-delimited so
// a repeat Generate replaces its own prior block instead of duplicating -
// same discipline as ufirmwarebuildconfig.pas's SpliceOverrideBlock. No-op
// (returns '') if AIds contains no file-copy uCNC modules. AIds may
// include non-uCNC/non-file-copy ids freely - they're simply skipped here.
function ApplyUCNCModuleFiles(const AIds: TFirmwareModuleIdArray;
  const AModulesRepoRoot, ADestDir: string): string;

implementation

uses
  FileUtil;

const
  MODULE_COUNT = 18;
  MODULES: array[0..MODULE_COUNT - 1] of TModuleInfo = (
    (Id: fmUCNCi2cLcd; Ecosystem: fwUCNC;
     DisplayName: 'I2C LCD display';
     Description: 'Basic status display over software I2C on 2 auto-picked, real generic DIN pins. Verified end-to-end with a real pio compile.';
     RequiresFileCopy: True; SourceDirName: 'i2c_lcd'),
    (Id: fmUCNCEncoder; Ecosystem: fwUCNC;
     DisplayName: 'Quadrature encoder (MPG/jog wheel)';
     Description: 'Built-in ENCODERS support - needs 2 free generic DIN pins (pulse + dir), chosen below. Verified end-to-end with a real pio compile.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmGrblHALEncoder; Ecosystem: fwGrblHAL;
     DisplayName: 'Quadrature encoder (jog/override)';
     Description: 'Plugin_encoder - only offered when this board already breaks out QEI pins.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmGrblHALKeypad; Ecosystem: fwGrblHAL;
     DisplayName: 'Keypad (UART mode)';
     Description: 'Plugin_keypad, UART mode - jog/feed-hold/cycle-start over a free UART port.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmUCNCRelay; Ecosystem: fwUCNC;
     DisplayName: 'Relay / digital output control (M62-M65)';
     Description: 'Adds LinuxCNC-style M62-M65 GCode to turn any already-wired generic output pin on/off (e.g. M62 P5). No pin selection here - the pin number is a GCode parameter at run time. Verified end-to-end with a real pio compile.';
     RequiresFileCopy: True; SourceDirName: 'm62_m65'),
    (Id: fmUCNCShiftRegisterOut; Ecosystem: fwUCNC;
     DisplayName: 'Output expander (IC74HC595 shift register)';
     Description: 'Adds up to 56 extra DOUT-family output pins via a chained 74HC595 (e.g. for many relays) - uses 3 auto-picked, real DOUT control pins. Verified end-to-end with a real pio compile.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmGrblHALMcp23017; Ecosystem: fwGrblHAL;
     DisplayName: 'I2C GPIO expander (MCP23017)';
     Description: '16-channel I2C GPIO expander (8 outputs + 8 inputs by default) - no pin config needed, uses the board''s existing I2C bus. Verified end-to-end with a real pio compile.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmUCNCEeprom; Ecosystem: fwUCNC;
     DisplayName: 'External I2C EEPROM/FRAM (persistent settings)';
     Description: 'Persistent settings storage on an external I2C EEPROM chip, over software I2C on 2 auto-picked, real generic DIN pins.';
     RequiresFileCopy: True; SourceDirName: 'i2c_eeprom'),
    (Id: fmGrblHALEeprom; Ecosystem: fwGrblHAL;
     DisplayName: 'External I2C EEPROM/FRAM (persistent settings)';
     Description: 'Persistent settings storage on an external I2C EEPROM/FRAM chip - no pin config needed, uses the board''s existing I2C bus.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmUCNCBltouch; Ecosystem: fwUCNC;
     DisplayName: 'BLTouch probe (M280)';
     Description: 'BLTouch auto-leveling probe support over M280, using the board''s SERVO0 pin - only offered when SERVO0 is already active on this board.';
     RequiresFileCopy: True; SourceDirName: 'bltouch'),
    (Id: fmGrblHALSdCard; Ecosystem: fwGrblHAL;
     DisplayName: 'SD card (run GCode from card)';
     Description: 'Run GCode programs directly from an SD card - only offered when the board already breaks out a real SD chip-select pin.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmGrblHALBluetooth; Ecosystem: fwGrblHAL;
     DisplayName: 'Bluetooth serial (HC-05)';
     Description: 'HC-05 Bluetooth module support - no pin config needed, auto-picks a free port and self-configures at run time.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmGrblHALTrinamic; Ecosystem: fwGrblHAL;
     DisplayName: 'Silent stepper drivers (Trinamic TMC2209, UART)';
     Description: 'Silent/quiet TMC2209 stepper driver support (UART mode) for all configured motors - only offered when the board already has Trinamic UART/SPI wiring.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmUCNCTrinamicX; Ecosystem: fwUCNC;
     DisplayName: 'Silent stepper driver - X axis (Trinamic TMC2209, UART)';
     Description: 'Silent/quiet TMC2209 driver for the X axis (STEPPER0) only, over UART - uses 2 auto-picked, real DOUT(TX)/DIN(RX) pins. Other axes need the same module added per-stepper (not yet built).';
     RequiresFileCopy: True; SourceDirName: 'tmc_driver'),
    (Id: fmUCNCSdCard; Ecosystem: fwUCNC;
     DisplayName: 'SD card (run GCode from card)';
     Description: 'Run GCode programs from an SD/MMC card ($run/$ls/$cd/$sdmnt) over software SPI on 4 auto-picked, real pins.';
     RequiresFileCopy: True; SourceDirName: 'sd_card_v2'),
    (Id: fmGrblHALModbus; Ecosystem: fwGrblHAL;
     DisplayName: 'Modbus RTU (RS485)';
     Description: 'Generic Modbus RTU support (auto direction mode) - real base for RS485-connected VFD spindles and similar devices, no board-specific pin needed.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmUCNCModbusVfd; Ecosystem: fwUCNC;
     DisplayName: 'Huanyang VFD spindle (Modbus RS485)';
     Description: 'Selects the Huanyang VFD spindle driver as the primary tool (TOOL1), over Modbus RS485 on 2 auto-picked, real DOUT(TX)/DIN(RX) softuart pins.';
     RequiresFileCopy: False; SourceDirName: ''),
    (Id: fmGrblHALEthernet; Ecosystem: fwGrblHAL;
     DisplayName: 'Ethernet (WIZnet W5500)';
     Description: 'Wired Ethernet - GCode streaming, Telnet, WebSocket over a WIZnet W5500 breakout on the board''s SPI bus (DHCP by default). Only offered when the board already breaks out a WIZnet chip-select pin.';
     RequiresFileCopy: False; SourceDirName: '')
  );

function GetModuleInfo(AId: TFirmwareModuleId): TModuleInfo;
var
  i: Integer;
begin
  for i := 0 to MODULE_COUNT - 1 do
    if MODULES[i].Id = AId then
    begin
      Result := MODULES[i];
      Exit;
    end;
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := fmNone;
end;

function ModulesForEcosystem(AEcosystem: TFirmwareEcosystem): TFirmwareModuleIdArray;
var
  i, n: Integer;
begin
  SetLength(Result, 0);
  n := 0;
  for i := 0 to MODULE_COUNT - 1 do
    if MODULES[i].Ecosystem = AEcosystem then
    begin
      SetLength(Result, n + 1);
      Result[n] := MODULES[i].Id;
      Inc(n);
    end;
end;

function LoadFileTextSafe(const APath: string): string;
var
  f: TStringList;
begin
  Result := '';
  if not FileExists(APath) then Exit;
  f := TStringList.Create;
  try
    f.LoadFromFile(APath);
    Result := f.Text;
  finally
    f.Free;
  end;
end;

// True if AMapText contains an uncommented "#define <AName>" line - a
// simple, direct active/absent check (deliberately not going through
// TBoardMap's slot model, which only recognizes specific known pin
// families; this is used for one-off named checks like SERVO0).
function HasActiveDefine(const AMapText, AName: string): Boolean;
var
  lines: TStringList;
  i: Integer;
  trimmed: string;
begin
  Result := False;
  lines := TStringList.Create;
  try
    lines.Text := AMapText;
    for i := 0 to lines.Count - 1 do
    begin
      trimmed := TrimLeft(lines[i]);
      if Pos('#define ' + AName + ' ', trimmed) = 1 then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
    lines.Free;
  end;
end;

function ModuleAvailableForBoard(AId: TFirmwareModuleId; const AEnv: TBoardEnv): Boolean;
var
  mapText: string;
begin
  case AId of
    fmGrblHALEncoder:
      begin
        mapText := LoadFileTextSafe(IncludeTrailingPathDelimiter(AEnv.RepoDir) + AEnv.MapFilePath);
        Result := Pos('QEI_A_PORT', mapText) > 0;
      end;
    fmGrblHALKeypad:
      begin
        mapText := LoadFileTextSafe(IncludeTrailingPathDelimiter(AEnv.RepoDir) + AEnv.MapFilePath);
        Result := Pos('UART KEYPAD connection is not supported', mapText) = 0;
      end;
    fmUCNCBltouch:
      begin
        // Only offered when SERVO0 is already ACTIVE (uncommented) on this
        // board - bltouch.c's own default (BLTOUCH_PROBE_SERVO SERVO0)
        // assumes a real servo output already exists; this module doesn't
        // attempt to activate a merely-available SERVO0 itself (unlike the
        // DIN/DOUT pin families, whose activation mechanism is proven
        // safe - SERVO pins haven't been verified the same way).
        mapText := LoadFileTextSafe(IncludeTrailingPathDelimiter(AEnv.RepoDir) + AEnv.MapFilePath);
        Result := HasActiveDefine(mapText, 'SERVO0_BIT');
      end;
    fmGrblHALSdCard:
      begin
        // Real, confirmed requirement (grbl/driver_opts2.h):
        // `#if SDCARD_ENABLE && !SDCARD_SDIO && !defined(SD_CS_PIN) #error
        // SD card plugin not supported! #endif` - only offered where the
        // board already declares one or the other.
        mapText := LoadFileTextSafe(IncludeTrailingPathDelimiter(AEnv.RepoDir) + AEnv.MapFilePath);
        Result := (Pos('SD_CS_PIN', mapText) > 0) or (Pos('SDCARD_SDIO', mapText) > 0);
      end;
    fmGrblHALTrinamic:
      begin
        // Boards that support Trinamic wiring declare real UART/SPI pin
        // overrides gated on TRINAMIC_UART_ENABLE/TRINAMIC_SPI_ENABLE
        // (confirmed in btt_skr_pro_v1_1_map.h) - a simple presence check
        // is a reasonable proxy, matching the same discipline already used
        // for QEI/SD-card gating (not distinguishing active vs merely
        // mentioned, an accepted, already-disclosed tradeoff elsewhere).
        mapText := LoadFileTextSafe(IncludeTrailingPathDelimiter(AEnv.RepoDir) + AEnv.MapFilePath);
        Result := Pos('TRINAMIC', mapText) > 0;
      end;
    fmGrblHALEthernet:
      begin
        // Real, confirmed requirement: WIZNET_CS_PORT/PIN must already be
        // board-declared (this module doesn't attempt to activate a pin
        // itself, same caution as SERVO/control-switch pins) - confirmed
        // present in 5/24 stm32f4xx board maps, 0/9 stm32f1xx.
        mapText := LoadFileTextSafe(IncludeTrailingPathDelimiter(AEnv.RepoDir) + AEnv.MapFilePath);
        Result := Pos('WIZNET_CS_PORT', mapText) > 0;
      end;
  else
    Result := True; // uCNC modules: no per-board hardware prerequisite
  end;
end;

function ModuleConfigLines(AId: TFirmwareModuleId; AEncPulsePin, AEncDirPin,
  ALcdSclPin, ALcdSdaPin, ASrSdoPin, ASrClkPin, ASrLatchPin,
  ATmcTxPin, ATmcRxPin,
  AEepromClkPin, AEepromDataPin,
  ASdClkPin, ASdSdoPin, ASdSdiPin, ASdCsPin,
  AVfdTxPin, AVfdRxPin: Integer): TStringArray;
begin
  SetLength(Result, 0);
  case AId of
    fmUCNCi2cLcd:
      begin
        SetLength(Result, 4);
        Result[0] := '#define ENABLE_MAIN_LOOP_MODULES';
        // Real, verified requirement (found by tracing a real pio compile
        // failure to source, then confirmed by a real successful compile
        // with this flag added): uCNC's io_hal.h only generates a generic
        // DIN pin's io<N>_config_output/_set_output/etc macros when
        // DISABLE_HAL_CONFIG_PROTECTION is defined - a deliberate safety
        // gate restricting generic DIN pins to input-only by default,
        // undocumented in i2c_lcd's own README. Software I2C (SOFTI2C, used
        // for LCD_I2C_SCL/SDA) needs both directions, so this is required.
        Result[1] := '#define DISABLE_HAL_CONFIG_PROTECTION';
        Result[2] := Format('#define LCD_I2C_SCL DIN%d', [ALcdSclPin]);
        Result[3] := Format('#define LCD_I2C_SDA DIN%d', [ALcdSdaPin]);
      end;
    fmUCNCEncoder:
      begin
        SetLength(Result, 3);
        Result[0] := '#define ENCODERS 1';
        Result[1] := Format('#define ENC0_PULSE DIN%d', [AEncPulsePin]);
        Result[2] := Format('#define ENC0_DIR DIN%d', [AEncDirPin]);
      end;
    fmGrblHALEncoder:
      begin
        SetLength(Result, 1);
        // Mode 1 = absolute jogging (the plugin's README describes 1 and 2
        // as two experimental jogging modes, absolute or relative - 1 is
        // used here as the default/first mode).
        Result[0] := '#define ENCODER_ENABLE 1';
      end;
    fmGrblHALKeypad:
      begin
        SetLength(Result, 1);
        Result[0] := '#define KEYPAD_ENABLE 2';
      end;
    fmUCNCRelay:
      begin
        SetLength(Result, 1);
        Result[0] := '#define ENABLE_PARSER_MODULES';
      end;
    fmUCNCShiftRegisterOut:
      begin
        SetLength(Result, 4);
        Result[0] := '#define IC74HC595_COUNT 1';
        Result[1] := Format('#define SHIFT_REGISTER_SDO DOUT%d', [ASrSdoPin]);
        Result[2] := Format('#define SHIFT_REGISTER_CLK DOUT%d', [ASrClkPin]);
        Result[3] := Format('#define IC74HC595_LATCH DOUT%d', [ASrLatchPin]);
      end;
    fmGrblHALMcp23017:
      begin
        SetLength(Result, 1);
        // Mode 1: port A as outputs, port B as inputs - the most generally
        // useful default (both directions available at once).
        Result[0] := '#define MCP23017_ENABLE 1';
      end;
    fmUCNCEeprom:
      begin
        SetLength(Result, 5);
        Result[0] := '#define ENABLE_SETTINGS_MODULES';
        // Forces software I2C on 2 auto-picked DIN pins rather than
        // trusting hardware I2C to exist on every board - same reasoning
        // as i2c_lcd, same required DISABLE_HAL_CONFIG_PROTECTION flag
        // (these DIN pins need bidirectional I2C, not input-only).
        Result[1] := '#define I2C_EEPROM_INTERFACE SW_I2C';
        Result[2] := '#define DISABLE_HAL_CONFIG_PROTECTION';
        Result[3] := Format('#define I2C_EEPROM_I2C_CLOCK DIN%d', [AEepromClkPin]);
        Result[4] := Format('#define I2C_EEPROM_I2C_DATA DIN%d', [AEepromDataPin]);
      end;
    fmGrblHALEeprom:
      begin
        SetLength(Result, 1);
        // 16 = 2K capacity, the smallest/most common real-world EEPROM
        // size for this - the module's own comment documents 16/32/64/
        // 128/256 as the valid values (2K through 32K).
        Result[0] := '#define EEPROM_ENABLE 16';
      end;
    fmUCNCBltouch:
      begin
        SetLength(Result, 1);
        Result[0] := '#define ENABLE_IO_MODULES';
      end;
    fmGrblHALSdCard:
      begin
        SetLength(Result, 1);
        Result[0] := '#define SDCARD_ENABLE 1';
      end;
    fmGrblHALBluetooth:
      begin
        SetLength(Result, 1);
        Result[0] := '#define BLUETOOTH_ENABLE 2';
      end;
    fmGrblHALTrinamic:
      begin
        SetLength(Result, 1);
        // TMC2209 auto-derives TRINAMIC_UART_ENABLE=1 - confirmed real in
        // grbl/driver_opts.h, no companion define needed.
        Result[0] := '#define TRINAMIC_ENABLE 2209';
      end;
    fmUCNCTrinamicX:
      begin
        SetLength(Result, 6);
        Result[0] := '#define ENABLE_MAIN_LOOP_MODULES';
        Result[1] := '#define ENABLE_PARSER_MODULES';
        Result[2] := '#define STEPPER0_HAS_TMC';
        Result[3] := '#define STEPPER0_DRIVER_TYPE 2209';
        Result[4] := Format('#define STEPPER0_UART_TX DOUT%d', [ATmcTxPin]);
        Result[5] := Format('#define STEPPER0_UART_RX DIN%d', [ATmcRxPin]);
      end;
    fmUCNCSdCard:
      begin
        SetLength(Result, 7);
        Result[0] := '#define ENABLE_MAIN_LOOP_MODULES';
        // Real, verified requirement (diskio.h): SD_CARD_INTERFACE
        // defaults to SD_CARD_HW_SPI - forcing SW_SPI + explicit pins
        // avoids trusting hardware SPI to exist/be free on every board,
        // same reasoning as i2c_lcd's original hardware-I2C risk.
        Result[1] := '#define SD_CARD_INTERFACE SD_CARD_SW_SPI';
        Result[2] := Format('#define SD_SPI_CLK DOUT%d', [ASdClkPin]);
        Result[3] := Format('#define SD_SPI_SDO DOUT%d', [ASdSdoPin]);
        Result[4] := Format('#define SD_SPI_SDI DIN%d', [ASdSdiPin]);
        Result[5] := Format('#define SD_SPI_CS DOUT%d', [ASdCsPin]);
        // Real, verified upstream gap (found via a real pio compile
        // failure, "SD_CARD_SPI_DMA undeclared"): diskio.c's
        // mmcsd_spi_speed() references SD_CARD_SPI_DMA unconditionally,
        // but the module only ever gives it a default inside the
        // HW_SPI/HW_SPI2 branches - never for SW_SPI, which we force
        // above. `false` is the semantically correct value for software
        // SPI (DMA genuinely isn't used), not just a workaround value.
        Result[6] := '#define SD_CARD_SPI_DMA false';
      end;
    fmGrblHALModbus:
      begin
        SetLength(Result, 1);
        Result[0] := '#define MODBUS_ENABLE 1';
      end;
    fmUCNCModbusVfd:
      begin
        SetLength(Result, 4);
        // Real, confirmed mechanism (cnc_hal_config.h's own "Tool
        // pallete" docs): TOOL1 is already #define'd (to spindle_pwm) by
        // default, so it must be #undef'd before redefining, to avoid a
        // "redefined" warning and to be certain the later definition
        // (this one) is the one that actually takes effect.
        Result[0] := '#undef TOOL1';
        Result[1] := '#define TOOL1 vfd_modbus';
        Result[2] := Format('#define VFD_TX_PIN DOUT%d', [AVfdTxPin]);
        Result[3] := Format('#define VFD_RX_PIN DIN%d', [AVfdRxPin]);
      end;
    fmGrblHALEthernet:
      begin
        SetLength(Result, 1);
        // Auto-derives ETHERNET_ENABLE/TELNET_ENABLE/WEBSOCKET_ENABLE
        // (Inc/my_machine.h: `#ifdef _WIZCHIP_ #define ETHERNET_ENABLE 1
        // #endif`). 5500 = W5500 chip, the most common real WIZnet
        // breakout - confirmed real via longboard32_map.h's own #error
        // gate requiring exactly this value for its WZ5500 chip.
        Result[0] := '#define _WIZCHIP_ 5500';
      end;
  end;
end;

// Recursively copies ASrcDir's *.c/*.h files (and those of any real
// subdirectories - e.g. sd_card_v2's fat_fs/ and petit_fat_fs/, the first
// module in scope that actually has any) into ADestDir, preserving the
// subdirectory structure, creating directories as needed. Only .c/.h files
// are copied at any depth - README.md/CHANGELOG.md etc are skipped the
// same way at every level, not just the top one.
function CopySourceFilesOnly(const ASrcDir, ADestDir: string): Boolean;
var
  sr: TSearchRec;
  ext: string;
begin
  Result := True;
  if not ForceDirectories(ADestDir) then
  begin
    Result := False;
    Exit;
  end;
  if FindFirst(IncludeTrailingPathDelimiter(ASrcDir) + '*', faAnyFile, sr) = 0 then
  begin
    try
      repeat
        if (sr.Name = '.') or (sr.Name = '..') then Continue;
        if (sr.Attr and faDirectory) <> 0 then
        begin
          if not CopySourceFilesOnly(IncludeTrailingPathDelimiter(ASrcDir) + sr.Name,
               IncludeTrailingPathDelimiter(ADestDir) + sr.Name) then
          begin
            Result := False;
            Break;
          end;
          Continue;
        end;
        ext := LowerCase(ExtractFileExt(sr.Name));
        if (ext <> '.c') and (ext <> '.h') then Continue;
        if not CopyFile(IncludeTrailingPathDelimiter(ASrcDir) + sr.Name,
             IncludeTrailingPathDelimiter(ADestDir) + sr.Name) then
        begin
          Result := False;
          Break;
        end;
      until FindNext(sr) <> 0;
    finally
      FindClose(sr);
    end;
  end;
end;

// Splices `LOAD_MODULE(<name>);` lines right after module.c's real
// `// PLACE YOUR MODULES HERE` marker (inside load_modules()'s body),
// replacing any prior Firmware-Builder-inserted block found by our own
// markers first. Leaves the file untouched (returns AModuleCText as-is) if
// the real marker isn't found - that would mean the copied module.c isn't
// what we expect, and silently inserting the calls somewhere else in the
// file (possibly outside the function) would produce broken C.
function SpliceModuleLoadCalls(const AModuleCText: string; const AModuleNames: array of string): string;
var
  lines: TStringList;
  startLine, endLine, insertAt, i: Integer;
begin
  lines := TStringList.Create;
  try
    lines.Text := AModuleCText;

    startLine := -1;
    endLine := -1;
    for i := 0 to lines.Count - 1 do
    begin
      if Trim(lines[i]) = MODULE_LOAD_MARKER_START then startLine := i
      else if (startLine >= 0) and (Trim(lines[i]) = MODULE_LOAD_MARKER_END) then
      begin
        endLine := i;
        Break;
      end;
    end;
    if (startLine >= 0) and (endLine >= startLine) then
      for i := endLine downto startLine do
        lines.Delete(i);

    insertAt := -1;
    for i := 0 to lines.Count - 1 do
      if Pos('PLACE YOUR MODULES HERE', lines[i]) > 0 then
      begin
        insertAt := i;
        Break;
      end;
    if insertAt < 0 then
    begin
      Result := AModuleCText;
      Exit;
    end;

    lines.Insert(insertAt + 1, MODULE_LOAD_MARKER_END);
    for i := 0 to High(AModuleNames) do
      lines.Insert(insertAt + 1, Format('LOAD_MODULE(%s);', [AModuleNames[i]]));
    lines.Insert(insertAt + 1, MODULE_LOAD_MARKER_START);

    Result := lines.Text;
  finally
    lines.Free;
  end;
end;

function ApplyUCNCModuleFiles(const AIds: TFirmwareModuleIdArray;
  const AModulesRepoRoot, ADestDir: string): string;
var
  i: Integer;
  info: TModuleInfo;
  names: TStringList;
  moduleCPath, srcDir, destSubDir: string;
  moduleCText: string;
  f: TStringList;
begin
  Result := '';
  names := TStringList.Create;
  try
    for i := 0 to High(AIds) do
    begin
      info := GetModuleInfo(AIds[i]);
      if (info.Id = fmNone) or not info.RequiresFileCopy then Continue;

      srcDir := IncludeTrailingPathDelimiter(AModulesRepoRoot) + info.SourceDirName;
      destSubDir := IncludeTrailingPathDelimiter(ADestDir) + 'uCNC' + PathDelim +
        'src' + PathDelim + 'modules' + PathDelim + info.SourceDirName;
      if not DirectoryExists(srcDir) then
      begin
        Result := 'Module source missing: ' + srcDir;
        Exit;
      end;
      if not CopySourceFilesOnly(srcDir, destSubDir) then
      begin
        Result := 'Could not copy module files for ' + info.DisplayName;
        Exit;
      end;
      names.Add(info.SourceDirName);
    end;

    if names.Count = 0 then Exit; // nothing to splice into module.c

    moduleCPath := IncludeTrailingPathDelimiter(ADestDir) + 'uCNC' + PathDelim +
      'src' + PathDelim + 'module.c';
    if not FileExists(moduleCPath) then
    begin
      Result := 'Copied project is missing uCNC/src/module.c';
      Exit;
    end;

    f := TStringList.Create;
    try
      f.LoadFromFile(moduleCPath);
      moduleCText := f.Text;
      moduleCText := SpliceModuleLoadCalls(moduleCText, names.ToStringArray);
      f.Text := moduleCText;
      f.SaveToFile(moduleCPath);
    finally
      f.Free;
    end;
  finally
    names.Free;
  end;
end;

end.
