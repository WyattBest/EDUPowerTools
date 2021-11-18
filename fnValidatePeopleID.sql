USE [Campus6]
GO

/****** Object:  UserDefinedFunction [custom].[fnValidatePeopleID]    Script Date: 2021-11-18 11:20:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-11-18
-- Description:	Given a potentially malformed ID number, return a valid PEOPLE_CODE_ID.
-- =============================================
CREATE FUNCTION [custom].[fnValidatePeopleID] (@PCID NVARCHAR(10))
RETURNS NVARCHAR(10)
AS
BEGIN
	--Remove dashes
	SET @PCID = REPLACE(@PCID, '-', '')
	
	--Remove spaces
	SET @PCID = REPLACE(@PCID, ' ', '')

	-- Try to fix @PCID, first by padding with zeros, then by prepending 'P'
	IF LEN(@PCID) < 9
		SET @PCID = REPLICATE('0', 9 - LEN(@PCID)) + @PCID

	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID
	
	--Verify that the PCID actually exists in PEOPLE table
	SET @PCID = (
			SELECT PEOPLE_CODE_ID
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @PCID
			)

	-- Return the result of the function
	RETURN @PCID
END
GO

