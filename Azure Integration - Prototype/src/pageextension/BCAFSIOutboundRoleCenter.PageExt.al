namespace Node4.BCAzureFileSharedIntegration;

pageextension 50116 "BCAFSI Outbound Role Center" extends "BCAFSI Role Center"
{
    actions
    {
        addafter(InboundStaging)
        {
            action(OutboundStaging)
            {
                ApplicationArea = All;
                Caption = 'Outbound Staging';
                RunObject = page "BCAFSI Outbound Staging";
                ToolTip = 'View the outbound entries and create the files in the Azure File Share.';
            }
        }
    }
}
