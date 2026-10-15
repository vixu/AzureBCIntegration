namespace Node4.BCAzureFileSharedIntegration;

enum 50110 "BCAFSI Staging Status"
{
    Caption = 'BC Azure File Shared Integration Staging Status';
    Extensible = false;

    value(0; Ready)
    {
        Caption = 'Ready';
    }
    value(1; Processing)
    {
        Caption = 'Processing';
    }
    value(2; Processed)
    {
        Caption = 'Processed';
    }
    value(3; Error)
    {
        Caption = 'Error';
    }
}
