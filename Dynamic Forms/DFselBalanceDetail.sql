USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselBalanceDetail]    Script Date: 04/04/2022 12:38:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2022-03-10
-- Description:	Return details of a PEOPLEORGBALANCE row by ID.
--
-- 2022-03-14 Wyatt Best:		Added anticipated balance columns and ability to specify format string.
-- 2022-04-04 Wyatt Best:		Added COALESCE() to anticipated balance lookup.
-- =============================================
CREATE PROCEDURE [custom].[DFselBalanceDetail] @BalanceId NVARCHAR(10)
	,@Format NVARCHAR(20) = 'C'
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms submits blanks instead of null.
	IF @Format = ''
		SET @Format = 'C'

	SELECT ID AS [BalanceId]
		,PEOPLE_ORG_CODE_ID AS [PEOPLE_CODE_ID]
		,ACADEMIC_YEAR
		,ACADEMIC_TERM
		--,(ACADEMIC_TERM + ' ' + ACADEMIC_YEAR) AS [YearTerm]
		,BALANCE_AMOUNT
		,FORMAT(BALANCE_AMOUNT, @Format) [BalanceFormatted]
		,BALANCE_AMOUNT - Antic.Amount [AnticBalance]
		,FORMAT(BALANCE_AMOUNT - Antic.Amount, @Format) [AnticBalanceFormatted]
	FROM PEOPLEORGBALANCE B
	OUTER APPLY (
		SELECT COALESCE(SUM(CC.AMOUNT), 0) [Amount]
		FROM CHARGECREDIT CC
		WHERE cc.PEOPLE_ORG_CODE_ID = B.PEOPLE_ORG_CODE_ID
			AND ANTICIPATED_FLAG = 'Y'
			and CHARGE_CREDIT_TYPE ='F'
			AND ACADEMIC_YEAR = B.ACADEMIC_YEAR
			AND ACADEMIC_TERM = B.ACADEMIC_TERM
			AND ACADEMIC_SESSION = B.ACADEMIC_SESSION
		) Antic
	WHERE ID = @BalanceId
END
GO

