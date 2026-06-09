// 작성자: Ray Cho (skshpapa80@gmail.com)
// 프로그래명 : 사진 정리 프로그램
// 작성일 : 2015-11-11
// 수정일 : 2026-06-09
// 블로그 : https://skshpapa80.github.io/
//
// exif 정보를 이용한 파일 정리 프로그램
//
// 기능추가 : 중복체킄 기능, 이미지 파일 비교, 중복파일 비교, 중복파일 모으기


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
	Edit_DupFolder: TEdit;
	GroupBox1: TGroupBox;
	GroupBox2: TGroupBox;
	GroupBox3: TGroupBox;
	GroupBox4: TGroupBox;
	GroupBox5: TGroupBox;
	GroupBox6: TGroupBox;
	Label1: TLabel;
	Label2: TLabel;
	Label3: TLabel;
	Label_DupCount: TLabel;
	Label_DupFolder: TLabel;
	Label_DupFolderCount: TLabel;
	Label_ImgCount: TLabel;
	lsvFileList: TListView;
	ProgBar: TProgressBar;
	RadioButton1: TRadioButton;
	RadioButton2: TRadioButton;
	rdoMove: TRadioButton;
	rdoCopy: TRadioButton;
	chkContentDup: TCheckBox;
	chkGlobalDup: TCheckBox;
	chkDupToFolder: TCheckBox;
	procedure btnClearClick(Sender: TObject);
        procedure btnFolderSelClick(Sender: TObject);
        procedure btnTargetClick(Sender: TObject);
        procedure btnWorkStartClick(Sender: TObject);
		procedure Label3Click(Sender: TObject);
    private
        CurPath: String;
        procedure LoadFileList(Path: String);
        function IsImageFile(const FileName: String): Boolean;
        function FilesAreIdentical(const File1, File2: String): Boolean;
        function GetDupFolderPath: String;
        function GetUniqueFilePath(const Folder, FileName: String): String;
        procedure CollectImageFiles(const Path: String; FileList: TStringList;
          const ExcludeFolder: String);
        function GetFolderFileList(const FolderPath: String;
          FolderCache: TStringList): TStringList;
        function FindDuplicateInList(const SrcFile: String;
          FileList: TStringList; out DupFile: String): Boolean;
        function TransferFile(const SrcFile, DestFile: String): Boolean;
        function MoveToDupFolder(const SrcFile, FileName: String;
          out DestFile, StatusMsg: String): Boolean;
        function ProcessOneFile(const FileName, DstPath: String;
          FolderCache, GlobalFileList: TStringList; var pCnt: Integer;
          out StatusMsg: String; out IsDupSkip, IsDupFolder: Boolean): Boolean;
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

function TfrmMain.IsImageFile(const FileName: String): Boolean;
var
    Ext: String;
begin
    Ext := LowerCase(ExtractFileExt(FileName));
    Result := (Ext = '.jpg') or (Ext = '.jpeg') or (Ext = '.jpe');
end;

function TfrmMain.FilesAreIdentical(const File1, File2: String): Boolean;
var
    FS1, FS2: TFileStream;
    Buf1, Buf2: array[0..8191] of Byte;
    Read1, Read2: Integer;
begin
    Result := False;
    if not FileExists(File1) or not FileExists(File2) then
        Exit;
    if FileSize(File1) <> FileSize(File2) then
        Exit;

    FS1 := TFileStream.Create(File1, fmOpenRead or fmShareDenyWrite);
    try
        FS2 := TFileStream.Create(File2, fmOpenRead or fmShareDenyWrite);
        try
            while FS1.Position < FS1.Size do begin
                Read1 := FS1.Read(Buf1[0], SizeOf(Buf1));
                Read2 := FS2.Read(Buf2[0], SizeOf(Buf2));
                if (Read1 <> Read2) or (not CompareMem(@Buf1[0], @Buf2[0], Read1)) then
                    Exit;
            end;
            Result := True;
        finally
            FS2.Free;
        end;
    finally
        FS1.Free;
    end;
