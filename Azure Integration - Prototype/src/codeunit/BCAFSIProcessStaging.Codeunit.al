namespace Node4.BCAzureFileSharedIntegration;

codeunit 50113 "BCAFSI Process Staging"
{
    var
        FailedCount: Integer;
        ProcessedCount: Integer;
        SkippedCount: Integer;
        SummaryMsg: Label '%1 file(s) processed, %2 file(s) failed, %3 skipped.', Comment = '%1 = Processed, %2 = Failed, %3 = Skipped';

    // Used by the setup page and the Job Queue: Ready entries plus Error entries still under "Max. Retries".
    procedure ProcessIntegration(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
        EntryNo: Integer;
        EntryNos: List of [Integer];
    begin
        BCAFSIInboundStaging.SetLoadFields(Status, "Retry Count");
        BCAFSIInboundStaging.SetCurrentKey("Integration Code", Status);
        BCAFSIInboundStaging.SetRange("Integration Code", BCAFSIIntegrationSetup.Code);
        BCAFSIInboundStaging.SetFilter(Status, '%1|%2', BCAFSIInboundStaging.Status::Ready, BCAFSIInboundStaging.Status::Error);
        if BCAFSIInboundStaging.FindSet() then
            repeat
                if (BCAFSIInboundStaging.Status = BCAFSIInboundStaging.Status::Ready) or
                   (BCAFSIInboundStaging."Retry Count" < BCAFSIIntegrationSetup."Max. Retries")
                then
                    EntryNos.Add(BCAFSIInboundStaging."Entry No.");
            until BCAFSIInboundStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            ProcessEntry(EntryNo);
    end;

    // Used by the staging page: Ready and Error entries are processed regardless of "Max. Retries".
    procedure ProcessSelected(var BCAFSIInboundStaging: Record "BCAFSI Inbound Staging")
    var
        EntryNo: Integer;
        EntryNos: List of [Integer];
    begin
        BCAFSIInboundStaging.SetLoadFields(Status);
        if BCAFSIInboundStaging.FindSet() then
            repeat
                if BCAFSIInboundStaging.Status in [BCAFSIInboundStaging.Status::Ready, BCAFSIInboundStaging.Status::Error] then
                    EntryNos.Add(BCAFSIInboundStaging."Entry No.")
                else
                    SkippedCount += 1;
            until BCAFSIInboundStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            ProcessEntry(EntryNo);
    end;

    procedure GetSummary(): Text
    begin
        exit(StrSubstNo(SummaryMsg, ProcessedCount, FailedCount, SkippedCount));
    end;

    procedure GetFailedCount(): Integer
    begin
        exit(FailedCount);
    end;

    local procedure ProcessEntry(EntryNo: Integer)
    var
        BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        BCAFSIInboundStaging.ReadIsolation(IsolationLevel::UpdLock);
        BCAFSIInboundStaging.Get(EntryNo);
        if not (BCAFSIInboundStaging.Status in [BCAFSIInboundStaging.Status::Ready, BCAFSIInboundStaging.Status::Error]) then begin
            SkippedCount += 1;
            exit;
        end;

        BCAFSIInboundStaging.Status := BCAFSIInboundStaging.Status::Processing;
        BCAFSIInboundStaging."Processed By" := CopyStr(UserId(), 1, MaxStrLen(BCAFSIInboundStaging."Processed By"));
        BCAFSIInboundStaging."Error Message" := '';
        BCAFSIInboundStaging.Modify(true);
        // Commit the Processing status so each entry runs in its own isolated transaction below.
        Commit();

        ClearLastError();
        if Codeunit.Run(Codeunit::"BCAFSI Process Staging Entry", BCAFSIInboundStaging) then begin
            ProcessedCount += 1;
            exit;
        end;

        BCAFSIInboundStaging.Get(EntryNo);
        BCAFSIInboundStaging.Status := BCAFSIInboundStaging.Status::Error;
        BCAFSIInboundStaging."Error Message" := CopyStr(GetLastErrorText(), 1, MaxStrLen(BCAFSIInboundStaging."Error Message"));
        BCAFSIInboundStaging."Retry Count" += 1;
        BCAFSIInboundStaging.Modify(true);
        Commit();
        FailedCount += 1;

        CustomDimensions.Add('Category', 'BCAFSI Process');
        CustomDimensions.Add('IntegrationCode', BCAFSIInboundStaging."Integration Code");
        CustomDimensions.Add('EntryNo', Format(EntryNo));
        CustomDimensions.Add('RetryCount', Format(BCAFSIInboundStaging."Retry Count"));
        Session.LogMessage('BCAFSI-0001', 'Staging entry failed to process.', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
