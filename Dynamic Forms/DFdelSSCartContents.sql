USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFdelSSCartContents]    Script Date: 2020-11-24 11:51:05 ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER ON
GO

/***********************************************************************
-- Author:		Wyatt Best
-- Create date: 2020-11-02
-- Description:	Deletes either an individual item or all sections from an advisee's Self-Servic cart.
--
-- 2020-11-24: Changed authorization model to allow any advisor to modify any cart, not just My Advisees.
************************************************************************/
CREATE PROCEDURE [custom].[DFdelSSCartContents] @PCID NVARCHAR(10)
	,@AdvisorID NVARCHAR(10)
	,@SectionId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Authorized BIT = 0;

	--Adjust @PCID
	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID

	IF @SectionId = ''
		SET @SectionId = NULL

	--If @AdvisorID truly is an advisor, set Authorized = True. @AdvisorID is supplied via SSO.
	IF @AdvisorID IN (
			SELECT PEOPLE_CODE_ID
			FROM PEOPLETYPE
			WHERE PEOPLE_TYPE = 'ADV'
			)
		SET @Authorized = 1

	DELETE
	FROM CartSection
	WHERE 1 = 1
		AND PersonId = dbo.fnGetPersonId(@PCID)
		AND @Authorized = 1
		AND (
			SectionId = @SectionId
			OR @SectionId IS NULL
			)
END
