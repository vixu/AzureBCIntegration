namespace Node4.BCAzureFileSharedIntegration;

using System.ExternalFileStorage;
using System.Threading;

page 50110 "BCAFSI Integration Setup"
{
    AdditionalSearchTerms = 'BC Azure File Shared Integration, BCAFSI, Azure File Share Setup';
    ApplicationArea = All;
    Caption = 'BC Azure File Shared Integration Setup';
    DelayedInsert = true;
    PageType = List;
    SourceTable = "BCAFSI Integration Setup";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Integrations)
            {
                field("Code"; Rec."Code")
                {
                    ToolTip = 'Specifies the unique code of the integration. Use it as Parameter String on the Job Queue entry.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies a description of the integration.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ToolTip = 'Specifies whether the integration is active. Only enabled integrations are fetched and processed.';
                }
                field("File Account Name"; Rec."File Account Name")
                {
                    ToolTip = 'Specifies the External File Account that connects to the Azure File Share.';
                }
                field("Inbound Folder"; Rec."Inbound Folder")
                {
                    ToolTip = 'Specifies the folder, relative to the share root, that new files are read from.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupFolder(Rec."Inbound Folder", Text));
                    end;
                }
                field("Archive Folder"; Rec."Archive Folder")
                {
                    ToolTip = 'Specifies the folder, relative to the share root, that staged files are moved to.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupFolder(Rec."Archive Folder", Text));
                    end;
                }
                field("Error Folder"; Rec."Error Folder")
                {
                    ToolTip = 'Specifies the folder, relative to the share root, that unreadable files are moved to.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupFolder(Rec."Error Folder", Text));
                    end;
                }
                field("Outbound Folder"; Rec."Outbound Folder")
                {
                    ToolTip = 'Specifies the folder, relative to the share root, that outbound confirmation files are created in.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupFolder(Rec."Outbound Folder", Text));
                    end;
                }
                field("File Name Filter"; Rec."File Name Filter")
                {
                    ToolTip = 'Specifies a filter on the file names to fetch, for example @*.csv. Leave blank to fetch all files.';
                }
                field("Journal Template Name"; Rec."Journal Template Name")
                {
                    ToolTip = 'Specifies the general journal template that lines are created in.';
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ToolTip = 'Specifies the general journal batch that lines are created in.';
                }
                field("Max. Retries"; Rec."Max. Retries")
                {
                    ToolTip = 'Specifies how many times the Job Queue retries a staging entry with status Error. 0 disables automatic retries.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                Caption = 'Test Connection';
                Image = TestFile;
                ToolTip = 'Connect to the file account and check that the inbound, archive and error folders exist.';

                trigger OnAction()
                var
                    BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
                begin
                    BCAFSIFileStorageMgt.TestConnection(Rec);
                end;
            }
            action(BrowseShare)
            {
                Caption = 'Browse Share';
                Image = BOMVersions;
                ToolTip = 'Open the Storage Browser for the file account to navigate folders and see their content.';

                trigger OnAction()
                var
                    BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
                begin
                    BCAFSIFileStorageMgt.BrowseShare(Rec);
                end;
            }
            action(FetchFiles)
            {
                Caption = 'Fetch Files';
                Image = Import;
                ToolTip = 'Copy the files in the inbound folder to staging and move them to the archive folder.';

                trigger OnAction()
                var
                    BCAFSIFetchFiles: Codeunit "BCAFSI Fetch Files";
                begin
                    CurrPage.SaveRecord();
                    Commit();
                    if not BCAFSIFetchFiles.Run(Rec) then
                        Error(GetLastErrorText());
                    Message(BCAFSIFetchFiles.GetSummary(Rec.Code));
                end;
            }
            action(ProcessStaging)
            {
                Caption = 'Process Staging';
                Image = PostBatch;
                ToolTip = 'Create general journal lines from the Ready staging entries and the Error entries that are still under the retry limit.';

                trigger OnAction()
                var
                    BCAFSIProcessStaging: Codeunit "BCAFSI Process Staging";
                begin
                    CurrPage.SaveRecord();
                    BCAFSIProcessStaging.ProcessIntegration(Rec);
                    Message(BCAFSIProcessStaging.GetSummary());
                end;
            }
            action(CreateJobQueueEntry)
            {
                Caption = 'Create Job Queue Entry';
                Image = Job;
                ToolTip = 'Create a recurring Job Queue entry (every 15 minutes, On Hold) that fetches and processes files for this integration.';

                trigger OnAction()
                var
                    BCAFSIJobQueueHandler: Codeunit "BCAFSI Job Queue Handler";
                begin
                    CurrPage.SaveRecord();
                    BCAFSIJobQueueHandler.CreateJobQueueEntry(Rec);
                end;
            }
        }
        area(Navigation)
        {
            action(Staging)
            {
                Caption = 'Inbound Staging';
                Image = List;
                RunObject = page "BCAFSI Inbound Staging";
                RunPageLink = "Integration Code" = field("Code");
                ToolTip = 'View the staging entries of this integration.';
            }
            action(OutboundStaging)
            {
                Caption = 'Outbound Staging';
                Image = List;
                RunObject = page "BCAFSI Outbound Staging";
                RunPageLink = "Integration Code" = field("Code");
                ToolTip = 'View the outbound entries of this integration.';
            }
            action(FileAccounts)
            {
                Caption = 'External File Accounts';
                Image = Server;
                RunObject = page "File Accounts";
                ToolTip = 'Open the External File Accounts page.';
            }
            action(JobQueueEntries)
            {
                Caption = 'Job Queue Entries';
                Image = JobListSetup;
                RunObject = page "Job Queue Entries";
                ToolTip = 'Open the Job Queue Entries page.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(FetchFiles_Promoted; FetchFiles) { }
                actionref(ProcessStaging_Promoted; ProcessStaging) { }
            }
            group(Category_Connection)
            {
                Caption = 'Connection';

                actionref(TestConnection_Promoted; TestConnection) { }
                actionref(BrowseShare_Promoted; BrowseShare) { }
                actionref(CreateJobQueueEntry_Promoted; CreateJobQueueEntry) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Navigate';

                actionref(Staging_Promoted; Staging) { }
                actionref(OutboundStaging_Promoted; OutboundStaging) { }
                actionref(FileAccounts_Promoted; FileAccounts) { }
                actionref(JobQueueEntries_Promoted; JobQueueEntries) { }
            }
        }
    }

    local procedure LookupFolder(CurrentFolder: Text; var Text: Text): Boolean
    var
        BCAFSIFileStorageMgt: Codeunit "BCAFSI File Storage Mgt.";
        SelectedFolder: Text;
    begin
        SelectedFolder := BCAFSIFileStorageMgt.SelectFolder(Rec, CurrentFolder);
        if SelectedFolder = '' then
            exit(false);
        Text := SelectedFolder;
        exit(true);
    end;
}
