USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselStudentACADEMICReg]    Script Date: 2021-11-18 12:37:00 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-11-18
-- Description:	Returns YT, PDC, credits, DEPARTMENT, and ENROLL_SEPARATION for a student.
--				YT is limited to terms with registration and/or Add/Drop currently open.
-- =============================================
CREATE PROCEDURE [custom].[DFselStudentACADEMICReg] @StudentPCID NVARCHAR(10)
	,@PeriodType NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;
	
	--Fix PCID
	SET @StudentPCID = [custom].fnValidatePeopleID(@StudentPCID);

	DECLARE @TermId INT

	--Future flexbility to add more @PeriodType options
	SET @TermId = CASE @PeriodType
			--Current date is between pre-registration open and the end of add/drop period
			WHEN 'RegAddDrop'
				THEN (
						SELECT TermId
						FROM [custom].vwOrderedTerms OT
						INNER JOIN ACADEMICCALENDAR AC
							ON AC.ACADEMIC_YEAR = OT.ACADEMIC_YEAR
								AND AC.ACADEMIC_TERM = OT.ACADEMIC_TERM
						WHERE 1 = 1
							AND AC.ACADEMIC_SESSION = '01'
							AND GETDATE() BETWEEN PRE_REG_DATE AND GRADE_PENALTY_DATE
						)
			ELSE NULL
			END

	SELECT TOP 1 A.PEOPLE_CODE_ID
		,A.ACADEMIC_YEAR
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
		AND A.TermId = @TermId
		AND A.[STATUS] <> 'N'
		AND A.ACADEMIC_FLAG = 'Y'
		AND A.PRIMARY_FLAG = 'Y'
		AND A.ENROLL_SEPARATION NOT IN (
			SELECT CODE_VALUE_KEY
			FROM CODE_ENROLLMENT
			WHERE REQUIRE_SEPDATE = 'Y'
			)
	ORDER BY A.TRANSCRIPT_SEQ DESC
END
GO

