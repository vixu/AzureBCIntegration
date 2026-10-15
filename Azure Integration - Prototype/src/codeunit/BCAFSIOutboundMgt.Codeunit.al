namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;
using System.Utilities;

codeunit 50115 "BCAFSI Outbound Mgt."
{
    // OnRun exports one entry; ProcessSelected calls it with Codeunit.Run so one failure doesn't stop the others.
    TableNo = "BCAFSI Outbound Staging";

    trigger OnRun()
    begin
        ExportEntry(Rec);
    end;

    var
        FailedCount: Integer;
        ProcessedCount: Integer;
        SkippedCount: Integer;
        SummaryMsg: Label '%1 file(s) created, %2 failed, %3 skipped.', Comment = '%1 = Processed, %2 = Failed, %3 = Skipped';
        HeaderTxt: Label 'DocumentNo|PostingDate|AccountNo|Amount|JournalBatch|JournalLineNo', Locked = true;

    // Called by the inbound flow after the journal lines are created: one Ready entry per inbound file.
    // The confirmation content is built now, so it doesn't depend on the journal lines still existing at export time.
    procedure CreateOutboundEntry(BCAFSIInboundStaging: Record "BCAFSI Inbound Staging")
    var
        BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging";
        GenJournalLine: Record "Gen. Journal Line";
        ContentOutStream: OutStream;
        ContentTextBuilder: TextBuilder;
    begin
        ContentTextBuilder.AppendLine(HeaderTxt);
        GenJournalLine.SetRange("BCAFSI Staging Entry No.", BCAFSIInboundStaging."Entry No.");
        if GenJournalLine.FindSet() then
            repeat
                ContentTextBuilder.AppendLine(
                    GenJournalLine."Document No." + '|' +
                    Format(GenJournalLine."Posting Date", 0, 9) + '|' +
                    GenJournalLine."Account No." + '|' +
                    Format(GenJournalLine.Amount, 0, 9) + '|' +
                    GenJournalLine."Journal Batch Name" + '|' +
                    Format(GenJournalLine."Line No."));
            until GenJournalLine.Next() = 0;

        BCAFSIOutboundStaging.Init();
        BCAFSIOutboundStaging."Integration Code" := BCAFSIInboundStaging."Integration Code";
        BCAFSIOutboundStaging."Inbound Entry No." := BCAFSIInboundStaging."Entry No.";
        BCAFSIOutboundStaging."Inbound File Name" := BCAFSIInboundStaging."File Name";
        BCAFSIOutboundStaging.Status := BCAFSIOutboundStaging.Status::Ready;
        BCAFSIOutboundStaging."No. of Lines" := BCAFSIInboundStaging."No. of Lines Created";
        BCAFSIOutboundStaging."Created At" := CurrentDateTime();
        BCAFSIOutboundStaging."File Content".CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText(ContentTextBuilder.ToText());
        BCAFSIOutboundStaging.Insert(true);
    end;

    // Used by the outbound staging page: Ready and Error entries are exported.
    procedure ProcessSelected(var BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging")
    var
        EntryNo: Integer;
        EntryNos: List of [Integer];
    begin
        BCAFSIOutboundStaging.SetLoadFields(Status);
        if BCAFSIOutboundStaging.FindSet() then
            repeat
                if BCAFSIOutboundStaging.Status in [BCAFSIOutboundStaging.Status::Ready, BCAFSIOutboundStaging.Status::Error] then
                    EntryNos.Add(BCAFSIOutboundStaging."Entry No.")
                else
                    SkippedCount += 1;
            until BCAFSIOutboundStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            ProcessEntry(EntryNo);
    end;

    procedure GetSummary(): Text
    begin
        exit(StrSubstNo(SummaryMsg, ProcessedCount, FailedCount, SkippedCount));
    end;

    local procedure ProcessEntry(EntryNo: Integer)
    var
        BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging";
    begin
        BCAFSIOutboundStaging.Get(EntryNo);
        BCAFSIOutboundStaging."Processed By" := CopyStr(UserId(), 1, MaxStrLen(BCAFSIOutboundStaging."Processed By"));
        BCAFSIOutboundStaging."Error Message" := '';
        BCAFSIOutboundStaging.Modify(true);
        Commit();

        ClearLastError();
        if Codeunit.Run(Codeunit::"BCAFSI Outbound Mgt.", BCAFSIOutboundStaging) then begin
            ProcessedCount += 1;
            exit;
        end;

        BCAFSIOutboundStaging.Get(EntryNo);
        BCAFSIOutboundStaging.Status := BCAFSIOutboundStaging.Status::Error;
        BCAFSIOutboundStaging."Error Message" := CopyStr(GetLastErrorText(), 1, MaxStrLen(BCAFSIOutboundStaging."Error Message"));
        BCAFSIOutboundStaging.Modify(true);
        Commit();
        FailedCount += 1;
    end;

    local procedure ExportEntry(var BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging")
    var
        BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup";
        BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
        TempBlob: Codeunit "Temp Blob";
        FileName: Text;
    begin
        BCAFSIIntegrationSetup.Get(BCAFSIOutboundStaging."Integration Code");
        BCAFSIIntegrationSetup.TestField("Outbound Folder");
        BCAFSIFileStorageMgt.Initialize(BCAFSIIntegrationSetup);

        BCAFSIOutboundStaging.CalcFields("File Content");
        TempBlob.FromRecord(BCAFSIOutboundStaging, BCAFSIOutboundStaging.FieldNo("File Content"));
        // e.g. OUT_12_BCAFSI_Sample_Valid.txt; the Entry No. keeps the name unique.
        FileName := 'OUT_' + Format(BCAFSIOutboundStaging."Entry No.") + '_' + RemoveExtension(BCAFSIOutboundStaging."Inbound File Name") + '.txt';
        BCAFSIFileStorageMgt.CreateFile(BCAFSIIntegrationSetup."Outbound Folder", FileName, TempBlob);

        BCAFSIOutboundStaging.Status := BCAFSIOutboundStaging.Status::Processed;
        BCAFSIOutboundStaging."File Name" := CopyStr(FileName, 1, MaxStrLen(BCAFSIOutboundStaging."File Name"));
        BCAFSIOutboundStaging."Processed At" := CurrentDateTime();
        BCAFSIOutboundStaging.Modify(true);
    end;

    local procedure RemoveExtension(FileName: Text): Text
    begin
        if FileName.LastIndexOf('.') = 0 then
            exit(FileName);
        exit(FileName.Substring(1, FileName.LastIndexOf('.') - 1));
    end;
}
