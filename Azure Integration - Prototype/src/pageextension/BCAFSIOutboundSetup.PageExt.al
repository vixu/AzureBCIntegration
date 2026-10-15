namespace Node4.BCAzureFileSharedIntegration;

pageextension 50115 "BCAFSI Outbound Setup" extends "BCAFSI Integration Setup"
{
    layout
    {
        addafter("Error Folder")
        {
            field("Outbound Folder"; Rec."Outbound Folder")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the folder, relative to the share root, that outbound text files are created in.';

                trigger OnLookup(var Text: Text): Boolean
                var
                    BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
                    SelectedFolder: Text;
                begin
                    SelectedFolder := BCAFSIFileStorageMgt.SelectFolder(Rec, Rec."Outbound Folder");
                    if SelectedFolder = '' then
                        exit(false);
                    Text := SelectedFolder;
                    exit(true);
                end;
            }
        }
    }

    actions
    {
        addafter(Staging)
        {
            action(OutboundStaging)
            {
                ApplicationArea = All;
                Caption = 'Outbound Staging';
                Image = List;
                RunObject = page "BCAFSI Outbound Staging";
                RunPageLink = "Integration Code" = field("Code");
                ToolTip = 'View the outbound entries of this integration.';
            }
        }
        addafter(Staging_Promoted)
        {
            actionref(OutboundStaging_Promoted; OutboundStaging) { }
        }
    }
}
