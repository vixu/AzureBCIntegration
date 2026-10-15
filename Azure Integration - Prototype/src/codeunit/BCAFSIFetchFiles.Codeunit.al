namespace Node4.BCAzureFileSharedIntegration;

using System.ExternalFileStorage;
using System.Utilities;

codeunit 50111 "BCAFSI Fetch Files"
{
    TableNo = "BCAFSI Integration Setup";

    trigger OnRun()
    begin
        FetchFiles(Rec);
    end;

    var
        BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
        ArchiveFailedCount: Integer;
        DuplicateCount: Integer;
        ReadFailedCount: Integer;
        StagedCount: Integer;
        LastMoveErrorMsg: Label '\\Last move error: %1', Comment = '%1 = Error text';
        SummaryMsg: Label 'Integration %1:\%2 file(s) staged\%3 duplicate(s) archived without staging\%4 file(s) moved to the Error folder\%5 file(s) could not be moved', Comment = '%1 = Integration code, %2 = Staged, %3 = Duplicates, %4 = Read failures, %5 = Move failures';
        LastMoveError: Text;

    procedure GetSummary(IntegrationCode: Code[20]): Text
    var
        Summary: Text;
    begin
        Summary := StrSubstNo(SummaryMsg, IntegrationCode, StagedCount, DuplicateCount, ReadFailedCount, ArchiveFailedCount);
        if LastMoveError <> '' then
            Summary += StrSubstNo(LastMoveErrorMsg, LastMoveError);
        exit(Summary);
    end;

    local procedure FetchFiles(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        TempFileAccountContent: Record "File Account Content" temporary;
    begin
        BCAFSIIntegrationSetup.TestField(Enabled, true);
        BCAFSIIntegrationSetup.CheckReadyToRun();
        BCAFSIFileStorageMgt.Initialize(BCAFSIIntegrationSetup);

        BCAFSIFileStorageMgt.ListFiles(BCAFSIIntegrationSetup."Inbound Folder", TempFileAccountContent);
        TempFileAccountContent.SetRange(Type, TempFileAccountContent.Type::File);
        if BCAFSIIntegrationSetup."File Name Filter" <> '' then
            TempFileAccountContent.SetFilter(Name, BCAFSIIntegrationSetup."File Name Filter");
        if TempFileAccountContent.FindSet() then
            repeat
                FetchFile(BCAFSIIntegrationSetup, TempFileAccountContent.Name);
            until TempFileAccountContent.Next() = 0;
    end;

    local procedure FetchFile(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; FileName: Text)
    var
        BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
        TempBlob: Codeunit "Temp Blob";
        SourcePath: Text;
        TargetPath: Text;
    begin
        SourcePath := BCAFSIFileStorageMgt.CombinePath(BCAFSIIntegrationSetup."Inbound Folder", FileName);

        if IsAlreadyStaged(BCAFSIIntegrationSetup.Code, FileName) then begin
            DuplicateCount += 1;
            MoveFile(BCAFSIIntegrationSetup, SourcePath, BCAFSIIntegrationSetup."Archive Folder", FileName, TargetPath);
            exit;
        end;

        if (StrLen(FileName) > MaxStrLen(BCAFSIInboundStaging."File Name")) or
           (not BCAFSIFileStorageMgt.TryReadFile(SourcePath, TempBlob))
        then begin
            ReadFailedCount += 1;
            LogFetchIssue('BCAFSI-0002', 'File could not be read and was moved to the Error folder.', BCAFSIIntegrationSetup.Code);
            MoveFile(BCAFSIIntegrationSetup, SourcePath, BCAFSIIntegrationSetup."Error Folder", FileName, TargetPath);
            exit;
        end;

        InsertStaging(BCAFSIIntegrationSetup.Code, FileName, TempBlob, BCAFSIInboundStaging);
        // Commit the staged record before moving the file, so a failed move cannot lose the content.
        Commit();
        StagedCount += 1;

        if MoveFile(BCAFSIIntegrationSetup, SourcePath, BCAFSIIntegrationSetup."Archive Folder", FileName, TargetPath) then begin
            BCAFSIInboundStaging."Archived File Path" := CopyStr(TargetPath, 1, MaxStrLen(BCAFSIInboundStaging."Archived File Path"));
            BCAFSIInboundStaging.Modify(true);
            Commit();
        end;
    end;

    local procedure IsAlreadyStaged(IntegrationCode: Code[20]; FileName: Text): Boolean
    var
        BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
    begin
        BCAFSIInboundStaging.SetRange("Integration Code", IntegrationCode);
        BCAFSIInboundStaging.SetRange("File Name", FileName);
        exit(not BCAFSIInboundStaging.IsEmpty());
    end;

    local procedure InsertStaging(IntegrationCode: Code[20]; FileName: Text; var TempBlob: Codeunit "Temp Blob"; var BCAFSIInboundStaging: Record "BCAFSI Inbound Staging")
    var
        ContentInStream: InStream;
        ContentOutStream: OutStream;
    begin
        BCAFSIInboundStaging.Init();
        BCAFSIInboundStaging."Integration Code" := IntegrationCode;
        BCAFSIInboundStaging."File Name" := CopyStr(FileName, 1, MaxStrLen(BCAFSIInboundStaging."File Name"));
        BCAFSIInboundStaging."File Size" := TempBlob.Length();
        BCAFSIInboundStaging."Received At" := CurrentDateTime();
        BCAFSIInboundStaging.Status := BCAFSIInboundStaging.Status::Ready;
        TempBlob.CreateInStream(ContentInStream);
        BCAFSIInboundStaging."File Content".CreateOutStream(ContentOutStream);
        CopyStream(ContentOutStream, ContentInStream);
        BCAFSIInboundStaging.Insert(true);
    end;

    local procedure MoveFile(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; SourcePath: Text; TargetFolder: Text; FileName: Text; var TargetPath: Text): Boolean
    begin
        if BCAFSIFileStorageMgt.TryMoveToFolder(SourcePath, TargetFolder, FileName, TargetPath) then
            exit(true);
        LastMoveError := GetLastErrorText();
        ArchiveFailedCount += 1;
        LogFetchIssue('BCAFSI-0003', 'File could not be moved.', BCAFSIIntegrationSetup.Code);
        exit(false);
    end;

    local procedure LogFetchIssue(EventId: Text; MessageText: Text; IntegrationCode: Code[20])
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('Category', 'BCAFSI Fetch');
        CustomDimensions.Add('IntegrationCode', IntegrationCode);
        CustomDimensions.Add('CompanyName', CompanyName());
        Session.LogMessage(EventId, MessageText, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
