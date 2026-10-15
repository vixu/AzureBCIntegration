namespace Node4.BCAzureFileSharedIntegration;

page 50115 "BCAFSI Outbound Staging"
{
    AdditionalSearchTerms = 'BC Azure File Shared Integration, BCAFSI, Outbound Staging';
    ApplicationArea = All;
    Caption = 'Outbound BC Azure Integration';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "BCAFSI Outbound Staging";
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
                    ToolTip = 'Specifies the number of the outbound entry.';
                }
                field("Integration Code"; Rec."Integration Code")
                {
                    ToolTip = 'Specifies the integration that the entry belongs to.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ToolTip = 'Specifies the document number of the journal line.';
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the export status: Ready, Processing, Processed or Error.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    Style = Unfavorable;
                    ToolTip = 'Specifies why the last export attempt failed.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the posting date of the journal line.';
                }
                field("Account No."; Rec."Account No.")
                {
                    ToolTip = 'Specifies the account number of the journal line.';
                }
                field(Amount; Rec.Amount)
                {
                    ToolTip = 'Specifies the amount of the journal line.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the journal line.';
                }
                field("Inbound Entry No."; Rec."Inbound Entry No.")
                {
                    ToolTip = 'Specifies the inbound staging entry that created the journal line.';
                }
                field("Journal Template Name"; Rec."Journal Template Name")
                {
                    ToolTip = 'Specifies the journal template of the line.';
                    Visible = false;
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ToolTip = 'Specifies the journal batch of the line.';
                    Visible = false;
                }
                field("Journal Line No."; Rec."Journal Line No.")
                {
                    ToolTip = 'Specifies the line number of the journal line.';
                    Visible = false;
                }
                field("Created At"; Rec."Created At")
                {
                    ToolTip = 'Specifies when the outbound entry was created.';
                }
                field("Processed At"; Rec."Processed At")
                {
                    ToolTip = 'Specifies when the file was created in the outbound folder.';
                }
                field("Processed By"; Rec."Processed By")
                {
                    ToolTip = 'Specifies the user who last processed the entry.';
                }
                field("File Name"; Rec."File Name")
                {
                    ToolTip = 'Specifies the name of the file created in the outbound folder.';
                }
                field("File Path"; Rec."File Path")
                {
                    ToolTip = 'Specifies the full path of the file in the file share.';
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
                Image = ExportFile;
                ToolTip = 'Create a text file in the outbound folder for each selected Ready or Error entry.';

                trigger OnAction()
                var
                    BCAFSIOutboundStaging: Record "BCAFSI Outbound Staging";
                    BCAFSIOutboundMgt: Codeunit "BCAFSI Outbound Mgt.";
                begin
                    CurrPage.SetSelectionFilter(BCAFSIOutboundStaging);
                    BCAFSIOutboundMgt.ProcessSelected(BCAFSIOutboundStaging);
                    CurrPage.Update(false);
                    Message(BCAFSIOutboundMgt.GetSummary());
                end;
            }
        }
        area(Navigation)
        {
            action(InboundEntry)
            {
                Caption = 'Inbound Entry';
                Image = Import;
                RunObject = page "BCAFSI Inbound Staging";
                RunPageLink = "Entry No." = field("Inbound Entry No.");
                ToolTip = 'View the inbound staging entry that the journal line was created from.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Process_Promoted; Process) { }
                actionref(InboundEntry_Promoted; InboundEntry) { }
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
}
