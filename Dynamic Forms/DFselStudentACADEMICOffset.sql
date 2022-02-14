USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselStudentACADEMICOffset]    Script Date: 02/14/2022 15:50:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Archange Malvoisin
-- Create date: 2022-01-19
-- Description:	Returns student total credits enrolled for the semester.
-- =============================================
CREATE PROCEDURE [custom].[DFselStudentACADEMICOffset] @StudentPCID NVARCHAR(10)
	,@TermOffset INT = 0
AS
BEGIN
	SET NOCOUNT ON;
	--Fix PCID
	SET @StudentPCID = [custom].fnValidatePeopleID(@StudentPCID);

	DECLARE @CurTermId INT = (
			SELECT TermId
			FROM [custom].vwOrderedTerms
			WHERE ACADEMIC_YEAR = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
				AND ACADEMIC_TERM = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)

	SELECT A.PEOPLE_CODE_ID
		,A.ACADEMIC_YEAR
		,A.ACADEMIC_TERM
		,SUM(CAST(TD.CREDIT AS DECIMAL (2,1))) TOTAL_CREDITS
	FROM [custom].vwACADEMIC A
	LEFT JOIN TRANSCRIPTDETAIL TD ON TD.PEOPLE_ID = A.PEOPLE_ID
		AND TD.ACADEMIC_YEAR = A.ACADEMIC_YEAR
		AND TD.ACADEMIC_TERM = A.ACADEMIC_TERM
		AND TD.ACADEMIC_SESSION = A.ACADEMIC_SESSION
		AND TD.ADD_DROP_WAIT = 'A'
	WHERE 1 = 1
		AND A.PEOPLE_CODE_ID = @StudentPCID
		AND A.TermId = (@CurTermId + @TermOffset)
		AND A.ENROLL_SEPARATION = 'ENRL'
		AND A.[STATUS] <> 'N'
		AND A.ENROLL_SEPARATION = 'ENRL'
	GROUP BY A.PEOPLE_CODE_ID
		,A.ACADEMIC_YEAR
		,A.ACADEMIC_TERM
END

GO

