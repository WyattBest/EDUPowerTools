USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselSSCartContents]    Script Date: 2020-11-24 11:49:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-11-02
-- Description:	Selects the contents of the Self-Service cart by student ID and advisor ID.
--
-- 2020-11-24: Changed authorization model to allow any advisor to modify any cart, not just My Advisees.
-- =============================================
CREATE PROCEDURE [custom].[DFselSSCartContents] @PCID NVARCHAR(10)
	,@AdvisorID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Authorized BIT = 0;

	--Adjust @PCID
	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID

	--If @AdvisorID truly is an advisor, set Authorized = True. @AdvisorID is supplied via SSO.
	IF @AdvisorID IN (
			SELECT PEOPLE_CODE_ID
			FROM PEOPLETYPE
			WHERE PEOPLE_TYPE = 'ADV'
			)
		SET @Authorized = 1

	SELECT SectionId
		,C.EVENT_ID + ' / ' + C.Event_Sub_Type + ' / ' + C.SECTION [Desc]
	FROM vwsCartSection C
	INNER JOIN [custom].vwOrderedTerms OT
		ON OT.ACADEMIC_YEAR = C.ACADEMIC_YEAR
			AND OT.ACADEMIC_TERM = C.ACADEMIC_TERM
	WHERE 1 = 1
		AND C.PEOPLE_CODE_ID = @PCID
		AND @Authorized = 1
END
