# BC Azure File Shared Integration (BCAFSI)

Prototype that reads CSV files from the Azure File Share `inbound` through a standard
**External File Account**, stores them in a staging table, and creates **General Journal** lines.
It uses only the System Application **External File Storage** module (`System.ExternalFileStorage`).
There is no HttpClient code, no AFS File Client, and no credentials in code or tables.

## Objects (prefix `BCAFSI`, IDs 50110–50114)

| Type           | ID    | Name                                                   |
|----------------|-------|--------------------------------------------------------|
| enum           | 50110 | BCAFSI Staging Status (Ready, Processing, Processed, Error) |
| table          | 50110 | BCAFSI Integration Setup                               |
| table          | 50111 | BCAFSI Inbound Staging (caption "Inbound BC Azure Integration") |
| table          | 50112 | BCAFSI Cue                                             |
| tableextension | 50110 | BCAFSI Gen. Journal Line (adds field 50110 "BCAFSI Staging Entry No.") |
| codeunit       | 50110 | BCAFSI File Storage Mgt. (the only object that calls External File Storage) |
| codeunit       | 50111 | BCAFSI Fetch Files                                     |
| codeunit       | 50112 | BCAFSI Process Staging Entry (one file, runs isolated with `Codeunit.Run`) |
| codeunit       | 50113 | BCAFSI Process Staging (loops over entries, sets status, retries) |
| codeunit       | 50114 | BCAFSI Job Queue Handler                               |
| page           | 50110 | BCAFSI Integration Setup (list)                        |
| page           | 50111 | BCAFSI Inbound Staging (list)                          |
| page           | 50112 | BCAFSI Created Jnl. Lines                              |
| page           | 50113 | BCAFSI Activities (cues)                               |
| page           | 50114 | BCAFSI Role Center                                     |
| profile        | BCAFSI | BC Azure File Shared Integration                      |
| permissionset  | 50110 | BCAFSI                                                 |

Sample files:
- [samples/BCAFSI_Sample_Valid.csv](samples/BCAFSI_Sample_Valid.csv): valid accounts for the demo company (31010, 31020, 85300 against 78100).
- [samples/BCAFSI_Sample.csv](samples/BCAFSI_Sample.csv): its accounts don't exist in the demo company, so use it to demo the Error status.

## Status lifecycle

`Ready` → `Processing` → `Processed` | `Error`

- **Process** (manual, on selected entries) runs `Ready` and `Error` entries.
- **Process Staging** and the Job Queue run `Ready` entries, plus `Error` entries while Retry Count < Max. Retries.
- **Reset to Ready** works on `Error` and `Processing` entries. Use it for an entry left in `Processing`, for example after a session crash.
- `Processed` can't be reset, so journal lines can't be created twice from the same file.

## Setup

1. Publish the extension and assign permission set **BCAFSI** to the users.
   Users also need the standard permissions for General Journals, Job Queue and External File Storage.
2. In the share, create the folder **Error** next to `Inbound`, `Archived` and `CreatedInBC`.
   You can do this from the Storage Browser or the Azure portal.
3. Search for **BC Azure File Shared Integration Setup** and create a line:
   - **Code**: `UNITE`, then fill in Description.
   - **File Account**: use the lookup to choose the existing External File Account.
   - **Folders**: Inbound = `Inbound`, Archive = `Archived`, Error = `Error`. Each folder field has a lookup that opens the standard folder browser.
   - **File Name Filter**: `@*.csv` (the `@` makes it case-insensitive).
   - **Journal Template Name / Journal Batch Name**: a General template (non-recurring) and one of its batches.
   - **Max. Retries**: 3.
   - **Enabled**: Yes.
4. Choose **Test Connection**. You should get a success message, or a list of missing folders.
5. Optional: choose **Create Job Queue Entry**. This creates a recurring entry (every 15 minutes, On Hold) and opens its card. Set it to Ready when you want it to run.
6. Optional: in **My Settings**, choose the role **BC Azure File Shared Integration**.

## Demo script

1. Upload `BCAFSI_Sample_Valid.csv` to `Inbound`, from the Storage Browser (use **Browse Share**) or the Azure portal.
2. In **BC Azure File Shared Integration Setup**, choose **Fetch Files**. The summary should show
   1 file staged, and the file should now be in `Archived`.
3. Open **Inbound BC Azure Integration**. The entry is `Ready`. Use **View Content** or **Download Content** to check it.
4. Choose **Process**. The status changes to `Processed` with 3 lines created. Choose
   **Show Created Journal Lines**, then **Open General Journal**.
5. To demo an error, upload a copy with an invalid account number under a new file name, then fetch and process it.
   The status is `Error` and the error message lists every invalid line. No journal lines are created.
   Correct the account in BC, choose **Reset to Ready**, then process it again. The Role Center cues show the counts.

## CSV format

`DocumentNo,PostingDate,AccountType,AccountNo,Amount,BalAccountType,BalAccountNo,Description`

