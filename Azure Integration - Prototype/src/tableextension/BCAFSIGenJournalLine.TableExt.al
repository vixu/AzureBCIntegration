namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;

tableextension 50110 "BCAFSI Gen. Journal Line" extends "Gen. Journal Line"
{
    fields
    {
        field(50110; "BCAFSI Staging Entry No."; Integer)
        {
            Caption = 'BC Azure File Staging Entry No.';
            DataClassification = SystemMetadata;
            Editable = false;
            TableRelation = "BCAFSI Inbound Staging";
        }
    }

    keys
    {
        key(BCAFSIStagingEntryNo; "BCAFSI Staging Entry No.")
        {
        }
    }
}
