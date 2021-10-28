USE Campus6_test
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-10-28
-- Description:	Batch insert into ACTIONSCHEDULE. Requires a temp table #Actions to already exists in the same session.
--				This procedure will add ACTIONSCHEDULE_ID's to the #Actions table for the caller's use.
--
-- Temp table definition
/*
		CREATE TABLE #Actions (
			[ACTION_ID] nvarchar(8) NOT NULL				--Required
			,[PEOPLE_ORG_CODE_ID] nvarchar(10) NOT NULL	--Required
			,[SCHEDULED_DATE] datetime NULL
			,[EXECUTION_DATE] datetime NULL			
			,[ACTION_NAME] nvarchar(50) NULL			
			,[RESP_STAFF] nvarchar(10) NULL			
			,[COMPLETED_BY] nvarchar(10) NULL			
			,[REQUIRED] nvarchar(1) NOT NULL			
			,[RATING] nvarchar(3) NULL				
			,[RESPONSE] nvarchar(6) NULL				
			,[CONTACT] nvarchar(6) NULL				
			,[SCHEDULED_TIME] datetime NULL
			,[NOTE] nvarchar(max) NULL
			,[COMPLETED] nvarchar(1) NULL
			,[WAIVED] nvarchar(1) NULL
			,[WAIVED_REASON] nvarchar(6) NULL
			,[CANCELED] nvarchar(1) NULL
			,[CANCELED_REASON] nvarchar(6) NULL
			,[NUM_OF_REMINDERS] int NULL
			,[ACADEMIC_YEAR] nvarchar(4) NULL				--Required, can be null
			,[ACADEMIC_TERM] nvarchar(10) NULL			--Required, can be null
			,[ACADEMIC_SESSION] nvarchar(10) NULL			--Required, can be null
			,[DURATION] nvarchar(10) NULL
			,[DOCUMENT] nvarchar(255) NULL
			,[Instruction] nvarchar(max) NULL
			,[OPID] nvarchar(8) NOT NULL					--Required
			,[ACTIONSCHEDULE_ID] INT NULL
			)
*/
--
-- =============================================
CREATE PROCEDURE [custom].insAction
AS
BEGIN
	SET NOCOUNT ON;

	--Error checking
	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
			)
		RAISERROR (
				'#Actions temp table does not exist.'
				,11
				,1
				);

	IF 'ACTION_ID' NOT IN (
			SELECT [name]
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
			)
		RAISERROR (
				'Column ACTION_ID does not exist in #Actions.'
				,11
				,1
				);

	IF 'PEOPLE_ORG_CODE_ID' NOT IN (
			SELECT [name]
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
			)
		RAISERROR (
				'Column PEOPLE_ORG_CODE_ID does not exist in #Actions.'
				,11
				,1
				);

	DECLARE @Today DATETIME = dbo.fnmakeDate(getdate())
		,@Now DATETIME = dbo.fnmakeTime(getdate());

	--Add a primary key to #Actions
	ALTER TABLE #Actions ADD [Key] INT IDENTITY PRIMARY KEY;

	--Declare a table to hold new ACTIONSCHEDULE_ID's
	DECLARE @NewActionIds TABLE (
		[Key] INT NOT NULL
		,[ACTIONSCHEDULE_ID] INT NOT NULL
		);

	--Add optional columns to #Actions
	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'SCHEDULED_DATE'
			)
		ALTER TABLE #Actions ADD [SCHEDULED_DATE] DATETIME NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'EXECUTION_DATE'
			)
		ALTER TABLE #Actions ADD [EXECUTION_DATE] DATETIME NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'ACTION_NAME'
			)
		ALTER TABLE #Actions ADD [ACTION_NAME] NVARCHAR(50) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'RESP_STAFF'
			)
		ALTER TABLE #Actions ADD [RESP_STAFF] NVARCHAR(10) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'COMPLETED_BY'
			)
		ALTER TABLE #Actions ADD [COMPLETED_BY] NVARCHAR(10) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'REQUIRED'
			)
		ALTER TABLE #Actions ADD [REQUIRED] NVARCHAR(1) NOT NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'RATING'
			)
		ALTER TABLE #Actions ADD [RATING] NVARCHAR(3) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'RESPONSE'
			)
		ALTER TABLE #Actions ADD [RESPONSE] NVARCHAR(max) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'NOTE'
			)
		ALTER TABLE #Actions ADD [NOTE] NVARCHAR(max) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'CANCELED_REASON'
			)
		ALTER TABLE #Actions ADD [CANCELED_REASON] NVARCHAR(max) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'NUM_OF_REMINDERS'
			)
		ALTER TABLE #Actions ADD [NUM_OF_REMINDERS] INT NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'DURATION'
			)
		ALTER TABLE #Actions ADD [DURATION] NVARCHAR(10) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'DOCUMENT'
			)
		ALTER TABLE #Actions ADD [DOCUMENT] NVARCHAR(255) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'Instruction'
			)
		ALTER TABLE #Actions ADD [Instruction] NVARCHAR(max) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = object_id('tempdb..#Actions')
				AND [name] = 'ACTIONSCHEDULE_ID'
			)
		ALTER TABLE #Actions ADD [ACTIONSCHEDULE_ID] INT NULL;

	--INSERT into ACTIONSCHEDULE and capture the new ID's.
	INSERT INTO [ACTIONSCHEDULE] (
		[ACTION_ID]
		,[PEOPLE_ORG_CODE]
		,[PEOPLE_ORG_ID]
		,[PEOPLE_ORG_CODE_ID]
		,[REQUEST_DATE]
		,[REQUEST_TIME]
		,[SCHEDULED_DATE]
		,[EXECUTION_DATE]
		,[CREATE_DATE]
		,[CREATE_TIME]
		,[CREATE_OPID]
		,[CREATE_TERMINAL]
		,[REVISION_DATE]
		,[REVISION_TIME]
		,[REVISION_OPID]
		,[REVISION_TERMINAL]
		,[ABT_JOIN]
		,[ACTION_NAME]
		,[OFFICE]
		,[TYPE]
		,[RESP_STAFF]
		,[COMPLETED_BY]
		,[REQUIRED]
		,[PRIORITY]
		,[RATING]
		,[RESPONSE]
		,[CONTACT]
		,[SCHEDULED_TIME]
		,[NOTE]
		,[UNIQUE_KEY]
		,[COMPLETED]
		,[WAIVED]
		,[WAIVED_REASON]
		,[CANCELED]
		,[CANCELED_REASON]
		,[NUM_OF_REMINDERS]
		,[ACADEMIC_YEAR]
		,[ACADEMIC_TERM]
		,[ACADEMIC_SESSION]
		,[RULE_ID]
		,[SEQ_NUM]
		,[DURATION]
		,[DOCUMENT]
		,[Instruction]
		)
	OUTPUT INSERTED.ACTIONSCHEDULE_ID
	INTO @NewActionIds
	SELECT A.[ACTION_ID]
		,LEFT(PEOPLE_ORG_CODE_ID, 1) AS [PEOPLE_ORG_CODE]
		,RIGHT(PEOPLE_ORG_CODE_ID, 9) AS [PEOPLE_ORG_ID]
		,[PEOPLE_ORG_CODE_ID]
		,@Today AS [REQUEST_DATE]
		,@Now AS [REQUEST_TIME]
		,[SCHEDULED_DATE]
		,[EXECUTION_DATE]
		,@Today AS [CREATE_DATE]
		,@Now AS [CREATE_TIME]
		,A.OPID AS [CREATE_OPID]
		,'0001' AS [CREATE_TERMINAL]
		,@Today AS [REVISION_DATE]
		,@Now AS [REVISION_TIME]
		,OPID AS [REVISION_OPID]
		,'0001' AS [REVISION_TERMINAL]
		,'*' AS [ABT_JOIN]
		,COALESCE(ACTION_NAME, CA.ACTION_NAME) AS [ACTION_NAME]
		,CA.[OFFICE]
		,CA.[TYPE]
		,A.[RESP_STAFF]
		,[COMPLETED_BY]
		,COALESCE(A.[REQUIRED], CA.REQUIRED) AS [REQUIRED]
		,CA.[PRIORITY]
		,COALESCE(A.[RATING], CA.RATING) AS [RATING]
		,COALESCE(A.[RESPONSE], CA.RESPONSE) AS [RESPONSE]
		,[CONTACT]
		,COALESCE(@Now, A.SCHEDULED_TIME) AS [SCHEDULED_TIME]
		,[NOTE]
		,A.ACTION_ID + convert(NVARCHAR(4), datepart(yy, GETDATE())) + convert(NVARCHAR(2), datepart(mm, GETDATE())) + convert(NVARCHAR(2), datepart(dd, GETDATE())) + convert(NVARCHAR(2), datepart(hh, GETDATE())) + convert(NVARCHAR(2), datepart(mi, GETDATE())) + convert(NVARCHAR(4), datepart(ms, GETDATE())) AS [UNIQUE_KEY]
		,[COMPLETED]
		,[WAIVED]
		,[WAIVED_REASON]
		,[CANCELED]
		,[CANCELED_REASON]
		,[NUM_OF_REMINDERS]
		,[ACADEMIC_YEAR]
		,[ACADEMIC_TERM]
		,[ACADEMIC_SESSION]
		,0 AS [RULE_ID]
		,0 AS [SEQ_NUM]
		,[DURATION]
		,[DOCUMENT]
		,COALESCE(A.INSTRUCTION, CA.INSTRUCTION) AS [Instruction]
	FROM #Actions A
	INNER JOIN [ACTION] CA
		ON CA.[ACTION_ID] = A.[ACTION_ID]

	--Update #Actions with the new ACTIONSCHEDULE_ID's
	UPDATE A
	SET [ACTIONSCHEDULE_ID] = B.[ActionSchedule_Id]
	FROM #Actions A
	INNER JOIN @NewActionIds B
		ON A.[Key] = B.[Key]
END
GO


