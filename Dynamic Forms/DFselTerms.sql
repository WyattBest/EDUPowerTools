USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselTerms]    Script Date: 2020-11-12 15:26:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-11-09
-- Description:	Returns a list of current and future terms from the Academic Calendar.
--				@IncludeSessions paramter controls whether sessions or just terms are returned. If set to N or blank, information will be taken from session 01.
-- =============================================
CREATE PROCEDURE [custom].[DFselTerms] @IncludeSessions BIT
	,@Separator NVARCHAR(10) = ''
AS
BEGIN
	SET NOCOUNT ON;

	----Dynamic Forms submits blanks instead of null.
	--IF @IncludeSessions = ''
	--	SET @IncludeSessions = NULL
	IF @IncludeSessions = 1
		SELECT ACADEMIC_YEAR
			,ACADEMIC_TERM
			,ACADEMIC_SESSION
			,ACADEMIC_YEAR + @Separator + ACADEMIC_TERM + @Separator + ACADEMIC_SESSION [YTS]
			,ACADEMIC_TERM + @Separator + ACADEMIC_YEAR + @Separator + ACADEMIC_SESSION [TYS]
			,[START_DATE]
			,END_DATE
			,PRE_REG_DATE
			,REG_DATE
			,FIN_AID_YEAR
			,SessionPeriodId
		FROM ACADEMICCALENDAR
		WHERE END_DATE >= getdate()
		ORDER BY [START_DATE]

	IF @IncludeSessions = 0
		SELECT ACADEMIC_YEAR
			,ACADEMIC_TERM
			,ACADEMIC_SESSION
			,ACADEMIC_YEAR + @Separator + ACADEMIC_TERM + @Separator [YTS]
			,ACADEMIC_TERM + @Separator + ACADEMIC_YEAR + @Separator [TYS]
			,[START_DATE]
			,END_DATE
			,PRE_REG_DATE
			,REG_DATE
			,FIN_AID_YEAR
			,SessionPeriodId
		FROM ACADEMICCALENDAR
		WHERE END_DATE >= getdate()
			AND ACADEMIC_SESSION = '01'
		ORDER BY [START_DATE]
END
GO

