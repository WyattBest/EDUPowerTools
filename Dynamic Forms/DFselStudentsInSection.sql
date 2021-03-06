USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselStudentsInSection]    Script Date: 2021-04-22 11:50:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-04-19
-- Description:	Return students enrolled in a particular section.
-- =============================================
CREATE PROCEDURE [custom].[DFselStudentsInSection] @SectionId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT TD.PEOPLE_CODE_ID
		,TranscriptDetailId
		,dbo.fnPeopleOrgName(TD.PEOPLE_CODE_ID, 'DN |LN') [FullName]
		,dbo.fnPeopleOrgName(TD.PEOPLE_CODE_ID, 'DN') [FirstName]
		,dbo.fnPeopleOrgName(TD.PEOPLE_CODE_ID, 'LN') [LastName]
		,dbo.fnGetPrimaryEmail(TD.PEOPLE_CODE_ID) PrimaryEmail
		,TD.PEOPLE_CODE_ID + ', ' + dbo.fnPeopleOrgName(TD.PEOPLE_CODE_ID, 'DN |LN') + ', ' + dbo.fnGetPrimaryEmail(TD.PEOPLE_CODE_ID) AS [SearchableDesc]
		,*
	FROM SECTIONS S
	INNER JOIN TRANSCRIPTDETAIL TD
		ON TD.ACADEMIC_YEAR = S.ACADEMIC_YEAR
			AND TD.ACADEMIC_TERM = S.ACADEMIC_TERM
			AND TD.ACADEMIC_SESSION = S.ACADEMIC_SESSION
			AND TD.EVENT_ID = S.EVENT_ID
			AND TD.EVENT_SUB_TYPE = S.EVENT_SUB_TYPE
			AND TD.SECTION = S.SECTION
	INNER JOIN ACADEMIC A
		ON A.PEOPLE_CODE_ID = TD.PEOPLE_CODE_ID
			AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
			AND A.ACADEMIC_TERM = TD.ACADEMIC_TERM
			AND A.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
			AND A.TRANSCRIPT_SEQ = TD.TRANSCRIPT_SEQ
			and PRIMARY_FLAG = 'Y'
			AND A.[STATUS] IN ('A','G')
			AND A.ENROLL_SEPARATION NOT IN (
				SELECT CODE_VALUE_KEY
				FROM CODE_ENROLLMENT
				WHERE REQUIRE_SEPDATE = 'Y'
				)
	WHERE 1 = 1
		AND S.SectionId = @SectionId
		AND FINAL_GRADE NOT IN (
			SELECT GRADE
			FROM GRADEVALUES GV
			WHERE GV.ACADEMIC_YEAR = S.ACADEMIC_YEAR
				AND GV.ACADEMIC_TERM = S.ACADEMIC_TERM
				AND GV.CREDIT_TYPE = TD.CREDIT_TYPE
				AND WITHDRAWN_GRADE = 'Y'
			)
END
GO

