USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselSections]    Script Date: 2021-11-18 12:32:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-09-02
-- Description:	Selects information from SECTIONS. Limited to Active sections unless @SectionId is specified.
--				Feel free to add additional columns.
--
-- 2021-04-21 Wyatt Best:	Added @SectionId parameter and more columns.
-- 2021-11-18 Wyatt Best:	Added EventIdSectionLongName column.
-- =============================================
CREATE PROCEDURE [custom].[DFselSections] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@Curriculum NVARCHAR(6) = NULL
	,@EventId NVARCHAR(15) = NULL
	,@Section NVARCHAR(4) = NULL
	,@SectionId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms submits blanks instead of null.
	SET @Curriculum = NULLIF(@Curriculum, '')
	SET @EventId = NULLIF(@EventId, '')
	SET @Section = NULLIF(@Section, '')

	SELECT ACADEMIC_YEAR
		,ACADEMIC_TERM
		,EVENT_ID
		,EVENT_ID + ': ' + EVENT_MED_NAME [EventIdMedName]
		,EVENT_ID + ': ' + EVENT_LONG_NAME [EventIdLongName]
		,EVENT_ID + ' / ' + SECTION + ': ' + EVENT_LONG_NAME  [EventIdSectionLongName]
		,EVENT_SUB_TYPE
		,SECTION
		,EVENT_MED_NAME
		,EVENT_LONG_NAME
		,ORG_CODE_ID
		,PROGRAM
		,COLLEGE
		,DEPARTMENT
		,CURRICULUM
	FROM SECTIONS S
	WHERE 1 = 1
		AND (
			ACADEMIC_YEAR = @AcademicYear
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
			)
		OR SectionId = @SectionId
	ORDER BY EVENT_ID
		,SECTION
END
GO

