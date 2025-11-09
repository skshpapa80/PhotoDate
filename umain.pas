// 작성자: Ray Cho (skshpapa80@gmail.com)
// 프로그래명 : 사진 정리 프로그램
// 작성일 : 2015-11-11
// 수정일 : 2025-11-09
// 블로그 : https://skshpapa80.blogspot.com/
//
// exif 정보를 이용한 파일 정리 프로그램

unit umain;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
    dGlobal, dMetadata, FileUtil, lclintf;

type

	{ TfrmMain }

    TfrmMain = class(TForm)
		btnFolderSel: TButton;
		btnClear: TButton;
		btnTarget: TButton;
		btnWorkStart: TButton;
		Edit_target: TEdit;
		GroupBox1: TGroupBox;
		GroupBox2: TGroupBox;
		GroupBox3: TGroupBox;
		GroupBox4: TGroupBox;
		GroupBox5: TGroupBox;
		Label1: TLabel;
		Label2: TLabel;
		Label3: TLabel;
		Label_ImgCount: TLabel;
		lsvFileList: TListView;
		ProgBar: TProgressBar;
		RadioButton1: TRadioButton;
		RadioButton2: TRadioButton;
		rdoMove: TRadioButton;
		rdoCopy: TRadioButton;
		procedure btnClearClick(Sender: TObject);
        procedure btnFolderSelClick(Sender: TObject);
        procedure btnTargetClick(Sender: TObject);
        procedure btnWorkStartClick(Sender: TObject);
		procedure Label3Click(Sender: TObject);
    private
        CurPath: String;
        procedure LoadFileList(Path: String);
    public

    end;

var
   frmMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

function UNIXTimeToDateTimeFAST(UnixTime: Int64): TDateTime;
begin
    Result := (UnixTime / 86400000) + 25569;
end;

Function FileSizeFormat(Size: Double):String;
const
    sUnit: array[0..3] of string = ('KB', 'MB', 'GB', 'TB');
var
    nUnit: ShortInt;
    nDec : Integer;
    nTmp: Double;
begin
    nUnit := 0;
    nTmp := Round( Size / 1024);

    while (nTmp > 1024) do begin
        nTmp := nTmp / 1024;
        Inc(nUnit);
    end;
    nDec := Integer(Trunc((nTmp * 10) - Trunc(nTmp) * 10) > 0);
    Result := Format('%1.*n%s', [nDec,nTmp, sUnit[nUnit]]);
end;

procedure TfrmMain.btnFolderSelClick(Sender: TObject);
var
   Dir: String;
begin
   if SelectDirectory('폴더 찾아보기','',Dir) then begin
      if Dir[Length(Dir)] <> '\' then
	     Dir := Dir + '\';
      CurPath := Dir;
	  LoadFileList(CurPath);
   end;
end;

procedure TfrmMain.btnTargetClick(Sender: TObject);
var
   Dir: String;
begin
   if SelectDirectory('폴더 찾아보기','',Dir) then begin
      if Dir[Length(Dir)] <> '\' then
	     Dir := Dir + '\';
      Edit_target.Text := Dir;
   end;
end;

procedure TfrmMain.btnWorkStartClick(Sender: TObject);
var
   i, wCnt, pCnt: Integer;
   ImgData: TImgData;
   DstPath, FileName: String;
begin
   // 작업 시작
    if Edit_target.Text = '' then begin
        Exit;
    end;

    if lsvFileList.Items.Count = 0 then begin
        Exit;
    end;

    wCnt := 0;
    pCnt := 0;

    ProgBar.Min := 0;
    ProgBar.Max := lsvFileList.Items.Count;
    for i := 0 to lsvFileList.Items.Count - 1 do begin
        FileName := lsvFileList.Items.Item[i].Caption;

        if RadioButton2.Checked then begin

            DstPath := FormatDateTime('yyyy-MM-dd',UNIXTimeToDateTimeFAST(StrToInt64(StringReplace(FileName,ExtractFileExt(FileName),'',[rfReplaceAll, rfIgnoreCase]))));

            if not DirectoryExists(Edit_target.Text + DstPath) then begin
                ChDir(Edit_target.Text);
                MkDir(DstPath);
                pCnt := pCnt + 1;
            end;

            if FileExists(Edit_target.Text + DstPath + '\' + FileName) then begin

            end
            else begin
                // 옵션 파일 이동 선택
                if rdoMove.Checked = true then begin
                    RenameFile(PChar(CurPath + FileName),PChar(Edit_target.Text + DstPath + '\' + FileName));
                end
                // 옵션 파일 복사 선택
                else if rdoCopy.Checked = true then begin
                    CopyFile(PChar(CurPath + FileName),PChar(Edit_target.Text + DstPath + '\' + FileName),false);
                end;
            end;

        end
        else begin
            ImgData:= TImgData.Create();

            if ImgData.ProcessFile(CurPath + FileName) then begin
                // EXIF 정보 유무 확인
                if ImgData.HasEXIF = true then begin

                    DstPath := FormatDateTime('yyyy-MM-dd',ImgData.ExifObj.GetImgDateTime);

                    if not DirectoryExists(Edit_target.Text + DstPath) then begin
                        ChDir(Edit_target.Text);
                        MkDir(DstPath);
                        pCnt := pCnt + 1;
                    end;

                    if FileExists(Edit_target.Text + DstPath + '\' + FileName) then begin

                    end
                    else begin
                        // 옵션 파일 이동 선택
                        if rdoMove.Checked = true then begin
                            RenameFile(PChar(CurPath + FileName),PChar(Edit_target.Text + DstPath + '\' + FileName));
                        end
                        // 옵션 파일 복사 선택
                        else if rdoCopy.Checked = true then begin
                            CopyFile(PChar(CurPath + FileName),PChar(Edit_target.Text + DstPath + '\' + FileName),false);
                        end;
                    end;
                end;
            end;
        end;

        wCnt := wCnt + 1;
        Label1.Caption := '작업 이미지 갯수 : ' + IntToStr(wCnt);
        Label2.Caption := '폴더 생성 갯수 : ' + IntToStr(pCnt);
        ProgBar.Position := ProgBar.Position + 1;
        ImgData.Free;
        Application.ProcessMessages;

    end;

    ShowMessage('작업완료');
end;

procedure TfrmMain.Label3Click(Sender: TObject);
begin
    OpenURL('https://skshpapa80.blogspot.com/');
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
   Edit_target.Text := '';
   lsvFileList.Items.Clear;
   Label_ImgCount.Caption := '총 이미지 : 0';
   Label1.Caption := '작업이미지 갯수 : 0';
   Label2.Caption := '폴더 생 갯수 : 0';
end;

procedure TfrmMain.LoadFileList(Path: String);
var
   SearchRec: TSearchRec;
   ListItem: TListItem;
begin
   if Path = '' then Exit;

   lsvFileList.Items.BeginUpdate;
   lsvFileList.Items.Clear;
   if FindFirst(Path + '*.j*',faAnyFile,SearchRec) = 0 then begin
      repeat
          ListItem := lsvFileList.Items.Add;
          ListItem.Caption := SearchRec.Name;
          ListItem.SubItems.Add(FileSizeFormat(SearchRec.Size));
      Until (FindNext(SearchRec) <> 0);
	  FindClose(SearchRec);
   end;
   lsvFileList.Items.EndUpdate;
   Label_ImgCount.Caption := '총 이미지 : ' + IntToStr(lsvFileList.Items.Count);
end;

end.