end;

function TfrmMain.GetDupFolderPath: String;
var
    FolderName: String;
begin
    FolderName := Trim(Edit_DupFolder.Text);
    if FolderName = '' then
        FolderName := '_duplicates';
    if (FolderName[1] = '\') or (Pos(':', FolderName) > 0) then
        Result := IncludeTrailingPathDelimiter(FolderName)
    else
        Result := IncludeTrailingPathDelimiter(Edit_target.Text + FolderName);
end;

function TfrmMain.GetUniqueFilePath(const Folder, FileName: String): String;
var
    BaseName, Ext: String;
    i: Integer;
begin
    Result := Folder + FileName;
    if not FileExists(Result) then
        Exit;

    BaseName := ChangeFileExt(FileName, '');
    Ext := ExtractFileExt(FileName);
    i := 1;
    repeat
        Result := Folder + BaseName + '_' + IntToStr(i) + Ext;
        Inc(i);
    until not FileExists(Result);
end;

procedure TfrmMain.CollectImageFiles(const Path: String; FileList: TStringList;
  const ExcludeFolder: String);
var
    SearchRec: TSearchRec;
    FullPath, SubPath: String;
begin
    if not DirectoryExists(Path) then
        Exit;

    if FindFirst(Path + '*', faAnyFile, SearchRec) = 0 then begin
        repeat
            if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
                Continue;

            FullPath := Path + SearchRec.Name;

            if (SearchRec.Attr and faDirectory) <> 0 then begin
                if (ExcludeFolder <> '') and
                   (Pos(LowerCase(ExcludeFolder),
                     LowerCase(IncludeTrailingPathDelimiter(FullPath))) = 1) then
                    Continue;
                CollectImageFiles(IncludeTrailingPathDelimiter(FullPath),
                  FileList, ExcludeFolder);
            end
            else if IsImageFile(SearchRec.Name) then
                FileList.Add(FullPath);
        until FindNext(SearchRec) <> 0;
        FindClose(SearchRec);
    end;
end;

function TfrmMain.GetFolderFileList(const FolderPath: String;
  FolderCache: TStringList): TStringList;
var
    SearchRec: TSearchRec;
    FileList: TStringList;
    FullPath: String;
    i: Integer;
begin
    i := FolderCache.IndexOf(FolderPath);
    if i >= 0 then begin
        Result := TStringList(FolderCache.Objects[i]);
        Exit;
    end;

    FileList := TStringList.Create;
    if DirectoryExists(FolderPath) then begin
        if FindFirst(FolderPath + '*.j*', faAnyFile, SearchRec) = 0 then begin
            repeat
                FullPath := FolderPath + SearchRec.Name;
                FileList.Add(FullPath);
            until FindNext(SearchRec) <> 0;
            FindClose(SearchRec);
        end;
    end;

    FolderCache.AddObject(FolderPath, FileList);
    Result := FileList;
end;

function TfrmMain.FindDuplicateInList(const SrcFile: String;
  FileList: TStringList; out DupFile: String): Boolean;
var
    i: Integer;
    DestFile: String;
    SrcSize: Int64;
begin
    Result := False;
    DupFile := '';
    if not chkContentDup.Checked then
        Exit;

    SrcSize := FileSize(SrcFile);
    for i := 0 to FileList.Count - 1 do begin
        DestFile := FileList[i];
        if SameText(DestFile, SrcFile) then
            Continue;
        if FileSize(DestFile) <> SrcSize then
            Continue;
        if FilesAreIdentical(SrcFile, DestFile) then begin
            Result := True;
            DupFile := DestFile;
            Exit;
        end;
    end;
end;

function TfrmMain.TransferFile(const SrcFile, DestFile: String): Boolean;
begin
    if rdoMove.Checked then
        Result := RenameFile(PChar(SrcFile), PChar(DestFile))
    else
        Result := CopyFile(PChar(SrcFile), PChar(DestFile), False);
end;

function TfrmMain.MoveToDupFolder(const SrcFile, FileName: String;
  out DestFile, StatusMsg: String): Boolean;
var
    DupFolder: String;
begin
    Result := False;
    DupFolder := GetDupFolderPath;

    if not DirectoryExists(DupFolder) then
        ForceDirectories(DupFolder);

    DestFile := GetUniqueFilePath(DupFolder, FileName);
    if TransferFile(SrcFile, DestFile) then begin
        Result := True;
        StatusMsg := '중복폴더 이동';
    end
    else
        StatusMsg := '중복폴더 이동 실패';
end;

function TfrmMain.ProcessOneFile(const FileName, DstPath: String;
  FolderCache, GlobalFileList: TStringList; var pCnt: Integer;
  out StatusMsg: String; out IsDupSkip, IsDupFolder: Boolean): Boolean;
var
    SrcFile, DestFolder, DestFile, DupFile, CheckListFile: String;
    FolderFileList, CheckList: TStringList;
begin
    Result := False;
    StatusMsg := '';
    IsDupSkip := False;
    IsDupFolder := False;

    SrcFile := CurPath + FileName;
    DestFolder := IncludeTrailingPathDelimiter(Edit_target.Text + DstPath);
    DestFile := DestFolder + FileName;

    if not DirectoryExists(DestFolder) then begin
        ForceDirectories(DestFolder);
        pCnt := pCnt + 1;
    end;

    if chkContentDup.Checked then begin
        if chkGlobalDup.Checked and Assigned(GlobalFileList) then
            CheckList := GlobalFileList
        else
            CheckList := GetFolderFileList(DestFolder, FolderCache);

        if FindDuplicateInList(SrcFile, CheckList, DupFile) then begin
            CheckListFile := ExtractFileName(DupFile);
            if chkDupToFolder.Checked then begin
                if MoveToDupFolder(SrcFile, FileName, DestFile, StatusMsg) then begin
                    Result := True;
                    IsDupFolder := True;
                    StatusMsg := '중복폴더 이동 (' + CheckListFile + ')';
                    if Assigned(GlobalFileList) then
                        GlobalFileList.Add(DestFile);
                end;
            end
            else begin
                StatusMsg := '내용 중복 (' + CheckListFile + ')';
                IsDupSkip := True;
            end;
            Exit;
        end;
    end;

    if FileExists(DestFile) then begin
        if chkContentDup.Checked and chkDupToFolder.Checked and
           FilesAreIdentical(SrcFile, DestFile) then begin
            if MoveToDupFolder(SrcFile, FileName, DestFile, StatusMsg) then begin
                Result := True;
                IsDupFolder := True;
                StatusMsg := '중복폴더 이동 (파일명중복)';
                if Assigned(GlobalFileList) then
                    GlobalFileList.Add(DestFile);
            end;
        end
        else begin
            StatusMsg := '파일명 중복';
            IsDupSkip := True;
        end;
        Exit;
    end;

    if TransferFile(SrcFile, DestFile) then begin
        Result := True;
        if rdoMove.Checked then
            StatusMsg := '이동 완료'
        else
            StatusMsg := '복사 완료';

        if chkContentDup.Checked then begin
            if Assigned(GlobalFileList) then
                GlobalFileList.Add(DestFile)
            else begin
                FolderFileList := GetFolderFileList(DestFolder, FolderCache);
                FolderFileList.Add(DestFile);
            end;
        end;
    end
    else if rdoMove.Checked then
        StatusMsg := '이동 실패'
    else
        StatusMsg := '복사 실패';
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
   i, wCnt, pCnt, dupCnt, dupFolderCnt: Integer;
   ImgData: TImgData;
   DstPath, FileName, StatusMsg: String;
   FolderCache, GlobalFileList: TStringList;
   IsDupSkip, IsDupFolder: Boolean;
   j: Integer;
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
    dupCnt := 0;
    dupFolderCnt := 0;

    FolderCache := TStringList.Create;
    GlobalFileList := nil;
    try
        if chkContentDup.Checked and chkGlobalDup.Checked then begin
            GlobalFileList := TStringList.Create;
            CollectImageFiles(Edit_target.Text, GlobalFileList, GetDupFolderPath);
        end;

        ProgBar.Min := 0;
        ProgBar.Max := lsvFileList.Items.Count;
        for i := 0 to lsvFileList.Items.Count - 1 do begin
            FileName := lsvFileList.Items.Item[i].Caption;
            StatusMsg := '';
            ImgData := nil;
            IsDupSkip := False;
            IsDupFolder := False;
            if RadioButton2.Checked then begin
                DstPath := FormatDateTime('yyyy-MM-dd',
                  UNIXTimeToDateTimeFAST(StrToInt64(
                    StringReplace(FileName, ExtractFileExt(FileName), '',
                      [rfReplaceAll, rfIgnoreCase]))));

                ProcessOneFile(FileName, DstPath, FolderCache,
                  GlobalFileList, pCnt, StatusMsg, IsDupSkip, IsDupFolder);
            end
            else begin
                ImgData := TImgData.Create();
                if ImgData.ProcessFile(CurPath + FileName) then begin
                    if ImgData.HasEXIF = true then begin
                        DstPath := FormatDateTime('yyyy-MM-dd',
                          ImgData.ExifObj.GetImgDateTime);
                        ProcessOneFile(FileName, DstPath, FolderCache,
                          GlobalFileList, pCnt, StatusMsg, IsDupSkip, IsDupFolder);
                    end
                    else
                        StatusMsg := 'EXIF 없음';
                end
                else
                    StatusMsg := '파일 읽기 실패';
            end;

            if IsDupSkip then
                dupCnt := dupCnt + 1;
            if IsDupFolder then
                dupFolderCnt := dupFolderCnt + 1;

            if lsvFileList.Items.Item[i].SubItems.Count < 2 then
                lsvFileList.Items.Item[i].SubItems.Add('');
            lsvFileList.Items.Item[i].SubItems[1] := StatusMsg;

            wCnt := wCnt + 1;
            Label1.Caption := '작업 이미지 갯수 : ' + IntToStr(wCnt);
            Label2.Caption := '폴더 생성 갯수 : ' + IntToStr(pCnt);
            Label_DupCount.Caption := '중복 건너뜀 : ' + IntToStr(dupCnt);
            Label_DupFolderCount.Caption := '중복폴더 이동 : ' + IntToStr(dupFolderCnt);
            ProgBar.Position := ProgBar.Position + 1;

            if Assigned(ImgData) then
                ImgData.Free;
            Application.ProcessMessages;
        end;
    finally
        for j := 0 to FolderCache.Count - 1 do
            TStringList(FolderCache.Objects[j]).Free;
        FolderCache.Free;
        if Assigned(GlobalFileList) then
            GlobalFileList.Free;
    end;

    ShowMessage('작업완료' + LineEnding +
      '중복 건너뜀 : ' + IntToStr(dupCnt) + '건' + LineEnding +
      '중복폴더 이동 : ' + IntToStr(dupFolderCnt) + '건');
end;

procedure TfrmMain.Label3Click(Sender: TObject);
begin
    OpenURL('https://skshpapa80.github.io/');
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
   Edit_target.Text := '';
   lsvFileList.Items.Clear;
   Label_ImgCount.Caption := '총 이미지 : 0';
   Label1.Caption := '작업이미지 갯수 : 0';
   Label2.Caption := '폴더 생 갯수 : 0';
   Label_DupCount.Caption := '중복 건너뜀 : 0';
   Label_DupFolderCount.Caption := '중복폴더 이동 : 0';
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
          ListItem.SubItems.Add('');
      Until (FindNext(SearchRec) <> 0);
	  FindClose(SearchRec);
   end;
   lsvFileList.Items.EndUpdate;
   Label_ImgCount.Caption := '총 이미지 : ' + IntToStr(lsvFileList.Items.Count);
end;

end.

