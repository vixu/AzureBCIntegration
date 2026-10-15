namespace Node4.BCAzureFileSharedIntegration;

using System.Threading;

codeunit 50114 "BCAFSI Job Queue Handler"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        RunIntegrations(Rec."Parameter String");
    end;

    var
        JobQueueDescriptionTxt: Label 'BC Azure File Shared Integration %1', Comment = '%1 = Integration code';

    // ParameterString = Integration Code; empty runs all enabled integrations.
    procedure RunIntegrations(ParameterString: Text)
    var
        BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup";
        IntegrationErr: Label 'Integration %1: %2', Comment = '%1 = Integration code, %2 = Error text';
        FetchError: Text;
        ErrorTextBuilder: TextBuilder;
    begin
        if ParameterString <> '' then
            BCAFSIIntegrationSetup.SetRange(Code, CopyStr(ParameterString, 1, MaxStrLen(BCAFSIIntegrationSetup.Code)))
        else
            BCAFSIIntegrationSetup.SetRange(Enabled, true);
        BCAFSIIntegrationSetup.FindSet();

        repeat
            if not RunIntegration(BCAFSIIntegrationSetup, FetchError) then
                ErrorTextBuilder.AppendLine(StrSubstNo(IntegrationErr, BCAFSIIntegrationSetup.Code, FetchError));
        until BCAFSIIntegrationSetup.Next() = 0;

        // Surface fetch failures in the Job Queue log after all integrations have run.
        if ErrorTextBuilder.Length() > 0 then
            Error(ErrorTextBuilder.ToText());
    end;

    procedure CreateJobQueueEntry(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"BCAFSI Job Queue Handler");
        JobQueueEntry.SetRange("Parameter String", BCAFSIIntegrationSetup.Code);
        if not JobQueueEntry.FindFirst() then begin
            JobQueueEntry.Init();
            JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
            JobQueueEntry."Object ID to Run" := Codeunit::"BCAFSI Job Queue Handler";
            JobQueueEntry."Parameter String" := BCAFSIIntegrationSetup.Code;
            JobQueueEntry.Description := CopyStr(StrSubstNo(JobQueueDescriptionTxt, BCAFSIIntegrationSetup.Code), 1, MaxStrLen(JobQueueEntry.Description));
            JobQueueEntry."Recurring Job" := true;
            JobQueueEntry."Run on Mondays" := true;
            JobQueueEntry."Run on Tuesdays" := true;
            JobQueueEntry."Run on Wednesdays" := true;
            JobQueueEntry."Run on Thursdays" := true;
            JobQueueEntry."Run on Fridays" := true;
            JobQueueEntry."Run on Saturdays" := true;
            JobQueueEntry."Run on Sundays" := true;
            JobQueueEntry."No. of Minutes between Runs" := 15;
            JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
            JobQueueEntry.Insert(true);
        end;
        Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
    end;

    local procedure RunIntegration(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; var FetchError: Text): Boolean
    var
        BCAFSIFetchFiles: Codeunit "BCAFSI Fetch Files";
        BCAFSIProcessStaging: Codeunit "BCAFSI Process Staging";
        FetchSucceeded: Boolean;
    begin
        Commit();
        ClearLastError();
        FetchSucceeded := BCAFSIFetchFiles.Run(BCAFSIIntegrationSetup);
        FetchError := GetLastErrorText();
        // Process already-staged entries even when this run's fetch failed.
        BCAFSIProcessStaging.ProcessIntegration(BCAFSIIntegrationSetup);
        exit(FetchSucceeded);
    end;
}
