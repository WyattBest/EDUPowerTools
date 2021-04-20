USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselFacultySectionsTaught]    Script Date: 2021-04-19 15:55:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-04-19
-- Description:	List courses a faculty member has taught.
--				@PastTerms controls how many past terms are returned. Blank/0 for only current, 1 for current and previous, etc.
-- =============================================
CREATE PROCEDURE [custom].[DFselFacultySectionsTaught] @FacultyPCID NVARCHAR(10)
	,@PastTerms INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CurTermId INT = [custom].fnGetCurrentTermId()

	SELECT S.SectionId
		,S.ACADEMIC_YEAR
		,S.ACADEMIC_TERM
		,S.ACADEMIC_SESSION
		,S.ACADEMIC_YEAR + '/' + S.ACADEMIC_TERM + '/' + S.EVENT_ID + '/' + S.EVENT_MED_NAME + '/' + S.SECTION [Year/Term/EventId/Med/Section]
		,S.ACADEMIC_YEAR + ' / ' + S.ACADEMIC_TERM + ' / ' + S.EVENT_ID + ' / ' + S.EVENT_LONG_NAME + ' / ' + S.SECTION [Year/Term/EventId/Long/Section]
		,S.EVENT_ID
		,S.SECTION
		,S.EVENT_MED_NAME
		,S.EVENT_LONG_NAME
	FROM SECTIONPER SP
	INNER JOIN [custom].vwOrderedTerms OT
		ON OT.ACADEMIC_YEAR = SP.ACADEMIC_YEAR
			AND OT.ACADEMIC_TERM = SP.ACADEMIC_TERM
			AND OT.TermId BETWEEN (@CurTermId - @PastTerms) AND @CurTermId
	INNER JOIN SECTIONS S
		ON S.ACADEMIC_YEAR = SP.ACADEMIC_YEAR
			AND S.ACADEMIC_TERM = SP.ACADEMIC_TERM
			AND S.ACADEMIC_SESSION = SP.ACADEMIC_SESSION
			AND S.EVENT_ID = SP.EVENT_ID
			AND S.EVENT_SUB_TYPE = SP.EVENT_SUB_TYPE
			AND S.SECTION = SP.SECTION
			AND S.EVENT_STATUS IN ('P', 'A')
	WHERE 1 = 1
		AND SP.PERSON_CODE_ID = @FacultyPCID
	ORDER BY TermId DESC
		,EVENT_ID
		,SECTION
END
GO

