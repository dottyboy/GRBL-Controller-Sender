unit uterminalframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Graphics,
  usender;

type

  { TTerminalFrame }

  TTerminalFrame = class(TFrame)
    BtnClear: TButton;
    BtnSend: TButton;
    EdCommand: TEdit;
    Memo: TMemo;
    procedure ClearClick(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure EdCommandKeyPress(Sender: TObject; var Key: char);
  private
    FSender: TSender;
  public
    procedure SetSender(ASender: TSender);
    procedure AppendLine(const ALine: string; IsError: Boolean);
  end;

implementation

{$R *.frm}

{ TTerminalFrame }

procedure TTerminalFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TTerminalFrame.AppendLine(const ALine: string; IsError: Boolean);
var
  prefix: string;
begin
  if IsError then
    prefix := '[ERR] '
  else
    prefix := '';
  Memo.Lines.Add(prefix + ALine);
end;

procedure TTerminalFrame.SendClick(Sender: TObject);
begin
  if (FSender = nil) or (Trim(EdCommand.Text) = '') then Exit;
  Memo.Lines.Add('> ' + EdCommand.Text);
  FSender.EnqueueGCode(EdCommand.Text);
  EdCommand.Text := '';
end;

procedure TTerminalFrame.ClearClick(Sender: TObject);
begin
  Memo.Clear;
end;

procedure TTerminalFrame.EdCommandKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    SendClick(Sender);
  end;
end;

end.
