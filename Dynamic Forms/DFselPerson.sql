USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselPerson]    Script Date: 2021-04-22 11:51:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-12-08
-- Description:	Returns information about a specific person. Forgiving on the input ID number.
--				Feel free to add more columns.
--
-- 2021-03-08 Wyatt Best:	Added emails, FirstName, and LastName.
-- =============================================
CREATE PROCEDURE [custom].[DFselPerson] @PCID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Try to fix @PCID, first by padding with zeros and then by prepending 'P'
	IF LEN(@PCID) < 9
		SET @PCID = REPLICATE('0', 9 - LEN(@PCID)) + @PCID

	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID

	SELECT dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'DN |LN') [FullName] --Use Ellucian's function to handle display names
		,dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'DN') [FirstName]
		,dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'LN') [LastName]
		,PEOPLE_CODE_ID
		,E.PrimaryEmail
		,E.AlternateEmail
	FROM PEOPLE P
	LEFT JOIN VWUEMAILADDRESSTOP E
		ON E.PEOPLE_ORG_CODE_ID = P.PEOPLE_CODE_ID
	WHERE p.PEOPLE_CODE_ID = @PCID
END
GO

