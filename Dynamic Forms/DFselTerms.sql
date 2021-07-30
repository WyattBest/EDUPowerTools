USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselTerms]    Script Date: 2021-07-30 09:42:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-11-09
-- Description:	Returns a list of current and future terms from the Academic Calendar.
--				@IncludeSessions paramter controls whether sessions or just terms are returned. If set to N or blank, information will be taken from session 01.
--				@MinWeek parameter will eliminate terms/sessions that have progressed past this many weeks.
--					For example, we can eliminate the current term after week 10, which is the last week for withdrawals.
-- =============================================
CREATE PROCEDURE [custom].[DFselTerms] @IncludeSessions BIT
	,@Separator NVARCHAR(10) = ''
	,@MinWeek INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms submits blanks instead of null.
	IF @MinWeek = ''
		SET @MinWeek = NULL

	SELECT ACADEMIC_YEAR
		,ACADEMIC_TERM
		,ACADEMIC_SESSION
		,ACADEMIC_YEAR + @Separator + ACADEMIC_TERM + CASE 
			WHEN @IncludeSessions = 1
				THEN @Separator + ACADEMIC_SESSION
			ELSE ''
			END [YTS]
		,ACADEMIC_TERM + @Separator + ACADEMIC_YEAR + CASE 
			WHEN @IncludeSessions = 1
				THEN @Separator + ACADEMIC_SESSION
			ELSE ''
			END [TYS]
		,[START_DATE]
		,END_DATE
		,PRE_REG_DATE
		,REG_DATE
		,FIN_AID_YEAR
		,SessionPeriodId
	FROM ACADEMICCALENDAR
	WHERE END_DATE >= getdate()
		AND (
			@IncludeSessions = 1
			OR (
				@IncludeSessions = 0
				AND ACADEMIC_SESSION = '01'
				)
			)
		AND (
			@MinWeek >= (datediff(day, [START_DATE], getdate()) / 7) + 1
			OR @MinWeek IS NULL
			)
	ORDER BY [START_DATE]
END
