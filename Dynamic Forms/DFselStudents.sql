USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselStudents]    Script Date: 2021-04-20 14:22:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-03-08
-- Description:	Return a list of students in the current term and (optionally) past terms.
--
-- 2021-03-12 Archange Malvosin:	Added emails, FirstName, and LastName.
-- 2021-04-20 Wyatt Best:			Added optional parameter to include n prior terms.
-- =============================================
CREATE PROCEDURE [custom].[DFselStudents] @PastTerms INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CurTermId INT = [custom].fnGetCurrentTermId()

	--Dynamic Forms submits blanks instead of NULLs
	IF @PastTerms = ''
		SET @PastTerms = 0

	SELECT P.PEOPLE_CODE_ID
		,dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'DN |LN') [FullName]
		,dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'DN') [FirstName]
		,dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'LN') [LastName]
		,E.PrimaryEmail
		,E.AlternateEmail
		,P.PEOPLE_CODE_ID + ', ' + dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'DN |LN') + ', ' + E.PrimaryEmail AS [SearchableDesc]
	FROM PEOPLE P
	LEFT JOIN VWUEMAILADDRESSTOP E
		ON E.PEOPLE_ORG_CODE_ID = P.PEOPLE_CODE_ID
	WHERE 1 = 1
		AND PEOPLE_CODE_ID IN (
			SELECT PEOPLE_CODE_ID
			FROM [custom].vwACADEMIC
			WHERE 1 = 1
				AND TermId BETWEEN (@CurTermId - @PastTerms) AND @CurTermId
				AND ACADEMIC_SESSION > ''
				AND ACADEMIC_FLAG = 'Y'
			)
END
GO

