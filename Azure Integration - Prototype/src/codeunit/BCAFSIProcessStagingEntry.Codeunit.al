namespace Node4.BCAzureFileSharedIntegration;

using Microsoft.Bank.BankAccount;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Journal;
using System.IO;

codeunit 50112 "BCAFSI Process Staging Entry"
{
    TableNo = "BCAFSI Inbound Staging";

    trigger OnRun()
    begin
        ProcessEntry(Rec);
    end;

    var
        AccountBlockedErr: Label '%1 %2 is blocked.', Comment = '%1 = Account type, %2 = Account no.';
        AccountNotFoundErr: Label '%1 %2 does not exist.', Comment = '%1 = Account type, %2 = Account no.';
        AccountTypeErr: Label 'Account type "%1" is not supported. Use G/L Account or Bank Account.', Comment = '%1 = Account type text';
        AmountErr: Label 'Amount "%1" is not a valid non-zero decimal with "." as decimal separator.', Comment = '%1 = Amount text';
        ColumnCountErr: Label 'Expected %1 columns, found %2.', Comment = '%1 = Expected, %2 = Found';
        EmptyContentErr: Label 'File %1 has no content.', Comment = '%1 = File name';
        EmptyValueErr: Label '%1 must not be empty.', Comment = '%1 = Column name';
        GLAccountNotPostingErr: Label 'G/L Account %1 must be a posting account with Direct Posting enabled.', Comment = '%1 = Account no.';
        HeaderErr: Label 'The header row does not match the expected format: %1', Comment = '%1 = Expected header';
        LineErr: Label 'Line %1: %2', Comment = '%1 = Line number in file, %2 = Error text';
        NoDataLinesErr: Label 'File %1 contains no data lines.', Comment = '%1 = File name';
        PostingDateErr: Label 'PostingDate "%1" is not a valid date in format YYYY-MM-DD.', Comment = '%1 = Date text';
        TooLongErr: Label '%1 "%2" is longer than %3 characters.', Comment = '%1 = Column name, %2 = Value, %3 = Max length';
        UnexpectedStatusErr: Label 'Staging entry %1 must have status %2 to be processed.', Comment = '%1 = Entry No., %2 = Status';
        ValidationFailedErr: Label 'File %1 was not imported. %2 line(s) failed validation:\%3', Comment = '%1 = File name, %2 = Number of errors, %3 = Errors';
        ExpectedHeaderTxt: Label 'DocumentNo,PostingDate,AccountType,AccountNo,Amount,BalAccountType,BalAccountNo,Description', Locked = true;

    local procedure ProcessEntry(var BCAFSIInboundStaging: Record "BCAFSI Inbound Staging")
    var
        BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup";
        TempCSVBuffer: Record "CSV Buffer" temporary;
        TempGenJournalLine: Record "Gen. Journal Line" temporary;
        BCAFSIOutboundMgt: Codeunit "BCAFSI Outbound Mgt.";
        LinesCreated: Integer;
    begin
        if BCAFSIInboundStaging.Status <> BCAFSIInboundStaging.Status::Processing then
            Error(UnexpectedStatusErr, BCAFSIInboundStaging."Entry No.", BCAFSIInboundStaging.Status::Processing);

        BCAFSIIntegrationSetup.Get(BCAFSIInboundStaging."Integration Code");
        CheckJournal(BCAFSIIntegrationSetup);

        LoadCsv(BCAFSIInboundStaging, TempCSVBuffer);
        CheckHeader(TempCSVBuffer);
        ParseAndValidateLines(BCAFSIInboundStaging."File Name", TempCSVBuffer, TempGenJournalLine);
        LinesCreated := CreateJournalLines(BCAFSIIntegrationSetup, BCAFSIInboundStaging."Entry No.", TempGenJournalLine);

        // Status is set in the same transaction as the journal lines, so both commit or roll back together.
        BCAFSIInboundStaging.Status := BCAFSIInboundStaging.Status::Processed;
        BCAFSIInboundStaging."Processed At" := CurrentDateTime();
        BCAFSIInboundStaging."No. of Lines Created" := LinesCreated;
        BCAFSIInboundStaging."Error Message" := '';
        BCAFSIInboundStaging.Modify(true);

        // One outbound entry per inbound file, in the same transaction as the journal lines.
        BCAFSIOutboundMgt.CreateOutboundEntry(BCAFSIInboundStaging);
    end;

    local procedure CheckJournal(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup")
    var
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalTemplate: Record "Gen. Journal Template";
    begin
        BCAFSIIntegrationSetup.TestField("Journal Template Name");
        BCAFSIIntegrationSetup.TestField("Journal Batch Name");
        GenJournalTemplate.SetLoadFields(Type, Recurring);
        GenJournalTemplate.Get(BCAFSIIntegrationSetup."Journal Template Name");
        GenJournalTemplate.TestField(Type, GenJournalTemplate.Type::General);
        GenJournalTemplate.TestField(Recurring, false);
        GenJournalBatch.SetLoadFields(Name);
        GenJournalBatch.Get(BCAFSIIntegrationSetup."Journal Template Name", BCAFSIIntegrationSetup."Journal Batch Name");
    end;

    local procedure LoadCsv(var BCAFSIInboundStaging: Record "BCAFSI Inbound Staging"; var TempCSVBuffer: Record "CSV Buffer" temporary)
    var
        ContentInStream: InStream;
    begin
        BCAFSIInboundStaging.CalcFields("File Content");
        if not BCAFSIInboundStaging."File Content".HasValue() then
            Error(EmptyContentErr, BCAFSIInboundStaging."File Name");
        BCAFSIInboundStaging."File Content".CreateInStream(ContentInStream);
        TempCSVBuffer.LoadDataFromStream(ContentInStream, ',', '" ', Utf8CodePage());
    end;

    local procedure CheckHeader(var TempCSVBuffer: Record "CSV Buffer" temporary)
    var
        ColumnNo: Integer;
        ExpectedColumns: List of [Text];
    begin
        ExpectedColumns := ExpectedHeaderTxt.Split(',');
        TempCSVBuffer.SetRange("Line No.", 1);
        if TempCSVBuffer.Count() <> ExpectedColumns.Count() then
            Error(HeaderErr, ExpectedHeaderTxt);
        for ColumnNo := 1 to ExpectedColumns.Count() do
            if UpperCase(GetValue(TempCSVBuffer, 1, ColumnNo)) <> UpperCase(ExpectedColumns.Get(ColumnNo)) then
                Error(HeaderErr, ExpectedHeaderTxt);
        TempCSVBuffer.Reset();
    end;

    local procedure ParseAndValidateLines(FileName: Text; var TempCSVBuffer: Record "CSV Buffer" temporary; var TempGenJournalLine: Record "Gen. Journal Line" temporary)
    var
        TempLineCSVBuffer: Record "CSV Buffer" temporary;
        ErrorCount: Integer;
        LineError: Text;
        ErrorTextBuilder: TextBuilder;
    begin
        TempLineCSVBuffer.Copy(TempCSVBuffer, true);
        TempLineCSVBuffer.SetFilter("Line No.", '>1');
        TempLineCSVBuffer.SetRange("Field No.", 1);
        if TempLineCSVBuffer.FindSet() then
            repeat
                if not IsEmptyLine(TempCSVBuffer, TempLineCSVBuffer."Line No.") then begin
                    LineError := ParseLine(TempCSVBuffer, TempLineCSVBuffer."Line No.", TempGenJournalLine);
                    if LineError <> '' then begin
                        ErrorCount += 1;
                        ErrorTextBuilder.Append('\' + StrSubstNo(LineErr, TempLineCSVBuffer."Line No.", LineError));
                    end;
                end;
            until TempLineCSVBuffer.Next() = 0;

        if ErrorCount > 0 then
            Error(ValidationFailedErr, FileName, ErrorCount, ErrorTextBuilder.ToText());
        if TempGenJournalLine.IsEmpty() then
            Error(NoDataLinesErr, FileName);
    end;

    // Returns the first validation error for the line, or '' if the line is valid.
    local procedure ParseLine(var TempCSVBuffer: Record "CSV Buffer" temporary; LineNo: Integer; var TempGenJournalLine: Record "Gen. Journal Line" temporary): Text
    var
        PostingDate: Date;
        Amount: Decimal;
        AccountType: Enum "Gen. Journal Account Type";
        BalAccountType: Enum "Gen. Journal Account Type";
        ColumnCount: Integer;
        AccountNo: Text;
        AmountText: Text;
        BalAccountNo: Text;
        Description: Text;
        DocumentNo: Text;
        LineError: Text;
        PostingDateText: Text;
    begin
        TempCSVBuffer.SetRange("Line No.", LineNo);
        ColumnCount := TempCSVBuffer.Count();
        TempCSVBuffer.Reset();
        if ColumnCount <> 8 then
            exit(StrSubstNo(ColumnCountErr, 8, ColumnCount));

        DocumentNo := GetValue(TempCSVBuffer, LineNo, 1);
        PostingDateText := GetValue(TempCSVBuffer, LineNo, 2);
        AccountNo := GetValue(TempCSVBuffer, LineNo, 4);
        AmountText := GetValue(TempCSVBuffer, LineNo, 5);
        BalAccountNo := GetValue(TempCSVBuffer, LineNo, 7);
        Description := GetValue(TempCSVBuffer, LineNo, 8);

        if DocumentNo = '' then
            exit(StrSubstNo(EmptyValueErr, 'DocumentNo'));
        if StrLen(DocumentNo) > MaxStrLen(TempGenJournalLine."Document No.") then
            exit(StrSubstNo(TooLongErr, 'DocumentNo', DocumentNo, MaxStrLen(TempGenJournalLine."Document No.")));
        if not Evaluate(PostingDate, PostingDateText, 9) then
            exit(StrSubstNo(PostingDateErr, PostingDateText));
        if not ParseAccountType(GetValue(TempCSVBuffer, LineNo, 3), false, AccountType, LineError) then
            exit(LineError);
        LineError := CheckAccount(AccountType, AccountNo, false);
        if LineError <> '' then
            exit(LineError);
        if not Evaluate(Amount, AmountText, 9) or (Amount = 0) then
            exit(StrSubstNo(AmountErr, AmountText));
        if not ParseAccountType(GetValue(TempCSVBuffer, LineNo, 6), true, BalAccountType, LineError) then
            exit(LineError);
        LineError := CheckAccount(BalAccountType, BalAccountNo, true);
        if LineError <> '' then
            exit(LineError);
        if StrLen(Description) > MaxStrLen(TempGenJournalLine.Description) then
            exit(StrSubstNo(TooLongErr, 'Description', Description, MaxStrLen(TempGenJournalLine.Description)));

        TempGenJournalLine.Init();
        TempGenJournalLine."Line No." := LineNo;
        TempGenJournalLine."Document No." := CopyStr(DocumentNo, 1, MaxStrLen(TempGenJournalLine."Document No."));
        TempGenJournalLine."Posting Date" := PostingDate;
        TempGenJournalLine."Account Type" := AccountType;
        TempGenJournalLine."Account No." := CopyStr(AccountNo, 1, MaxStrLen(TempGenJournalLine."Account No."));
        TempGenJournalLine.Amount := Amount;
        TempGenJournalLine."Bal. Account Type" := BalAccountType;
        TempGenJournalLine."Bal. Account No." := CopyStr(BalAccountNo, 1, MaxStrLen(TempGenJournalLine."Bal. Account No."));
        TempGenJournalLine.Description := CopyStr(Description, 1, MaxStrLen(TempGenJournalLine.Description));
        TempGenJournalLine.Insert();
        exit('');
    end;

    local procedure ParseAccountType(AccountTypeText: Text; AllowBlank: Boolean; var AccountType: Enum "Gen. Journal Account Type"; var LineError: Text): Boolean
    begin
        case UpperCase(AccountTypeText) of
            'G/L ACCOUNT':
                AccountType := AccountType::"G/L Account";
            'BANK ACCOUNT':
                AccountType := AccountType::"Bank Account";
            '':
                begin
                    if not AllowBlank then begin
                        LineError := StrSubstNo(EmptyValueErr, 'AccountType');
                        exit(false);
                    end;
                    AccountType := AccountType::"G/L Account";
                end;
            else begin
                LineError := StrSubstNo(AccountTypeErr, AccountTypeText);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure CheckAccount(AccountType: Enum "Gen. Journal Account Type"; AccountNo: Text; AllowBlank: Boolean): Text
    var
        BankAccount: Record "Bank Account";
        GLAccount: Record "G/L Account";
    begin
        if AccountNo = '' then begin
            if AllowBlank then
                exit('');
            exit(StrSubstNo(EmptyValueErr, 'AccountNo'));
        end;
        if StrLen(AccountNo) > MaxStrLen(GLAccount."No.") then
            exit(StrSubstNo(TooLongErr, 'AccountNo', AccountNo, MaxStrLen(GLAccount."No.")));

        case AccountType of
            AccountType::"G/L Account":
                begin
                    GLAccount.SetLoadFields(Blocked, "Account Type", "Direct Posting");
                    if not GLAccount.Get(AccountNo) then
                        exit(StrSubstNo(AccountNotFoundErr, AccountType, AccountNo));
                    if GLAccount.Blocked then
                        exit(StrSubstNo(AccountBlockedErr, AccountType, AccountNo));
                    if (GLAccount."Account Type" <> GLAccount."Account Type"::Posting) or not GLAccount."Direct Posting" then
                        exit(StrSubstNo(GLAccountNotPostingErr, AccountNo));
                end;
            AccountType::"Bank Account":
                begin
                    BankAccount.SetLoadFields(Blocked);
                    if not BankAccount.Get(AccountNo) then
                        exit(StrSubstNo(AccountNotFoundErr, AccountType, AccountNo));
                    if BankAccount.Blocked then
                        exit(StrSubstNo(AccountBlockedErr, AccountType, AccountNo));
                end;
        end;
        exit('');
    end;

    local procedure CreateJournalLines(BCAFSIIntegrationSetup: Record "BCAFSI Integration Setup"; StagingEntryNo: Integer; var TempGenJournalLine: Record "Gen. Journal Line" temporary): Integer
    var
        GenJournalLine: Record "Gen. Journal Line";
        LastGenJournalLine: Record "Gen. Journal Line";
        LinesCreated: Integer;
        NextLineNo: Integer;
    begin
        LastGenJournalLine.ReadIsolation(IsolationLevel::UpdLock);
        LastGenJournalLine.SetRange("Journal Template Name", BCAFSIIntegrationSetup."Journal Template Name");
        LastGenJournalLine.SetRange("Journal Batch Name", BCAFSIIntegrationSetup."Journal Batch Name");
        if LastGenJournalLine.FindLast() then
            NextLineNo := LastGenJournalLine."Line No.";

        TempGenJournalLine.FindSet();
        repeat
            NextLineNo += 10000;
            GenJournalLine.Init();
            GenJournalLine."Journal Template Name" := BCAFSIIntegrationSetup."Journal Template Name";
            GenJournalLine."Journal Batch Name" := BCAFSIIntegrationSetup."Journal Batch Name";
            GenJournalLine.SetUpNewLine(LastGenJournalLine, 0, true);
            GenJournalLine."Line No." := NextLineNo;
            GenJournalLine.Validate("Posting Date", TempGenJournalLine."Posting Date");
            GenJournalLine.Validate("Document No.", TempGenJournalLine."Document No.");
            GenJournalLine.Validate("Account Type", TempGenJournalLine."Account Type");
            GenJournalLine.Validate("Account No.", TempGenJournalLine."Account No.");
            GenJournalLine.Validate("Bal. Account Type", TempGenJournalLine."Bal. Account Type");
            GenJournalLine.Validate("Bal. Account No.", TempGenJournalLine."Bal. Account No.");
            if TempGenJournalLine.Description <> '' then
                GenJournalLine.Validate(Description, TempGenJournalLine.Description);
            GenJournalLine.Validate(Amount, TempGenJournalLine.Amount);
            GenJournalLine."BCAFSI Staging Entry No." := StagingEntryNo;
            GenJournalLine.Insert(true);
            LastGenJournalLine := GenJournalLine;
            LinesCreated += 1;
        until TempGenJournalLine.Next() = 0;
        exit(LinesCreated);
    end;

    local procedure IsEmptyLine(var TempCSVBuffer: Record "CSV Buffer" temporary; LineNo: Integer): Boolean
    var
        TempLineCSVBuffer: Record "CSV Buffer" temporary;
    begin
        TempLineCSVBuffer.Copy(TempCSVBuffer, true);
        TempLineCSVBuffer.SetRange("Line No.", LineNo);
        TempLineCSVBuffer.SetFilter(Value, '<>%1', '');
        exit(TempLineCSVBuffer.IsEmpty());
    end;

    local procedure GetValue(var TempCSVBuffer: Record "CSV Buffer" temporary; LineNo: Integer; FieldNo: Integer): Text
    begin
        if TempCSVBuffer.Get(LineNo, FieldNo) then
            exit(TempCSVBuffer.Value.Trim());
        exit('');
    end;

    local procedure Utf8CodePage(): Integer
    begin
        exit(65001);
    end;
}
