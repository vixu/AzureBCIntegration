namespace Node4.BCAzureFileSharedIntegration;

page 50113 "BCAFSI Activities"
{
    Caption = 'BC Azure File Shared Integration';
    PageType = CardPart;
    RefreshOnActivate = true;
    ShowFilter = false;
    SourceTable = "BCAFSI Cue";

    layout
    {
        area(Content)
        {
            cuegroup(Staging)
            {
                Caption = 'Inbound Files';

                field("Ready Entries"; Rec."Ready Entries")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "BCAFSI Inbound Staging";
                    ToolTip = 'Specifies the number of staged files waiting to be processed.';
                }
                field("Error Entries"; Rec."Error Entries")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "BCAFSI Inbound Staging";
                    StyleExpr = ErrorStyle;
                    ToolTip = 'Specifies the number of staged files that failed to process.';
                }
                field("Processed"; Rec."Processed")
                {
                    ApplicationArea = All;
                    DrillDownPageId = "BCAFSI Inbound Staging";
                    ToolTip = 'Specifies the number of files processed.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
        //Rec.SetRange("DateTime Filter", CreateDateTime(Today(), 0T), CreateDateTime(Today(), 235959.999T));
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Error Entries");
        if Rec."Error Entries" > 0 then
            ErrorStyle := Format(PageStyle::Unfavorable)
        else
            ErrorStyle := Format(PageStyle::Favorable);
    end;

    var
        ErrorStyle: Text;
}
