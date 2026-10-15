namespace Node4.BCAzureFileSharedIntegration;

table 50112 "BCAFSI Cue"
{
    Caption = 'BC Azure File Shared Integration Cue';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Ready Entries"; Integer)
        {
            CalcFormula = count("BCAFSI Inbound Staging" where(Status = const(Ready)));
            Caption = 'Ready';
            Editable = false;
            FieldClass = FlowField;
        }
        field(11; "Error Entries"; Integer)
        {
            CalcFormula = count("BCAFSI Inbound Staging" where(Status = const(Error)));
            Caption = 'Error';
            Editable = false;
            FieldClass = FlowField;
        }
        field(12; "Processed"; Integer)
        {
            CalcFormula = count("BCAFSI Inbound Staging" where(Status = const(Processed)));
            Caption = 'Processed';
            Editable = false;
            FieldClass = FlowField;
        }
        field(20; "DateTime Filter"; DateTime)
        {
            Caption = 'DateTime Filter';
            FieldClass = FlowFilter;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
