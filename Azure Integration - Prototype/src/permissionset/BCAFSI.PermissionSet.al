namespace Node4.BCAzureFileSharedIntegration;

permissionset 50110 "BCAFSI"
{
    Assignable = true;
    Caption = 'BC Azure File Shared Integration';
    Permissions =
        codeunit "BCAFSI Fetch Files" = X,
        codeunit "BCAFSI File Storage Mgt." = X,
        codeunit "BCAFSI Job Queue Handler" = X,
        codeunit "BCAFSI Outbound Mgt." = X,
        codeunit "BCAFSI Process Staging" = X,
        codeunit "BCAFSI Process Staging Entry" = X,
        page "BCAFSI Activities" = X,
        page "BCAFSI Created Jnl. Lines" = X,
        page "BCAFSI Inbound Staging" = X,
        page "BCAFSI Integration Setup" = X,
        page "BCAFSI Outbound Staging" = X,
        page "BCAFSI Role Center" = X,
        table "BCAFSI Cue" = X,
        table "BCAFSI Inbound Staging" = X,
        table "BCAFSI Integration Setup" = X,
        table "BCAFSI Outbound Staging" = X,
        tabledata "BCAFSI Cue" = RIMD,
        tabledata "BCAFSI Inbound Staging" = RIMD,
        tabledata "BCAFSI Integration Setup" = RIMD,
        tabledata "BCAFSI Outbound Staging" = RIMD;
}
