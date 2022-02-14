USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselPDCEnrolled]    Script Date: 02/14/2022 15:53:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		?
-- Create date: 2021-08-23
-- Description:	Select all Program / Degree / Curriculum combinations a student has ever been enrolled in.
--
-- =============================================
CREATE PROCEDURE [custom].[DFselPDCEnrolled] @PCID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Fix PCID
	SET @PCID = [custom].fnValidatePeopleID(@PCID);

	SELECT DISTINCT PROGRAM
		,DEGREE
		,CURRICULUM
		,CP.LONG_DESC + ' / ' + CD.LONG_DESC + ' / ' + CC.LONG_DESC [LongDesc]
	FROM ACADEMIC A
	INNER JOIN CODE_PROGRAM CP
		ON CP.CODE_VALUE_KEY = A.PROGRAM
	INNER JOIN CODE_DEGREE CD
		ON CD.CODE_VALUE_KEY = A.DEGREE
	INNER JOIN CODE_CURRICULUM CC
		ON CC.CODE_VALUE_KEY = A.CURRICULUM
	WHERE 1 = 1
		AND PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_SESSION = '01'
		AND ACADEMIC_FLAG = 'Y'
		AND GRADUATED <> 'G'
END
GO

