USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFdiffDateDays]    Script Date: 2021-04-20 14:19:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-12-15
-- Description:	Compares two dates. Second date defaults to current date.
-- =============================================
CREATE PROCEDURE [custom].[DFdiffDateDays] @InputDate1 DATE
	,@InputDate2 DATE
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms submits blanks instead of null.
	IF @InputDate2 = ''
		SET @InputDate2 = getdate()

	SELECT datediff(day, @InputDate1, @InputDate2) [Diff]
END
GO

