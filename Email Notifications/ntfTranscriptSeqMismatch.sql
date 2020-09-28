USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[ntfTranscriptSeqMismatch]    Script Date: 2020-09-28 09:08:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-09-24
-- Description:	Email registrar about TRANSCRIPTDETAIL rows without an ACADEMIC record in the same TRANSCRIPT_SEQ.
--
-- 2020-09-28 Wyatt Best:	Don't send email for zero rows.
-- =============================================
CREATE PROCEDURE [custom].[ntfTranscriptSeqMismatch]
AS
BEGIN
	SET XACT_ABORT ON;--Stop on all errors.

	BEGIN TRAN SendEmails

	--Email subject and body
	DECLARE @Subject NVARCHAR(100) = 'Transcript Sequence Error'
		,@Body NVARCHAR(MAX) = '<style type="text/css">
			table.merged {
				width: 100%;
				border-width: 1px;
				border-color: #a5a5a5;
				border-collapse: collapse;
			}

			table.merged th {
				border-width: 1px;
				border-style: solid;
				border-color: #a5a5a5;
				background-color: #dedede;
				text-align: left;
				padding: 5px;
			}

			table.merged td {
				border-width: 1px;
				border-style: solid;
				border-color: #a5a5a5;
				background-color: #ffffff;
				padding: 5px;
			}
		</style>
		<p>The following students have a transcript sequence mismatch between their course registrations and Academic record(s):</p>
									<p><strong>{{table}}</strong></p>'
		,@CurYear NVARCHAR(4) = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
		,@CurTerm NVARCHAR(10) = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM');

	--Find TRANSCRIPTDETAIL rows without corresponding ACADEMIC row according to TRANSCRIPT_SEQ
	SELECT TD.PEOPLE_ID
		,TD.PEOPLE_CODE_ID
		,TD.EVENT_ID
		,TD.SECTION
		,TD.TRANSCRIPT_SEQ
	INTO #RogueTS
	FROM TRANSCRIPTDETAIL TD
	WHERE 1 = 1
		AND ACADEMIC_YEAR = @CurYear
		AND ACADEMIC_TERM = @CurTerm
		AND ADD_DROP_WAIT = 'A'
		AND NOT EXISTS (
			SELECT *
			FROM ACADEMIC A
			WHERE A.PEOPLE_ID = TD.PEOPLE_ID
				AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
				AND TD.ACADEMIC_TERM = A.ACADEMIC_TERM
				AND TD.TRANSCRIPT_SEQ = A.TRANSCRIPT_SEQ
				AND A.ACADEMIC_SESSION > ''
			)

	IF EXISTS (
			SELECT *
			FROM #RogueTS
			)
	BEGIN
		--Create #Messages table by joining TRANSCRIPTDETAIL on ACADEMIC
		SELECT 'selfservice@mcny.edu' [from]
			,'registrar@mcny.edu' [to]
			,'wbest@mcny.edu' [bcc]
			,0 [toTypeFlag]
			,@Subject [subject]
			,@Body [body]
			,0 [formatBodyFlag]
			,(
				SELECT 'merged' AS [@class]
					,(
						SELECT 'ID' [th]
							,'Name' [th]
							,'Course' [th]
							,'Rogue Sequence' [th]
						FOR XML raw('tr')
							,ELEMENTS
							,TYPE
						) AS 'thead'
					,(
						SELECT PEOPLE_ID [td]
							,dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'FN |LN') [td]
							,EVENT_ID + ' / ' + SECTION [td]
							,TRANSCRIPT_SEQ [td]
						FROM #RogueTS
						FOR XML RAW('tr')
							,ELEMENTS
							,TYPE
						) AS 'tbody'
				FOR XML PATH('table')
				) [Table]
		INTO #Messages;

		--Supply merge fields in the body
		UPDATE #Messages
		SET body = REPLACE(body, '{{table}}', [Table]);

		----Debug
		--SELECT *
		--FROM #Messages

		--Send emails
		EXEC [custom].[spSendEmails];

		DROP TABLE #Messages, #RogueTS;
	END

	COMMIT TRAN SendEmails
END
