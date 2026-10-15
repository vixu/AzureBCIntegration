namespace Node4.BCAzureFileSharedIntegration;

table 50115 "BCAFSI Outbound Staging"
{
    Caption = 'Outbound BC Azure Integration';
    DataClassification = CustomerContent;
    DrillDownPageId = "BCAFSI Outbound Staging";
    LookupPageId = "BCAFSI Outbound Staging";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
        }
        field(2; "Integration Code"; Code[20])
        {
            Caption = 'Integration Code';
            TableRelation = "BCAFSI Integration Setup";
        }
        field(3; "Inbound Entry No."; Integer)
        {
            Caption = 'Inbound Entry No.';
            TableRelation = "BCAFSI Inbound Staging";
        }
        field(4; "Inbound File Name"; Text[250])
        {
            Caption = 'Inbound File Name';
        }
        field(5; Status; Enum "BCAFSI Staging Status")
        {
            Caption = 'Status';
        }
        field(6; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
        }
        field(7; "File Content"; Blob)
        {
            Caption = 'File Content';
        }
        field(8; "File Name"; Text[250])
        {
            Caption = 'File Name';
        }
        field(9; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(10; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
        }
        field(11; "Processed By"; Code[50])
        {
            Caption = 'Processed By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(12; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
