USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselAdvisor]    Script Date: 2020-12-08 13:44:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-12-08
-- Description:	Returns information about a specific person. Feel free to add more columns.
-- =============================================
CREATE PROCEDURE [custom].[DFselPerson] @PCID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Adjust @PCID
	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID

	SELECT dbo.fnPeopleOrgName(@PCID, 'DN |LN') [FullName] --Use Ellucian's function to handle display names
END
GO


