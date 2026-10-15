namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;

page 50112 "BCAFSI Created Jnl. Lines"
{
    Caption = 'BC Azure File Shared Integration Journal Lines';
    Editable = false;
    PageType = List;
    SourceTable = "Gen. Journal Line";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Journal Template Name"; Rec."Journal Template Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the journal template of the line.';
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the journal batch of the line.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posting date of the line.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document number of the line.';
                }
                field("Account Type"; Rec."Account Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the account type of the line.';
                }
                field("Account No."; Rec."Account No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the account number of the line.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description of the line.';
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount of the line.';
                }
                field("Bal. Account Type"; Rec."Bal. Account Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the balancing account type of the line.';
                }
                field("Bal. Account No."; Rec."Bal. Account No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the balancing account number of the line.';
                }
                field("BCAFSI Staging Entry No."; Rec."BCAFSI Staging Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the staging entry that the line was created from.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(OpenGeneralJournal)
            {
                ApplicationArea = All;
                Caption = 'Open General Journal';
                Image = Journal;
                ToolTip = 'Open the general journal batch that contains the selected line.';

                trigger OnAction()
                var
                    GenJournalBatch: Record "Gen. Journal Batch";
                    GenJnlManagement: Codeunit GenJnlManagement;
                begin
                    GenJournalBatch.Get(Rec."Journal Template Name", Rec."Journal Batch Name");
                    GenJnlManagement.TemplateSelectionFromBatch(GenJournalBatch);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(OpenGeneralJournal_Promoted; OpenGeneralJournal) { }
            }
        }
    }
}
