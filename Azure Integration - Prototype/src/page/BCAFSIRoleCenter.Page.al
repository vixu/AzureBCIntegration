namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Finance.GeneralLedger.Journal;
using System.ExternalFileStorage;
using System.Threading;

page 50114 "BCAFSI Role Center"
{
    Caption = 'BC Azure File Shared Integration';
    PageType = RoleCenter;

    layout
    {
        area(RoleCenter)
        {
            part(Activities; "BCAFSI Activities")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Embedding)
        {
            action(IntegrationSetup)
            {
                ApplicationArea = All;
                Caption = 'Integration Setup';
                RunObject = page "BCAFSI Integration Setup";
                ToolTip = 'Set up the BC Azure File Shared Integrations.';
            }
            action(InboundStaging)
            {
                ApplicationArea = All;
                Caption = 'Inbound Staging';
                RunObject = page "BCAFSI Inbound Staging";
                ToolTip = 'View the files staged from the Azure File Share.';
            }
            action(JobQueueEntries)
            {
                ApplicationArea = All;
                Caption = 'Job Queue Entries';
                RunObject = page "Job Queue Entries";
                ToolTip = 'View the Job Queue entries.';
            }
            action(FileAccounts)
            {
                ApplicationArea = All;
                Caption = 'External File Accounts';
                RunObject = page "File Accounts";
                ToolTip = 'View the External File Accounts.';
            }
            action(GeneralJournals)
            {
                ApplicationArea = All;
                Caption = 'General Journals';
                RunObject = page "General Journal";
                ToolTip = 'Open the general journals.';
            }
        }
    }
}
