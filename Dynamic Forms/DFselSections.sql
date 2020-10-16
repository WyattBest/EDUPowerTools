USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselSections]    Script Date: 2020-10-16 11:54:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-09-02
-- Description:	Selects information from SECTIONS. Limited to active sections.
--				Feel free to add additional columns.
-- =============================================
CREATE PROCEDURE [custom].[DFselSections] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@Curriculum NVARCHAR(6) = NULL
	,@EventId NVARCHAR(15) = NULL
	,@Section NVARCHAR(4) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms submits blanks instead of null.
	SELECT @Curriculum = CASE WHEN @Curriculum = '' THEN NULL ELSE @Curriculum END
		,@EventId = CASE WHEN @EventId = '' THEN NULL ELSE @EventId END
		,@Section = CASE WHEN @Section = '' THEN NULL ELSE @Section END

	SELECT ACADEMIC_YEAR
		,ACADEMIC_TERM
		,EVENT_ID
		,EVENT_ID + ': ' + EVENT_MED_NAME [EventIdMedName]
		,EVENT_ID + ': ' + EVENT_LONG_NAME [EventIdLongName]
		,EVENT_SUB_TYPE
		,SECTION
		,EVENT_MED_NAME
		,EVENT_LONG_NAME
		,ORG_CODE_ID
	FROM SECTIONS S
	WHERE ACADEMIC_YEAR = @AcademicYear
		AND ACADEMIC_TERM = @AcademicTerm
		AND (
			EVENT_ID = @EventId
			OR @EventId IS NULL
			)
		AND (
			SECTION = @Section
			OR @Section IS NULL
			)
		AND (
			@Curriculum IS NULL
			OR EVENT_ID IN (
				SELECT DR.EVENT_ID
				FROM DEGREQEVENT DR
				WHERE MATRIC_YEAR = ACADEMIC_YEAR
					AND MATRIC_TERM = ACADEMIC_TERM
					AND DR.CURRICULUM = @Curriculum
				)
			)
		AND EVENT_STATUS = 'A'
	ORDER BY EVENT_ID
		,SECTION
END
GO

