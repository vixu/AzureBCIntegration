namespace Node4.BCAzureFileSharedIntegration;

permissionset 50115 "BCAFSI Outbound"
{
    Assignable = true;
    Caption = 'BC Azure File Shared Integration Outbound';
    IncludedPermissionSets = "BCAFSI";
    Permissions =
        codeunit "BCAFSI Outbound Export Entry" = X,
        codeunit "BCAFSI Outbound Mgt." = X,
        page "BCAFSI Outbound Staging" = X,
        table "BCAFSI Outbound Staging" = X,
        tabledata "BCAFSI Outbound Staging" = RIMD;
}
