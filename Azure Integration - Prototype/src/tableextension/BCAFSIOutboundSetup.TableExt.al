namespace Node4.BCAzureFileSharedIntegration;

tableextension 50115 "BCAFSI Outbound Setup" extends "BCAFSI Integration Setup"
{
    fields
    {
        field(50115; "Outbound Folder"; Text[250])
        {
            Caption = 'Outbound Folder';
            DataClassification = CustomerContent;
            InitValue = 'Outbound';

            trigger OnValidate()
            begin
                // Same rule as the inbound folders: External File Storage rejects paths starting with '/'.
                "Outbound Folder" := CopyStr(DelChr("Outbound Folder".Trim(), '<>', '/'), 1, MaxStrLen("Outbound Folder"));
            end;
        }
    }
}
