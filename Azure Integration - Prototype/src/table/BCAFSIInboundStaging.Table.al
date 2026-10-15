namespace Node4.BCAzureFileSharedIntegration;

table 50111 "BCAFSI Inbound Staging"
{
    Caption = 'Inbound BC Azure Integration';
    DataClassification = CustomerContent;
    DrillDownPageId = "BCAFSI Inbound Staging";
    LookupPageId = "BCAFSI Inbound Staging";

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
        field(3; "File Name"; Text[250])
        {
            Caption = 'File Name';
        }
        field(4; "File Content"; Blob)
        {
            Caption = 'File Content';
        }
        field(5; "File Size"; BigInteger)
        {
            Caption = 'File Size (Bytes)';
        }
        field(6; "Received At"; DateTime)
        {
            Caption = 'Received At';
        }
        field(7; Status; Enum "BCAFSI Staging Status")
        {
            Caption = 'Status';
        }
        field(8; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(9; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
        }
        field(10; "Processed By"; Code[50])
        {
            Caption = 'Processed By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; "No. of Lines Created"; Integer)
        {
            Caption = 'No. of Lines Created';
        }
        field(12; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
        }
        field(13; "Archived File Path"; Text[2048])
        {
            Caption = 'Archived File Path';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(IntegrationFile; "Integration Code", "File Name")
        {
            Unique = true;
        }
        key(IntegrationStatus; "Integration Code", Status)
        {
        }
        key(StatusProcessedAt; Status, "Processed At")
        {
        }
    }

    procedure DownloadContent()
    var
        ContentInStream: InStream;
        FileName: Text;
    begin
        CalcFields("File Content");
        "File Content".CreateInStream(ContentInStream);
        FileName := "File Name";
        DownloadFromStream(ContentInStream, '', '', '', FileName);
    end;

    procedure ShowContent()
    var
        ContentInStream: InStream;
        ContentTextBuilder: TextBuilder;
        LineCount: Integer;
        Line: Text;
        PreviewMsg: Label 'First lines of %1:\\%2', Comment = '%1 = File name, %2 = File content';
    begin
        CalcFields("File Content");
        "File Content".CreateInStream(ContentInStream, TextEncoding::UTF8);
        LineCount := 0;
        while (not ContentInStream.EOS()) and (LineCount < 20) do begin
            ContentInStream.ReadText(Line);
            ContentTextBuilder.AppendLine(CopyStr(Line, 1, 250));
            LineCount += 1;
        end;
        Message(PreviewMsg, "File Name", ContentTextBuilder.ToText());
    end;
}
