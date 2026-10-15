namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;

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
        field(3; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(4; Status; Enum "BCAFSI Staging Status")
        {
            Caption = 'Status';
        }
        field(5; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(6; "Account No."; Code[20])
        {
            Caption = 'Account No.';
        }
        field(7; Amount; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Amount';
        }
        field(8; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(10; "Inbound Entry No."; Integer)
        {
            Caption = 'Inbound Entry No.';
            TableRelation = "BCAFSI Inbound Staging";
        }
        field(11; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name';
            TableRelation = "Gen. Journal Template";
        }
        field(12; "Journal Batch Name"; Code[10])
        {
            Caption = 'Journal Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
        }
        field(13; "Journal Line No."; Integer)
        {
            Caption = 'Journal Line No.';
        }
        field(20; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(21; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
        }
        field(22; "Processed By"; Code[50])
        {
            Caption = 'Processed By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(23; "File Name"; Text[250])
        {
            Caption = 'File Name';
        }
        field(24; "File Path"; Text[2048])
        {
            Caption = 'File Path';
        }
        field(25; "Error Message"; Text[2048])
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
        key(IntegrationStatus; "Integration Code", Status)
        {
        }
    }
}
