unit usettingtemplates;

{ usettingtemplates: plan Phase 26 - known-good $$ defaults per common
  board/machine, transcribed verbatim from OpenBuilds CONTROL's own real
  app/js/grbl-settings-defaults.js (selectMachine()'s grblParams_def
  object, one per "type" branch, read directly from
  references/OpenBuilds-CONTROL-master.zip) - not invented, same
  "transcribe a real reference table, don't guess values" discipline
  usettinghelp.pas's own Phase 18 table already established. The
  source's "custom" branch is deliberately excluded (not a real machine,
  just a blank-ish fallback). The "acroa1" branch's real, genuine
  duplicate-key quirk (two $31/$32 entries in one JS object literal) is
  represented here as the single de-duplicated pair JS itself actually
  ends up sending at runtime (plain object literals silently collapse a
  duplicate key to its last value) - see usettingtemplates_data.inc's
  own comment on that entry.

  Each entry is just an $ID->value map - no per-board pin assignments or
  homing-direction commentary duplicated here, since
  usettingsgridframe.pas's own existing Apply step already diffs against
  the board's current values and sends only changed rows; this unit is
  purely a values source for that combo, not a board setup wizard. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTemplateSetting = record
    ID: Integer;
    Value: string;
  end;
  TTemplateSettingArray = array of TTemplateSetting;

  TSettingTemplate = record
    Key: string;          // internal id, e.g. 'sphinx55'
    DisplayName: string;  // shown in the "Load template..." combo
    Settings: TTemplateSettingArray;
  end;
  TSettingTemplateArray = array of TSettingTemplate;

// SettingTemplates: all known templates, in source order. Parsed once
// from the '|'-delimited RawTemplates table (usettingtemplates_data.inc)
// and cached.
function SettingTemplates: TSettingTemplateArray;

// FindSettingTemplate: looks up by the internal Key (not DisplayName).
function FindSettingTemplate(const AKey: string; out ATemplate: TSettingTemplate): Boolean;

implementation

{$I usettingtemplates_data.inc}

var
  FCache: TSettingTemplateArray;
  FCacheBuilt: Boolean;

function ParseSettings(const ARaw: string): TTemplateSettingArray;
var
  parts: TStringList;
  i, eqPos: Integer;
begin
  Result := nil;
  parts := TStringList.Create;
  try
    parts.Delimiter := '|';
    parts.StrictDelimiter := True;
    parts.DelimitedText := ARaw;
    SetLength(Result, parts.Count);
    for i := 0 to parts.Count - 1 do
    begin
      eqPos := Pos('=', parts[i]);
      Result[i].ID := StrToIntDef(Copy(parts[i], 1, eqPos - 1), -1);
      Result[i].Value := Copy(parts[i], eqPos + 1, Length(parts[i]) - eqPos);
    end;
  finally
    parts.Free;
  end;
end;

procedure BuildCache;
var
  i: Integer;
begin
  SetLength(FCache, RawTemplateCount);
  for i := 0 to RawTemplateCount - 1 do
  begin
    FCache[i].Key := RawTemplates[i][0];
    FCache[i].DisplayName := RawTemplates[i][1];
    FCache[i].Settings := ParseSettings(RawTemplates[i][2]);
  end;
  FCacheBuilt := True;
end;

function SettingTemplates: TSettingTemplateArray;
begin
  if not FCacheBuilt then BuildCache;
  Result := FCache;
end;

function FindSettingTemplate(const AKey: string; out ATemplate: TSettingTemplate): Boolean;
var
  i: Integer;
  all: TSettingTemplateArray;
begin
  all := SettingTemplates;
  for i := 0 to High(all) do
    if all[i].Key = AKey then
    begin
      ATemplate := all[i];
      Exit(True);
    end;
  Result := False;
end;

end.
