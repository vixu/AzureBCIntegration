namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;
using System.ExternalFileStorage;

table 50110 "BCAFSI Integration Setup"
{
    Caption = 'BC Azure File Shared Integration Setup';
    DataClassification = CustomerContent;
    DrillDownPageId = "BCAFSI Integration Setup";
    LookupPageId = "BCAFSI Integration Setup";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; Enabled; Boolean)
        {
            Caption = 'Enabled';

            trigger OnValidate()
            begin
                if Enabled then
                    CheckReadyToRun();
            end;
        }
        field(10; "File Account Id"; Guid)
        {
            Caption = 'File Account Id';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(11; "File Account Connector"; Enum "Ext. File Storage Connector")
        {
            Caption = 'File Account Connector';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(12; "File Account Name"; Text[250])
        {
            Caption = 'File Account';

            trigger OnValidate()
            var
                BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
            begin
                BCAFSIFileStorageMgt.ValidateFileAccountName(Rec);
            end;

            trigger OnLookup()
            var
                BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
            begin
                BCAFSIFileStorageMgt.LookupFileAccount(Rec);
            end;
        }
        field(20; "Inbound Folder"; Text[250])
        {
            Caption = 'Inbound Folder';
            InitValue = 'Inbound';

            trigger OnValidate()
            begin
                "Inbound Folder" := NormalizeFolder("Inbound Folder");
            end;
        }
        field(21; "Archive Folder"; Text[250])
        {
            Caption = 'Archive Folder';
            InitValue = 'Archived';

            trigger OnValidate()
            begin
                "Archive Folder" := NormalizeFolder("Archive Folder");
            end;
        }
        field(22; "Error Folder"; Text[250])
        {
            Caption = 'Error Folder';
            InitValue = 'Error';

            trigger OnValidate()
            begin
                "Error Folder" := NormalizeFolder("Error Folder");
            end;
        }
        field(23; "File Name Filter"; Text[100])
        {
            Caption = 'File Name Filter';
            InitValue = '@*.csv';
        }
        field(24; "Outbound Folder"; Text[250])
        {
            Caption = 'Outbound Folder';
            InitValue = 'Outbound';

            trigger OnValidate()
            begin
                "Outbound Folder" := NormalizeFolder("Outbound Folder");
            end;
        }
        field(30; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name';
            TableRelation = "Gen. Journal Template" where(Type = const(General), Recurring = const(false));

            trigger OnValidate()
            begin
                if "Journal Template Name" <> xRec."Journal Template Name" then
                    "Journal Batch Name" := '';
            end;
        }
        field(31; "Journal Batch Name"; Code[10])
        {
            Caption = 'Journal Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
        }
        field(40; "Max. Retries"; Integer)
        {
            Caption = 'Max. Retries';
            InitValue = 3;
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    procedure CheckReadyToRun()
    begin
        TestField("File Account Name");
        TestField("Inbound Folder");
        TestField("Archive Folder");
        TestField("Error Folder");
        TestField("Journal Template Name");
        TestField("Journal Batch Name");
    end;

    // External File Storage rejects paths starting with '/'.
    local procedure NormalizeFolder(Folder: Text[250]): Text[250]
    begin
        exit(CopyStr(DelChr(Folder.Trim(), '<>', '/'), 1, MaxStrLen(Folder)));
    end;
}
