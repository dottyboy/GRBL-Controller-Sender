unit uboardcatalog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils;

type
  { TBoardProfile: one curated, manually-selectable catalog entry. Seed
    data below is real, verified-on-disk data (see plan Context section) -
    µCNC entries are actual board header filenames from
    References/uCNC/uCNC/src/hal/boards/<family>/boardmap_*.h; grblHAL
    entries are driver FAMILIES only (from References/grblHAL-drivers/
    drivers.json) since the actual per-PCB grblHAL driver/board repos are
    not checked out locally - no fabricated grblHAL board model names. }
  TBoardProfile = record
    Name: string;
    Ecosystem: string; // 'grblHAL' | 'uCNC'
    Family: string;    // MCU/driver family, e.g. 'STM32F4xx', 'stm32', 'avr'
    AxisCount: Integer;
    Kinematics: string; // '' = unknown/cartesian default
    Notes: string;
  end;

  TBoardProfileArray = array of TBoardProfile;

function BoardCatalog: TBoardProfileArray;
function AllNames: TStringList; // "Ecosystem: Name" display strings, catalog index order
function ByEcosystem(const AEcosystem: string): TStringList;
function ByFamily(const AFamily: string): TStringList;
function ProfileAt(AIndex: Integer): TBoardProfile;

implementation

const
  Catalog: TBoardProfileArray = (
    // --- grblHAL: driver families only (real, from drivers.json) ---
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'iMXRT1062 (Teensy 4.x)'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'STM32F1xx'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'STM32F4xx'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'STM32F7xx'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'STM32H7xx'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'ESP32'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'SAM3X8E (Arduino Due)'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'RP2040 (Pi Pico & Pico W)'; AxisCount: 3; Kinematics: ''; Notes: ''),
    (Name: 'Custom board on this driver'; Ecosystem: 'grblHAL'; Family: 'Simulator'; AxisCount: 3; Kinematics: ''; Notes: ''),

    // --- uCNC: real board header filenames, hal/boards/avr/ ---
    (Name: 'Arduino Uno'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_uno.h'),
    (Name: 'Arduino Uno (mirror)'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_uno_mirror.h'),
    (Name: 'Arduino Uno + CNC Shield v3'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_uno_shield_v3.h'),
    (Name: 'RAMPS 1.4'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_ramps14.h'),
    (Name: 'RAMPS 1.4 (mirror)'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_ramps14_mirror.h'),
    (Name: 'RAMBo 1.4'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_rambo14.h'),
    (Name: 'Melzi v1.14'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_melzi_v114.h'),
    (Name: 'MKS GEN L v1'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_gen_l_v1.h'),
    (Name: 'MKS DLC'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_dlc.h'),
    (Name: 'Mega Shield v3'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mega_shield_v3.h'),
    (Name: 'X-Controller'; Ecosystem: 'uCNC'; Family: 'avr'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_x_controller.h'),

    // --- uCNC: hal/boards/stm32/ ---
    (Name: 'Blue Pill (STM32F103)'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_bluepill.h'),
    (Name: 'Blue Pill F0'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_bluepill_f0.h'),
    (Name: 'Black Pill'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_blackpill.h'),
    (Name: 'BTT SKR3'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_skr3.h'),
    (Name: 'BTT SKR v1.4 Turbo'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_skr_v14_turbo.h'),
    (Name: 'MKS Robin Nano v1.2'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_robin_nano_v1_2.h'),
    (Name: 'MKS Robin Nano v3.1'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_robin_nano_v3_1.h'),
    (Name: 'Fysetc Cheetah v2'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_fysetc_cheetah_v2.h'),
    (Name: 'Mellow Fly D5'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mellow_fly_d5.h'),
    (Name: 'MKS Monster8 v2'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_monster8_v2.h'),
    (Name: 'Generic STM32H750'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_generic_h750.h'),
    (Name: 'Nucleo F411RE + Shield v3'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_nucleo_f411re_shield_v3.h'),
    (Name: 'SRK Pro v1.2'; Ecosystem: 'uCNC'; Family: 'stm32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_srk_pro_v1_2.h'),

    // --- uCNC: hal/boards/esp32/ ---
    (Name: 'ESP32-S3 DevKit'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_devkit_s3.h'),
    (Name: 'ESP32-C3 Core'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_core_c3.h'),
    (Name: 'MKS DLC32'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_dlc32.h'),
    (Name: 'MKS DLC32 S3'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_dlc32_s3.h'),
    (Name: 'MKS TinyBee'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_tinybee.h'),
    (Name: 'ESP32 CNC Shield v3'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_esp32_shield_v3.h'),
    (Name: 'Wemos D1 R32'; Ecosystem: 'uCNC'; Family: 'esp32'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_wemos_d1_r32.h'),

    // --- uCNC: hal/boards/esp8266/, lpc176x/, rp2040/, samd21/ ---
    (Name: 'Wemos D1 (ESP8266)'; Ecosystem: 'uCNC'; Family: 'esp8266'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_wemos_d1.h'),
    (Name: 'MKS Base 1.3'; Ecosystem: 'uCNC'; Family: 'lpc176x'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mks_base13.h'),
    (Name: 'Re-ARM'; Ecosystem: 'uCNC'; Family: 'lpc176x'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_re_arm.h'),
    (Name: 'Raspberry Pi Pico'; Ecosystem: 'uCNC'; Family: 'rp2040'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_rpi_pico.h'),
    (Name: 'Raspberry Pi Pico 2'; Ecosystem: 'uCNC'; Family: 'rp2040'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_rpi_pico2.h'),
    (Name: 'Raspberry Pi Pico W'; Ecosystem: 'uCNC'; Family: 'rp2040'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_rpi_pico_w.h'),
    (Name: 'SAMD21 Zero'; Ecosystem: 'uCNC'; Family: 'samd21'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_zero.h'),
    (Name: 'SAMD21 MZero'; Ecosystem: 'uCNC'; Family: 'samd21'; AxisCount: 3; Kinematics: ''; Notes: 'boardmap_mzero.h')
  );

function BoardCatalog: TBoardProfileArray;
begin
  Result := Catalog;
end;

function AllNames: TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to High(Catalog) do
    Result.Add(Catalog[i].Ecosystem + ': ' + Catalog[i].Name +
      IfThen(Catalog[i].Family <> '', ' (' + Catalog[i].Family + ')', ''));
end;

function ByEcosystem(const AEcosystem: string): TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to High(Catalog) do
    if SameText(Catalog[i].Ecosystem, AEcosystem) then
      Result.AddObject(Catalog[i].Name, TObject(PtrInt(i)));
end;

function ByFamily(const AFamily: string): TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to High(Catalog) do
    if SameText(Catalog[i].Family, AFamily) then
      Result.AddObject(Catalog[i].Name, TObject(PtrInt(i)));
end;

function ProfileAt(AIndex: Integer): TBoardProfile;
begin
  Result := Catalog[AIndex];
end;

end.
