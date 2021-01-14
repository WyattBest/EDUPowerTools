USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselActionCodes]    Script Date: 2021-01-12 10:24:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-01-12
-- Description:	Inserts a record into the VIOLATIONS table if it doesn't already exist for that PCID + Y/T/S + EVENT_ID/SECTION/EVENT_SUB_TYPE.
--				Used by the LEC to track which sections a student is receiving tutoring for.
-- =============================================
CREATE PROCEDURE [custom].[DFinsViolation] @TranscriptDetailId INT
	,@Violation NVARCHAR(10)
	,@ViolationDate DATE = NULL
	,@ReportedBy NVARCHAR(10) = NULL
	,@Opid NVARCHAR(8) = 'DYNFORMS'
	,@AllowDuplicates BIT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = (
			SELECT dbo.fnMakeDate(GETDATE())
			)
		,@Now DATETIME = (
			SELECT dbo.fnMakeTime(GETDATE())
			)
		,@ViolationExists BIT = 0

	--Dynamic Forms has an annoying habit of passing blanks instead of nulls/omitting parameters
	IF @Opid = ''
		OR @Opid IS NULL
		SET @Opid = 'DYNFORMS'

	IF @ReportedBy = ''
		SET @ReportedBy = NULL

	IF @ViolationDate = ''
		OR @ViolationDate IS NULL
		SET @ViolationDate = @Today

	--Error checking
	IF NOT EXISTS (
			SELECT *
			FROM TRANSCRIPTDETAIL
			WHERE TranscriptDetailId = @TranscriptDetailId
			)
		RAISERROR (
				'@TranscriptDetailId not found in database.'
				,11
				,1
				)

	IF NOT EXISTS (
			SELECT *
			FROM CODE_VIOLATIONS
			WHERE CODE_VALUE_KEY = @Violation
			)
		RAISERROR (
				'@Violation not found in database.'
				,11
				,1
				)

	IF NOT EXISTS (
			SELECT *
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @ReportedBy
			)
		RAISERROR (
				'@ReportedBy not found in database.'
				,11
				,1
				)

	--Does this violation already exist?
	IF EXISTS (
			SELECT 1
			FROM VIOLATIONS V
			INNER JOIN TRANSCRIPTDETAIL TD
				ON TranscriptDetailId = @TranscriptDetailId
					AND V.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
					AND V.ACADEMIC_TERM = TD.ACADEMIC_TERM
					AND V.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
					AND V.EVENT_ID = TD.EVENT_ID
					AND V.EVENT_SUB_TYPE = TD.EVENT_SUB_TYPE
					AND V.SECTION = TD.SECTION
			WHERE 1 = 1
				AND VIOLATION = @Violation
			)
		SET @ViolationExists = 1

	--Insert unique violation, insert duplicate violation, or do nothing depending on @AllowDuplicates
	IF (
			@ViolationExists = 1
			AND @AllowDuplicates = 1
			)
		OR @ViolationExists = 0
	BEGIN
		INSERT INTO [dbo].[VIOLATIONS] (
			[PEOPLE_CODE_ID]
			,[ACADEMIC_YEAR]
			,[ACADEMIC_TERM]
			,[ACADEMIC_SESSION]
			,[EVENT_ID]
			,[EVENT_SUB_TYPE]
			,[SECTION]
			,[VIOLATION_DATE]
			,[VIOLATION]
			,[REPORTED_BY_ID]
			,[COMMENTS]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			)
		SELECT PEOPLE_CODE_ID [PEOPLE_CODE_ID]
			,[ACADEMIC_YEAR]
			,[ACADEMIC_TERM]
			,[ACADEMIC_SESSION]
			,[EVENT_ID]
			,[EVENT_SUB_TYPE]
			,[SECTION]
			,@ViolationDate [VIOLATION_DATE]
			,@Violation [VIOLATION]
			,@ReportedBy [REPORTED_BY_ID]
			,NULL [COMMENTS]
			,@Today [CREATE_DATE]
			,@Now [CREATE_TIME]
			,@Opid [CREATE_OPID]
			,'0001' [CREATE_TERMINAL]
			,@Today [REVISION_DATE]
			,@Now [REVISION_TIME]
			,@Opid [REVISION_OPID]
			,'0001' [REVISION_TERMINAL]
		FROM TRANSCRIPTDETAIL TD
		WHERE TranscriptDetailId = @TranscriptDetailId

		SELECT @@ROWCOUNT [InsertedCount]
	END
	ELSE
		SELECT 0 [InsertedCount]
END
