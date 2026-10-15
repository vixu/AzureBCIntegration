namespace Node4.BCAzureFileSharedIntegration;

using System.ExternalFileStorage;
using System.Utilities;

codeunit 50110 "BCAFSI File Storage Mgt."
{
    var
        ExternalFileStorage: Codeunit "External File Storage";
        AccountNotFoundErr: Label 'The file account %1 used by integration %2 no longer exists. Select another file account.', Comment = '%1 = File account name, %2 = Integration code';
        AccountNameNotFoundErr: Label 'There is no external file account named %1.', Comment = '%1 = File account name';
        ConnectionFailedErr: Label 'Connection to file account %1 failed.\\%2', Comment = '%1 = File account name, %2 = Error text';
        ConnectionOkMsg: Label 'Connection to file account %1 succeeded. All folders exist.', Comment = '%1 = File account name';
        FoldersMissingMsg: Label 'Connection to file account %1 succeeded, but these folders do not exist:\%2', Comment = '%1 = File account name, %2 = List of folders';
        SelectFolderLbl: Label 'Select a folder';

    procedure Initialize(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        TempFileAccount: Record "File Account" temporary;
    begin
        BCAFSIIntegrationSetup.TestField("File Account Name");
        if not FindFileAccount(BCAFSIIntegrationSetup, TempFileAccount) then
            Error(AccountNotFoundErr, BCAFSIIntegrationSetup."File Account Name", BCAFSIIntegrationSetup.Code);
        ExternalFileStorage.Initialize(TempFileAccount);
    end;

    procedure LookupFileAccount(var BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        TempFileAccount: Record "File Account" temporary;
        FileAccounts: Page "File Accounts";
    begin
        if FindFileAccount(BCAFSIIntegrationSetup, TempFileAccount) then
            FileAccounts.SetAccount(TempFileAccount);
        FileAccounts.EnableLookupMode();
        if FileAccounts.RunModal() <> Action::LookupOK then
            exit;

        FileAccounts.GetAccount(TempFileAccount);
        SetFileAccount(BCAFSIIntegrationSetup, TempFileAccount);
    end;

    procedure ValidateFileAccountName(var BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        TempFileAccount: Record "File Account" temporary;
        FileAccount: Codeunit "File Account";
    begin
        if BCAFSIIntegrationSetup."File Account Name" = '' then begin
            Clear(BCAFSIIntegrationSetup."File Account Id");
            Clear(BCAFSIIntegrationSetup."File Account Connector");
            exit;
        end;

        FileAccount.GetAllAccounts(false, TempFileAccount);
        TempFileAccount.SetRange(Name, BCAFSIIntegrationSetup."File Account Name");
        if not TempFileAccount.FindFirst() then
            Error(AccountNameNotFoundErr, BCAFSIIntegrationSetup."File Account Name");
        SetFileAccount(BCAFSIIntegrationSetup, TempFileAccount);
    end;

    procedure TestConnection(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        MissingFolders: Text;
    begin
        Initialize(BCAFSIIntegrationSetup);
        if not TryCheckFolders(BCAFSIIntegrationSetup, MissingFolders) then
            Error(ConnectionFailedErr, BCAFSIIntegrationSetup."File Account Name", GetLastErrorText());

        if MissingFolders <> '' then
            Message(FoldersMissingMsg, BCAFSIIntegrationSetup."File Account Name", MissingFolders)
        else
            Message(ConnectionOkMsg, BCAFSIIntegrationSetup."File Account Name");
    end;

    procedure BrowseShare(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    begin
        Initialize(BCAFSIIntegrationSetup);
        ExternalFileStorage.BrowseAccount();
    end;

    procedure SelectFolder(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; CurrentFolder: Text): Text
    var
        StartFolder: Text;
    begin
        Initialize(BCAFSIIntegrationSetup);
        if (CurrentFolder <> '') and ExternalFileStorage.DirectoryExists(CurrentFolder) then
            StartFolder := CurrentFolder;
        exit(ExternalFileStorage.SelectAndGetFolderPath(StartFolder, SelectFolderLbl).TrimEnd('/'));
    end;

    procedure ListFiles(Folder: Text; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        FilePaginationData: Codeunit "File Pagination Data";
    begin
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        repeat
            ExternalFileStorage.ListFiles(Folder, FilePaginationData, TempFileAccountContent);
        until FilePaginationData.IsEndOfListing();
    end;

    procedure CombinePath(Folder: Text; FileName: Text): Text
    begin
        exit(ExternalFileStorage.CombinePath(Folder, FileName));
    end;

    [TryFunction]
    procedure TryReadFile(FilePath: Text; var TempBlob: Codeunit "Temp Blob")
    var
        SourceInStream: InStream;
        BlobOutStream: OutStream;
    begin
        ExternalFileStorage.GetFile(FilePath, SourceInStream);
        TempBlob.CreateOutStream(BlobOutStream);
        CopyStream(BlobOutStream, SourceInStream);
    end;

    // Creates FileName in Folder and returns its path. Fails if the file already exists.
    procedure CreateFile(Folder: Text; FileName: Text; var TempBlob: Codeunit "Temp Blob"): Text
    var
        ContentInStream: InStream;
        FilePath: Text;
        FileExistsErr: Label 'The file %1 already exists.', Comment = '%1 = File path';
    begin
        FilePath := ExternalFileStorage.CombinePath(Folder, FileName);
        if ExternalFileStorage.FileExists(FilePath) then
            Error(FileExistsErr, FilePath);
        TempBlob.CreateInStream(ContentInStream);
        ExternalFileStorage.CreateFile(FilePath, ContentInStream);
        exit(FilePath);
    end;

    // On a name clash in TargetFolder, a _yyyyMMddHHmmss (UTC) suffix is added instead of overwriting.
    [TryFunction]
    procedure TryMoveToFolder(SourcePath: Text; TargetFolder: Text; FileName: Text; var TargetPath: Text)
    begin
        TargetPath := ExternalFileStorage.CombinePath(TargetFolder, FileName);
        if ExternalFileStorage.FileExists(TargetPath) then
            TargetPath := ExternalFileStorage.CombinePath(TargetFolder, AddTimestampSuffix(FileName));
        // Not MoveFile: the File Share connector passes source/target to AFS RenameFile in reverse order, so it always fails.
        ExternalFileStorage.CopyFile(SourcePath, TargetPath);
        ExternalFileStorage.DeleteFile(SourcePath);
    end;

    local procedure AddTimestampSuffix(FileName: Text): Text
    var
        DotPosition: Integer;
        Timestamp: Text;
    begin
        Timestamp := CopyStr(DelChr(Format(CurrentDateTime(), 0, 9), '=', '-:TZ'), 1, 14);
        DotPosition := FileName.LastIndexOf('.');
        if DotPosition = 0 then
            exit(FileName + '_' + Timestamp);
        exit(FileName.Substring(1, DotPosition - 1) + '_' + Timestamp + FileName.Substring(DotPosition));
    end;

    [TryFunction]
    local procedure TryCheckFolders(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; var MissingFolders: Text)
    begin
        MissingFolders := '';
        CheckFolder(BCAFSIIntegrationSetup."Inbound Folder", MissingFolders);
        CheckFolder(BCAFSIIntegrationSetup."Archive Folder", MissingFolders);
        CheckFolder(BCAFSIIntegrationSetup."Error Folder", MissingFolders);
        CheckFolder(BCAFSIIntegrationSetup."Outbound Folder", MissingFolders);
    end;

    local procedure CheckFolder(Folder: Text; var MissingFolders: Text)
    begin
        if Folder = '' then
            exit;
        if not ExternalFileStorage.DirectoryExists(Folder) then
            MissingFolders += '\- ' + Folder;
    end;

    local procedure FindFileAccount(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; var TempFileAccount: Record "File Account" temporary): Boolean
    var
        FileAccount: Codeunit "File Account";
    begin
        if IsNullGuid(BCAFSIIntegrationSetup."File Account Id") then
            exit(false);
        FileAccount.GetAllAccounts(false, TempFileAccount);
        exit(TempFileAccount.Get(BCAFSIIntegrationSetup."File Account Id", BCAFSIIntegrationSetup."File Account Connector"));
    end;

    local procedure SetFileAccount(var BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; TempFileAccount: Record "File Account" temporary)
    begin
        BCAFSIIntegrationSetup."File Account Id" := TempFileAccount."Account Id";
        BCAFSIIntegrationSetup."File Account Connector" := TempFileAccount.Connector;
        BCAFSIIntegrationSetup."File Account Name" := TempFileAccount.Name;
    end;
}
