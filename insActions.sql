USE Campus6
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
--				Columns defaulted from Action Definition will remain NULL in #Actions.
--
-- Temp table definition
/*
	CREATE TABLE #Actions (
		[ACTION_ID] NVARCHAR(8) NOT NULL			--Required
		,[PEOPLE_ORG_CODE_ID] NVARCHAR(10) NOT NULL	--Required
		,[SCHEDULED_DATE] DATETIME NULL
		,[SCHEDULED_TIME] DATETIME NULL
		,[EXECUTION_DATE] DATETIME NULL
		,[ACTION_NAME] NVARCHAR(50) NULL
		,[RESP_STAFF] NVARCHAR(10) NULL
		,[COMPLETED_BY] NVARCHAR(10) NULL
		,[REQUIRED] NVARCHAR(1) NOT NULL
		,[RATING] NVARCHAR(3) NULL
		,[RESPONSE] NVARCHAR(6) NULL
		,[CONTACT] NVARCHAR(6) NULL
		,[NOTE] NVARCHAR(max) NULL
		,[COMPLETED] NVARCHAR(1) NULL
		,[WAIVED] NVARCHAR(1) NULL
		,[WAIVED_REASON] NVARCHAR(6) NULL
		,[CANCELED] NVARCHAR(1) NULL
		,[CANCELED_REASON] NVARCHAR(6) NULL
		,[NUM_OF_REMINDERS] INT NULL
		,[ACADEMIC_YEAR] NVARCHAR(4) NULL
		,[ACADEMIC_TERM] NVARCHAR(10) NULL
		,[ACADEMIC_SESSION] NVARCHAR(10) NULL
		,[DURATION] NVARCHAR(10) NULL
		,[DOCUMENT] NVARCHAR(255) NULL
		,[Instruction] NVARCHAR(max) NULL
		,[OPID] NVARCHAR(8) NOT NULL				--Required
		,[ACTIONSCHEDULE_ID] INT NULL
		)
*/
--
-- =============================================
CREATE PROCEDURE [custom].insActions
AS
BEGIN
	SET NOCOUNT ON;

	--Error checking
	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
			)
	BEGIN
		RAISERROR (
				'#Actions temp table does not exist.'
				,11
				,1
				)

		RETURN
	END

	IF 'ACTION_ID' NOT IN (
			SELECT [name]
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
			)
	BEGIN
		RAISERROR (
				'Column ACTION_ID does not exist in #Actions.'
				,11
				,1
				)

		RETURN
	END

	IF 'PEOPLE_ORG_CODE_ID' NOT IN (
			SELECT [name]
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
			)
	BEGIN
		RAISERROR (
				'Column PEOPLE_ORG_CODE_ID does not exist in #Actions.'
				,11
				,1
				)

		RETURN
	END

	DECLARE @Today DATETIME = dbo.fnmakeDate(getdate())
		,@Now DATETIME = dbo.fnmakeTime(getdate());

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
				AND [name] = 'SCHEDULED_TIME'
			)
		ALTER TABLE #Actions ADD [SCHEDULED_TIME] DATETIME NULL;

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
		ALTER TABLE #Actions ADD [REQUIRED] NVARCHAR(1) NULL;

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
				AND [name] = 'CONTACT'
			)
		ALTER TABLE #Actions ADD [CONTACT] NVARCHAR(6) NULL;

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
				AND [name] = 'COMPLETED'
			)
		ALTER TABLE #Actions ADD [COMPLETED] NVARCHAR(1) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'WAVIED'
			)
		ALTER TABLE #Actions ADD [WAIVED] NVARCHAR(1) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'WAIVED_REASON'
			)
		ALTER TABLE #Actions ADD [WAIVED_REASON] NVARCHAR(6) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'CANCELED'
			)
		ALTER TABLE #Actions ADD [CANCELED] NVARCHAR(1) NULL;

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
				AND [name] = 'ACADEMIC_YEAR'
			)
		ALTER TABLE #Actions ADD [ACADEMIC_YEAR] NVARCHAR(4) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'ACADEMIC_TERM'
			)
		ALTER TABLE #Actions ADD [ACADEMIC_TERM] NVARCHAR(10) NULL;

	IF NOT EXISTS (
			SELECT *
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Actions')
				AND [name] = 'ACADEMIC_SESSION'
			)
		ALTER TABLE #Actions ADD [ACADEMIC_SESSION] NVARCHAR(10) NULL;

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

	--Add a primary key to #Actions
	ALTER TABLE #Actions ADD  [tmpKey] INT IDENTITY PRIMARY KEY;

	--Create a table to hold new ACTIONSCHEDULE_ID's
	CREATE TABLE #NewActionIds (
		 [tmpKey] INT NOT NULL
		,[ACTIONSCHEDULE_ID] INT NOT NULL
		);

	--A stupid step to prevent compiler from erroring because it doesn't recognize the new columns as existing.
	--Might be able to remove in a future version of SQL Server.
	SELECT *
	INTO #ActionsIntermediate
	FROM #Actions;

	--Insert into ACTIONSCHEDULE. A MERGE statement is used to allow returning columns we didn't insert, specifically #Actions. [tmpKey].
	MERGE INTO ACTIONSCHEDULE AS T
	USING (
		SELECT A.[ACTION_ID]
			,LEFT(PEOPLE_ORG_CODE_ID, 1) AS [PEOPLE_ORG_CODE]
			,RIGHT(PEOPLE_ORG_CODE_ID, 9) AS [PEOPLE_ORG_ID]
			,[PEOPLE_ORG_CODE_ID]
			,@Today AS [REQUEST_DATE]
			,@Now AS [REQUEST_TIME]
			,COALESCE(A.[SCHEDULED_DATE], @Today) AS [SCHEDULED_DATE]
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
			,COALESCE(A.ACTION_NAME, CA.ACTION_NAME) AS [ACTION_NAME]
			,CA.[OFFICE]
			,CA.[TYPE]
			,A.[RESP_STAFF]
			,[COMPLETED_BY]
			,COALESCE(A.[REQUIRED], CA.REQUIRED) AS [REQUIRED]
			,CA.[PRIORITY]
			,[RATING]
			,[RESPONSE]
			,[CONTACT]
			,COALESCE(A.[SCHEDULED_TIME], @Now) AS [SCHEDULED_TIME]
			,A.[NOTE]
			,A.ACTION_ID + convert(NVARCHAR(4), datepart(yy, GETDATE())) + convert(NVARCHAR(2), datepart(mm, GETDATE())) + convert(NVARCHAR(2), datepart(dd, GETDATE())) + convert(NVARCHAR(2), datepart(hh, GETDATE())) + convert(NVARCHAR(2), datepart(mi, GETDATE())) + convert(NVARCHAR(4), datepart(ms, GETDATE())) AS [UNIQUE_KEY]
			,COALESCE([COMPLETED], 'N') AS [COMPLETED]
			,COALESCE([WAIVED], 'N') AS [WAIVED]
			,[WAIVED_REASON]
			,COALESCE([CANCELED], 'N') AS [CANCELED]
			,[CANCELED_REASON]
			,COALESCE([NUM_OF_REMINDERS], 0) AS [NUM_OF_REMINDERS]
			,[ACADEMIC_YEAR]
			,[ACADEMIC_TERM]
			,[ACADEMIC_SESSION]
			,0 AS [RULE_ID]
			,0 AS [SEQ_NUM]
			,[DURATION]
			,[DOCUMENT]
			,COALESCE(A.[Instruction], CA.[Instruction]) AS [Instruction]
			, [tmpKey]
		FROM #ActionsIntermediate A
		INNER JOIN [ACTION] CA
			ON CA.ACTION_ID = A.ACTION_ID
		) AS A
		--Always-false condition forces an INSERT instead of an UPDATE.
		ON 1 = 0
	WHEN NOT MATCHED
		THEN
			INSERT (
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
			VALUES (
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
	OUTPUT A. [tmpKey]
		,inserted.ACTIONSCHEDULE_ID
	INTO #NewActionIds;

	--Update #Actions with the new ACTIONSCHEDULE_ID's
	--Using EXEC because the compiler doens't know that  [tmpKey] exists.
	EXEC (
	'UPDATE A
	SET [ACTIONSCHEDULE_ID] = B.[ActionSchedule_Id]
	FROM #Actions A
	INNER JOIN #NewActionIds B
		ON A. [tmpKey] = B. [tmpKey]'
			)
END
GO


