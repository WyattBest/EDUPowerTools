USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[ntfSectionCanceled]    Script Date: 2020-04-27 14:26:15 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-01-14
-- Description:	Emails students when a section they are registered for is canceled.
--				Note that message body comes from the Note on the Action Definition for CANCSECT
--
-- 2020-01-14 Wyatt Best: Moved code from inside job to stored procedure.
-- 2020-04-27 Wyatt Best: Realized that TRANSCRIPTMARKETING wasn't matching because REVISION_DATE/TIME are not updated during cancel process!
--						  Implemented a LIKE match that works much better. False positives are possible but unlikely for MCNY. EVENT_ID pattern is school-specific.
-- =============================================
CREATE PROCEDURE [custom].[ntfSectionCanceled]
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;--Stop on all errors.

	BEGIN TRAN SendEmails

	--Select CANCSECT actions to process into #Messages table
	SELECT 'selfservice@mcny.edu' [from]
		,[PEOPLE_ORG_CODE_ID] [toId]
		,'P000000000' [bccId] --BCC Student Services
		,0 [toTypeFlag]
		,AC.[ACTION_NAME] [subject]
		,AC.[NOTE] [body]
		,CASE 
			WHEN oTM.[EVENT_ID] IS NOT NULL
				THEN oTM.[EVENT_ID] + '/' + CST.[LONG_DESC] + '/' + oTM.[SECTION] + ' (' + [EVENT_LONG_NAME] + ')'
			WHEN PATINDEX('%20__/%/%/%', ACS.[ACTION_NAME]) > 0
				THEN SUBSTRING(ACS.[ACTION_NAME], CHARINDEX('/', ACS.[ACTION_NAME], CHARINDEX('/', ACS.[ACTION_NAME], 21) + 1) + 1, 100) + '...' --Try to extract section name from action name (can be unfortunately truncated)
			ELSE '(unknown)'
			END AS [sectionCode]
		,1 [formatBodyFlag]
		,[UNIQUE_KEY] [uniqueKey]
	INTO #Messages
	FROM [ACTIONSCHEDULE] ACS
	INNER JOIN [ACTION] AC
		ON AC.[ACTION_ID] = ACS.[ACTION_ID]
	OUTER APPLY (
		SELECT ACADEMIC_YEAR
			,ACADEMIC_TERM
			,ACADEMIC_SESSION
			,EVENT_ID
			,EVENT_SUB_TYPE
			,SECTION
		FROM TRANSCRIPTMARKETING TM
		WHERE TM.[PEOPLE_CODE_ID] = ACS.[PEOPLE_ORG_CODE_ID]
			AND TM.ACADEMIC_YEAR = ACS.ACADEMIC_YEAR
			AND TM.ACADEMIC_TERM = ACS.ACADEMIC_TERM
			AND TM.ACADEMIC_SESSION = ACS.ACADEMIC_SESSION
			AND TM.[DROP_REASON] = 'CANCEL'
			AND TM.EVENT_ID = SUBSTRING(ACS.ACTION_NAME, PATINDEX('%/[A-Z][A-Z][A-Z] [0-9][0-9][0-9] [A-Z][A-Z][A-Z]/%', ACS.ACTION_NAME) + 1, 11) --EVENT_ID pattern not applicable to all schools
			AND TM.SECTION LIKE (SUBSTRING(ACS.ACTION_NAME, LEN(ACS.ACTION_NAME) - CHARINDEX('/', REVERSE(ACS.[ACTION_NAME])) + 2, 50) + '%')
		) oTM
	LEFT JOIN [SECTIONS] S
		ON S.[ACADEMIC_YEAR] = oTM.ACADEMIC_YEAR
			AND S.ACADEMIC_TERM = oTM.ACADEMIC_TERM
			AND S.ACADEMIC_SESSION = oTM.ACADEMIC_SESSION
			AND S.EVENT_ID = oTM.EVENT_ID
			AND S.EVENT_SUB_TYPE = oTM.EVENT_SUB_TYPE
			AND S.SECTION = oTM.SECTION
	LEFT JOIN CODE_EVENTSUBTYPE CST
		ON CST.CODE_VALUE = oTM.EVENT_SUB_TYPE
	WHERE ACS.[ACTION_ID] = 'CANCSECT'
		AND [COMPLETED] <> 'Y'
		AND [CANCELED] <> 'Y'
		AND [WAIVED] <> 'Y';

	--SELECT * FROM #Messages; --Debug
	--Supply student names
	UPDATE #Messages
	SET [body] = REPLACE([body], '{{FIRST_NAME}}', dbo.fnPeopleOrgName([toId], 'DN'));

	--Supply section names
	UPDATE #Messages
	SET [body] = REPLACE([body], '{{SECTION}}', [sectionCode]);

	ALTER TABLE #Messages

	DROP COLUMN [sectionCode];

	--Prepare table to capture results
	CREATE TABLE #MessagesResults (
		[from] NVARCHAR(255) NOT NULL
		,[fromId] NVARCHAR(10) NULL
		,[to] NVARCHAR(255) NULL
		,[toId] NVARCHAR(10) NOT NULL
		,[toTypeFlag] SMALLINT NOT NULL
		,[cc] NVARCHAR(255) NULL
		,[ccId] NVARCHAR(10) NULL
		,[bcc] NVARCHAR(255) NULL
		,[bccId] NVARCHAR(10) NULL
		,[subject] NVARCHAR(255) NOT NULL
		,[body] NVARCHAR(MAX) NOT NULL
		,[formatBodyFlag] SMALLINT NOT NULL
		,[uniqueKey] NVARCHAR(255) NULL
		,[MESSAGEID] INT NULL
		);

	--Actually send messages and capture results
	INSERT INTO #MessagesResults
	EXEC [custom].[spSendEmails];

	--SELECT * FROM #MessagesResults; --Debug
	--Complete Actions upon successful sending
	UPDATE ACS
	SET [COMPLETED] = 'Y'
		,[EXECUTION_DATE] = [dbo].[fnMakeDate](GETDATE())
		,[COMPLETED_BY] = 'P000000000' --System Administrator
	FROM [ACTIONSCHEDULE] AS ACS
	INNER JOIN #MessagesResults AS MR
		ON MR.[uniqueKey] = ACS.[UNIQUE_KEY]
			AND MR.[toId] = ACS.[PEOPLE_ORG_CODE_ID];

	DROP TABLE #Messages
		,#MessagesResults;

	COMMIT TRAN SendEmails
END