- Header row required, comma separator, UTF-8.
- PostingDate is `YYYY-MM-DD`. Amount uses `.` as the decimal separator.
- AccountType must be `G/L Account` or `Bank Account` (not case-sensitive). BalAccountType can be blank (treated as G/L Account).
- BalAccountNo can be blank (no balancing account on the line).
- Every line is validated before any journal line is created. If any line fails, no lines are created for that file.

## Assumptions

1. **Idempotency**: duplicates are detected by Integration Code + File Name, backed by a unique key.
   - If a file arrives with a name that is already staged, it is moved to Archive without staging.
   - Deleting a staging entry allows that file name to be imported again.
2. **Archive name clash**: if the name already exists in Archive or Error, `_yyyyMMddHHmmss` (UTC) is added before the extension.
   - Moving a file is done with `CopyFile` followed by `DeleteFile`, not `MoveFile`.
   - The reason: the Azure File Share connector's `MoveFile` passes source and target to `AFS File Client.RenameFile` in reverse order, so it always fails.
   - Copy within the same share completes immediately for small files.
3. **Where the file ends up**:
   - A file that was read successfully always goes to **Archive**, even if processing later fails. The original content is kept in staging, and the status and error text are on the staging record. Error and retry are tracked in BC, not by moving files.
   - Only a file that **cannot be read** goes to the **Error** folder.
   - If a move fails, the Fetch summary shows the last error. The staging record is committed **before** the move, so the file stays in Inbound and the next fetch archives it as a duplicate.
4. **Journal lines**:
   - The batch's number series is ignored: Document No. comes from the file.
   - Local currency only, no dimensions.
   - Template must be type General and not recurring.
   - Lines are created with the standard `SetUpNewLine` and `Validate` calls and are not posted.
   - G/L accounts must be posting accounts with Direct Posting enabled and not blocked. Bank accounts must not be blocked.
5. **CSV parsing** uses the standard Base App `CSV Buffer`.
   - Quoted values with commas inside them are **not** supported.
   - Surrounding quotes and spaces are trimmed.
   - Values are limited to 250 characters.
6. **Processing isolation**:
   - Each staging entry runs with `Codeunit.Run`, so one failure doesn't stop the others.
   - Commits are made only in Fetch Files and Process Staging, never in the parsing or journal code.
7. **Job Queue**:
   - One codeunit, 50114. Parameter String = Integration Code; empty means all enabled integrations.
   - If one integration's fetch fails, the others still run. The failure is reported in the Job Queue log at the end.
   - Staged entries are still processed even when that run's fetch failed.
8. **Enabled check**: Fetch requires the integration to be Enabled. Enabling it requires the account, all three folders, and the template and batch.
9. **Size and duration**: whole files are read into memory, which is fine for typical CSV sizes. Files still being uploaded aren't detected.
10. **Telemetry**: events BCAFSI-0001 (process failure), BCAFSI-0002 (read failure) and BCAFSI-0003 (move failure) are sent to the publisher's Application Insights. They contain no file content.
11. **Version**: app.json is unchanged (application/platform 29.0, runtime 18.0). The External File Storage methods used were checked on BCApps `releases/28.0`.
12. **Previous prototype**: the earlier "Unite File Monitor" objects (IDs 50100–50101) are still in this app and don't depend on BCAFSI.

## Outbound (prototype)

New objects only. The inbound objects are unchanged.

| Type           | ID    | Name                                                   |
|----------------|-------|--------------------------------------------------------|
| table          | 50115 | BCAFSI Outbound Staging (caption "Outbound BC Azure Integration") |
| tableextension | 50115 | BCAFSI Outbound Setup (adds field 50115 "Outbound Folder" to the setup) |
| codeunit       | 50115 | BCAFSI Outbound Mgt. (trigger subscriber + Process loop) |
| codeunit       | 50116 | BCAFSI Outbound Export Entry (one entry, runs isolated with `Codeunit.Run`) |
| page           | 50115 | BCAFSI Outbound Staging (list)                         |
| pageextension  | 50115 | BCAFSI Outbound Setup (Outbound Folder field + Outbound Staging action) |
| pageextension  | 50116 | BCAFSI Outbound Role Center (Outbound Staging link)    |
| permissionset  | 50115 | BCAFSI Outbound (includes BCAFSI)                      |

Flow:
1. Inbound processing inserts a General Journal line with "BCAFSI Staging Entry No.".
2. A subscriber on `Gen. Journal Line` OnAfterInsertEvent creates one outbound entry per line, status `Ready`.
   It runs in the same transaction, so if the inbound file fails, no outbound entries are kept.
3. On **Outbound BC Azure Integration**, choose **Process**. Each Ready or Error entry writes
   `OUT_<DocumentNo>_<EntryNo>.txt` to the Outbound Folder and becomes `Processed`, or `Error` with the message.

Setup: create the folder **Outbound** in the share, then set **Outbound Folder** on the integration setup line.

File format (UTF-8, pipe separated, header + one row):
`EntryNo|IntegrationCode|DocumentNo|PostingDate|AccountNo|Amount|Description|InboundEntryNo`
