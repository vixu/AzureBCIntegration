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
                field("Inbound Entry No."; Rec."Inbound Entry No.")
                {
                    ToolTip = 'Specifies the inbound staging entry that the journal lines were created from.';
                }
                field("Inbound File Name"; Rec."Inbound File Name")
                {
                    ToolTip = 'Specifies the inbound file that the journal lines were created from.';
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the export status: Ready, Processed or Error.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    Style = Unfavorable;
                    ToolTip = 'Specifies why the last export attempt failed.';
                }
                field("No. of Lines"; Rec."No. of Lines")
                {
                    ToolTip = 'Specifies how many journal lines the confirmation file lists.';
                }
                field("File Name"; Rec."File Name")
                {
                    ToolTip = 'Specifies the name of the file created in the outbound folder.';
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
                ToolTip = 'Create the confirmation file in the outbound folder for each selected Ready or Error entry.';

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
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Process_Promoted; Process) { }
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
            else
                StatusStyle := Format(PageStyle::Standard);
        end;
    end;

    var
        StatusStyle: Text;
}
