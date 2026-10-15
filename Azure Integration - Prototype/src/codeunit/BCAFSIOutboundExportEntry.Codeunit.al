namespace Node4.BCAzureFileSharedIntegration;

using System.ExternalFileStorage;
using System.Utilities;

codeunit 50116 "BCAFSI Outbound Export Entry"
{
    TableNo = "BCAFSI Outbound Staging";

    trigger OnRun()
    begin
        ExportEntry(Rec);
    end;

    var
        ExternalFileStorage: Codeunit "External File Storage";
        AccountNotFoundErr: Label 'The file account %1 used by integration %2 no longer exists. Select another file account.', Comment = '%1 = File account name, %2 = Integration code';
        FileExistsErr: Label 'The file %1 already exists in the outbound folder.', Comment = '%1 = File path';
        FolderMissingErr: Label 'The outbound folder %1 does not exist in the file share.', Comment = '%1 = Folder';
        UnexpectedStatusErr: Label 'Outbound entry %1 must have status %2 to be exported.', Comment = '%1 = Entry No., %2 = Status';
        HeaderTxt: Label 'EntryNo|IntegrationCode|DocumentNo|PostingDate|AccountNo|Amount|Description|InboundEntryNo', Locked = true;

    local procedure ExportEntry(var BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging")
    var
        BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup";
        TempBlob: Codeunit "Temp Blob";
        ContentInStream: InStream;
        FileName: Text;
        FilePath: Text;
    begin
        if BCAFSIOutboundStaging.Status <> BCAFSIOutboundStaging.Status::Processing then
            Error(UnexpectedStatusErr, BCAFSIOutboundStaging."Entry No.", BCAFSIOutboundStaging.Status::Processing);

        BCAFSIIntegrationSetup.Get(BCAFSIOutboundStaging."Integration Code");
        BCAFSIIntegrationSetup.TestField("Outbound Folder");
        Initialize(BCAFSIIntegrationSetup);

        if not ExternalFileStorage.DirectoryExists(BCAFSIIntegrationSetup."Outbound Folder") then
            Error(FolderMissingErr, BCAFSIIntegrationSetup."Outbound Folder");

        FileName := GetFileName(BCAFSIOutboundStaging);
        FilePath := ExternalFileStorage.CombinePath(BCAFSIIntegrationSetup."Outbound Folder", FileName);
        if ExternalFileStorage.FileExists(FilePath) then
            Error(FileExistsErr, FilePath);

        WriteContent(BCAFSIOutboundStaging, TempBlob);
        TempBlob.CreateInStream(ContentInStream);
        ExternalFileStorage.CreateFile(FilePath, ContentInStream);

        BCAFSIOutboundStaging.Status := BCAFSIOutboundStaging.Status::Processed;
        BCAFSIOutboundStaging."File Name" := CopyStr(FileName, 1, MaxStrLen(BCAFSIOutboundStaging."File Name"));
        BCAFSIOutboundStaging."File Path" := CopyStr(FilePath, 1, MaxStrLen(BCAFSIOutboundStaging."File Path"));
        BCAFSIOutboundStaging."Processed At" := CurrentDateTime();
        BCAFSIOutboundStaging."Error Message" := '';
        BCAFSIOutboundStaging.Modify(true);
    end;

    local procedure Initialize(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        TempFileAccount: Record "File Account" temporary;
        FileAccount: Codeunit "File Account";
    begin
        BCAFSIIntegrationSetup.TestField("File Account Name");
        FileAccount.GetAllAccounts(false, TempFileAccount);
        if not TempFileAccount.Get(BCAFSIIntegrationSetup."File Account Id", BCAFSIIntegrationSetup."File Account Connector") then
            Error(AccountNotFoundErr, BCAFSIIntegrationSetup."File Account Name", BCAFSIIntegrationSetup.Code);
        ExternalFileStorage.Initialize(TempFileAccount);
    end;

    // OUT_<DocumentNo>_<EntryNo>.txt; the Entry No. keeps the name unique.
    local procedure GetFileName(BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging"): Text
    begin
        exit('OUT_' + DelChr(BCAFSIOutboundStaging."Document No.", '=', '\/:*?"<>| ') + '_' + Format(BCAFSIOutboundStaging."Entry No.") + '.txt');
    end;

    // Header row plus one data row, pipe separated, UTF-8. Dates and amounts use the XML format (YYYY-MM-DD, '.' decimals).
    local procedure WriteContent(BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging"; var TempBlob: Codeunit "Temp Blob")
    var
        ContentOutStream: OutStream;
        ContentTextBuilder: TextBuilder;
    begin
        ContentTextBuilder.AppendLine(HeaderTxt);
        ContentTextBuilder.AppendLine(
            Format(BCAFSIOutboundStaging."Entry No.") + '|' +
            BCAFSIOutboundStaging."Integration Code" + '|' +
            BCAFSIOutboundStaging."Document No." + '|' +
            Format(BCAFSIOutboundStaging."Posting Date", 0, 9) + '|' +
            BCAFSIOutboundStaging."Account No." + '|' +
            Format(BCAFSIOutboundStaging.Amount, 0, 9) + '|' +
            BCAFSIOutboundStaging.Description + '|' +
            Format(BCAFSIOutboundStaging."Inbound Entry No."));

        TempBlob.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText(ContentTextBuilder.ToText());
    end;
}
