namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;

page 50111 "BCAFSI Inbound Staging"
{
    AdditionalSearchTerms = 'BC Azure File Shared Integration, BCAFSI, Inbound Staging';
    ApplicationArea = All;
    Caption = 'Inbound BC Azure Integration';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "BCAFSI Inbound Staging";
    SourceTableView = sorting("Entry No.") order(descending);
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the number of the staging entry.';
                }
                field("Integration Code"; Rec."Integration Code")
                {
                    ToolTip = 'Specifies the integration that fetched the file.';
                }
                field("File Name"; Rec."File Name")
                {
                    ToolTip = 'Specifies the name of the file in the inbound folder.';
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the processing status of the file: Ready, Processing, Processed or Error.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    Style = Unfavorable;
                    ToolTip = 'Specifies why the last processing attempt failed.';
                }
                field("No. of Lines Created"; Rec."No. of Lines Created")
                {
                    ToolTip = 'Specifies how many general journal lines were created from the file.';

                    trigger OnDrillDown()
                    begin
                        ShowJournalLines();
                    end;
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies how many processing attempts have failed.';
                }
                field("File Size"; Rec."File Size")
                {
                    ToolTip = 'Specifies the size of the file in bytes.';
                    Visible = false;
                }
                field("Received At"; Rec."Received At")
                {
                    ToolTip = 'Specifies when the file was copied to staging.';
                }
                field("Processed At"; Rec."Processed At")
                {
                    ToolTip = 'Specifies when the journal lines were created.';
                }
                field("Processed By"; Rec."Processed By")
                {
                    ToolTip = 'Specifies the user who last processed the file.';
                }
                field("Archived File Path"; Rec."Archived File Path")
                {
                    ToolTip = 'Specifies where the file was archived in the file share.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Process)
            {
                Caption = 'Process';
                Image = PostBatch;
                ToolTip = 'Create general journal lines from the selected Ready or Error entries.';

                trigger OnAction()
                var
                    BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
                    BCAFSIProcessStaging: Codeunit "BCAFSI Process Staging";
                begin
                    CurrPage.SetSelectionFilter(BCAFSIInboundStaging);
                    BCAFSIProcessStaging.ProcessSelected(BCAFSIInboundStaging);
                    CurrPage.Update(false);
                    Message(BCAFSIProcessStaging.GetSummary());
                end;
            }
            action(ResetToReady)
            {
                Caption = 'Reset to Ready';
                Image = ResetStatus;
                ToolTip = 'Set the selected Error or Processing entries back to Ready so they are processed again.';

                trigger OnAction()
                begin
                    ResetSelectedToReady();
                end;
            }
            action(ViewContent)
            {
                Caption = 'View Content';
                Image = View;
                ToolTip = 'Show the first lines of the staged file.';

                trigger OnAction()
                begin
                    Rec.ShowContent();
                end;
            }
            action(DownloadContent)
            {
                Caption = 'Download Content';
                Image = Download;
                ToolTip = 'Download the staged file.';

                trigger OnAction()
                begin
                    Rec.DownloadContent();
                end;
            }
        }
        area(Navigation)
        {
            action(ShowJournalLinesAction)
            {
                Caption = 'Show Created Journal Lines';
                Image = GeneralLedger;
                ToolTip = 'View the general journal lines that were created from this file.';

                trigger OnAction()
                begin
                    ShowJournalLines();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Process_Promoted; Process) { }
                actionref(ResetToReady_Promoted; ResetToReady) { }
            }
            group(Category_Content)
            {
                Caption = 'Content';

                actionref(ViewContent_Promoted; ViewContent) { }
                actionref(DownloadContent_Promoted; DownloadContent) { }
                actionref(ShowJournalLines_Promoted; ShowJournalLinesAction) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Processed:
                StatusStyle := Format(PageStyle::Favorable);
            Rec.Status::Error:
                StatusStyle := Format(PageStyle::Unfavorable);
            Rec.Status::Processing:
                StatusStyle := Format(PageStyle::Ambiguous);
            else
                StatusStyle := Format(PageStyle::Standard);
        end;
    end;

    var
        StatusStyle: Text;

    local procedure ResetSelectedToReady()
    var
        BCAFSIInboundStaging: Record "BCAFSI Inbound Staging";
        ResetCount: Integer;
        ResetMsg: Label '%1 entry(ies) reset to Ready.', Comment = '%1 = Number of entries';
    begin
        CurrPage.SetSelectionFilter(BCAFSIInboundStaging);
        BCAFSIInboundStaging.SetFilter(Status, '%1|%2', BCAFSIInboundStaging.Status::Error, BCAFSIInboundStaging.Status::Processing);
        if BCAFSIInboundStaging.FindSet(true) then
            repeat
                BCAFSIInboundStaging.Status := BCAFSIInboundStaging.Status::Ready;
                BCAFSIInboundStaging."Error Message" := '';
                BCAFSIInboundStaging.Modify(true);
                ResetCount += 1;
            until BCAFSIInboundStaging.Next() = 0;
        CurrPage.Update(false);
        Message(ResetMsg, ResetCount);
    end;

    local procedure ShowJournalLines()
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.SetRange("BCAFSI Staging Entry No.", Rec."Entry No.");
        Page.Run(Page::"BCAFSI Created Jnl. Lines", GenJournalLine);
    end;
}
