USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselACADEMICCurrent]    Script Date: 2021-04-20 14:20:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-07-02
-- Description:	Returns current PDC, credits, and ENROLL_SEPARATION for a student.

-- 2021-03-23 Archange Malvoisin:	Added field DEPARTMENT which provides student purpose in the result set. 
-- =============================================
CREATE PROCEDURE [custom].[DFselACADEMICCurrent] @StudentPCID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CurTermId INT = (
			SELECT TermId
			FROM [custom].vwOrderedTerms
			WHERE ACADEMIC_YEAR = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
				AND ACADEMIC_TERM = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)

	SELECT A.ACADEMIC_YEAR
		,A.ACADEMIC_TERM
		,PROGRAM
		,DEPARTMENT
		,CP.SHORT_DESC [ProgramShort]
		,CP.MEDIUM_DESC [ProgramMedium]
		,CP.LONG_DESC [ProgramLong]
		,DEGREE
		,CD.SHORT_DESC [DegreeShort]
		,CD.MEDIUM_DESC [DegreeMedium]
		,CD.LONG_DESC [DegreeLong]
		,CURRICULUM
		,CC.SHORT_DESC [CurriculumShort]
		,CC.MEDIUM_DESC [CurriculumMedium]
		,CC.LONG_DESC [CurriculumLong]
		,CREDITS
		,ENROLL_SEPARATION
	FROM [custom].vwACADEMIC A
	INNER JOIN CODE_PROGRAM CP
		ON CP.CODE_VALUE_KEY = A.PROGRAM
	INNER JOIN CODE_DEGREE CD
		ON CD.CODE_VALUE_KEY = A.DEGREE
	INNER JOIN CODE_CURRICULUM CC
		ON CC.CODE_VALUE_KEY = A.CURRICULUM
	WHERE 1 = 1
		AND A.PEOPLE_CODE_ID = @StudentPCID
		AND A.TermId = @CurTermId
		AND A.[STATUS] <> 'N'
END
GO

