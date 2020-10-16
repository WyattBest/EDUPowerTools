USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselTermDates]    Script Date: 2020-10-16 11:54:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-08-18
-- Description:	Returns various dates for a given year and term.
--				Returned dates are formatted according to optional parameter: https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings
-- =============================================
CREATE PROCEDURE [custom].[DFselTermDates] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@AcademicSession NVARCHAR(10) = '01'
	,@DateFormat VARCHAR(50) = 'yyyy-MM-dd HH:mm:ss.fff'
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms has an annoying habit of passing blanks instead of nulls/omitting parameters
	IF @AcademicSession = ''
		SET @AcademicSession = '01';

	IF @DateFormat = ''
		SET @DateFormat = 'yyyy-MM-dd HH:mm:ss.fff';

	SELECT FORMAT([START_DATE], @DateFormat) [Start]
		,FORMAT(END_DATE, @DateFormat) [End]
		,FORMAT(DATEADD(DAY, 7, START_DATE), @DateFormat) [1WeekAfterStart]
	FROM ACADEMICCALENDAR
	WHERE ACADEMIC_YEAR = @AcademicYear
		AND ACADEMIC_TERM = @AcademicTerm
		AND ACADEMIC_SESSION = @AcademicSession
END
GO

