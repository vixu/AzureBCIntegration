namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;

codeunit 50115 "BCAFSI Outbound Mgt."
{
    // Lets inbound users (and the Job Queue) create outbound entries without the outbound permission set.
    Permissions = tabledata "BCAFSI Outbound Staging" = RI;

    var
        FailedCount: Integer;
        ProcessedCount: Integer;
        SkippedCount: Integer;
        SummaryMsg: Label '%1 file(s) created, %2 failed, %3 skipped.', Comment = '%1 = Processed, %2 = Failed, %3 = Skipped';

    // Trigger point: a journal line created by the inbound flow adds one Ready outbound entry.
    // It runs in the same transaction as the journal line, so both commit or roll back together.
    [EventSubscriber(ObjectType::Table, Database::"Gen. Journal Line", 'OnAfterInsertEvent', '', false, false)]
    local procedure CreateOutboundOnGenJnlLineInsert(var Rec: Record "Gen. Journal Line"; RunTrigger: Boolean)
    var
        BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
        BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging";
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."BCAFSI Staging Entry No." = 0 then
            exit;

        BCAFSIInboundStaging.SetLoadFields("Integration Code");
        BCAFSIInboundStaging.Get(Rec."BCAFSI Staging Entry No.");

        BCAFSIOutboundStaging.Init();
        BCAFSIOutboundStaging."Integration Code" := BCAFSIInboundStaging."Integration Code";
        BCAFSIOutboundStaging."Document No." := Rec."Document No.";
        BCAFSIOutboundStaging.Status := BCAFSIOutboundStaging.Status::Ready;
        BCAFSIOutboundStaging."Posting Date" := Rec."Posting Date";
        BCAFSIOutboundStaging."Account No." := Rec."Account No.";
        BCAFSIOutboundStaging.Amount := Rec.Amount;
        BCAFSIOutboundStaging.Description := Rec.Description;
        BCAFSIOutboundStaging."Inbound Entry No." := Rec."BCAFSI Staging Entry No.";
        BCAFSIOutboundStaging."Journal Template Name" := Rec."Journal Template Name";
        BCAFSIOutboundStaging."Journal Batch Name" := Rec."Journal Batch Name";
        BCAFSIOutboundStaging."Journal Line No." := Rec."Line No.";
        BCAFSIOutboundStaging."Created At" := CurrentDateTime();
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
        BCAFSIOutboundStaging.ReadIsolation(IsolationLevel::UpdLock);
        BCAFSIOutboundStaging.Get(EntryNo);
        if not (BCAFSIOutboundStaging.Status in [BCAFSIOutboundStaging.Status::Ready, BCAFSIOutboundStaging.Status::Error]) then begin
            SkippedCount += 1;
            exit;
        end;

        BCAFSIOutboundStaging.Status := BCAFSIOutboundStaging.Status::Processing;
        BCAFSIOutboundStaging."Processed By" := CopyStr(UserId(), 1, MaxStrLen(BCAFSIOutboundStaging."Processed By"));
        BCAFSIOutboundStaging."Error Message" := '';
        BCAFSIOutboundStaging.Modify(true);
        // Commit the Processing status so each entry runs in its own isolated transaction below.
        Commit();

        ClearLastError();
        if Codeunit.Run(Codeunit::"BCAFSI Outbound Export Entry", BCAFSIOutboundStaging) then begin
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
}
