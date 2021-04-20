USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselFaculty]    Script Date: 2021-04-20 14:21:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-09-02
-- Description:	Selects names and email addresses of people with the Faculty record type.
--				Feel free to add additional columns.
-- =============================================
CREATE PROCEDURE [custom].[DFselFaculty]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT dbo.fnPeopleOrgName(P.PEOPLE_CODE_ID, 'LN') [LastName]
		,dbo.fnPeopleOrgName(P.PEOPLE_CODE_ID, 'FN') [FirstName]
		,PrimaryEmail
	--,AlternateEmail
	FROM FACULTY F
	INNER JOIN PEOPLETYPE PT
		ON PT.PEOPLE_ID = F.PEOPLE_ID
			AND PT.PEOPLE_TYPE = 'FAC'
	INNER JOIN PEOPLE P
		ON P.PEOPLE_ID = F.PEOPLE_ID
	LEFT JOIN VWUEMAILADDRESSTOP E
		ON E.PEOPLE_ORG_CODE_ID = P.PEOPLE_CODE_ID
	ORDER BY LAST_NAME
		,FIRST_NAME
END
GO

