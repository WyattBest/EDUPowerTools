USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spFillCalendarKey]    Script Date: 2/6/2020 10:21:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-02-06
-- Description:	Populates CalendarKey on TRANATTENDANCE a few thousand rows at a time.
--				New entries coming from eThink Moodle are missing CalendarKey and will not be visible in Self-Service until linked.
--				Updates work backwards by TranAttendanceId in order to prioritize more recent attendance.
--				Entries that cannot be matched or have linked duplicates are ignored. This sproc could probably be better optomized.
-- =============================================
CREATE PROCEDURE [custom].[spFillCalendarKey]
AS
BEGIN
	SET NOCOUNT ON;

	WITH CTE_ta
	AS (
		SELECT TOP 3000 CalendarKey
			,CALENDAR_KEY
		FROM TRANATTENDANCE ta
		CROSS APPLY (
			SELECT TOP 1 c.CALENDAR_KEY
			FROM dbo.CALENDAR c
			INNER JOIN CALENDARDETAIL cd
				ON c.EVENT_KEY = cd.EVENT_KEY
					AND cd.ACADEMIC_YEAR = ta.ACADEMIC_YEAR
					AND cd.ACADEMIC_TERM = ta.ACADEMIC_TERM
					AND CD.ACADEMIC_SESSION = ta.ACADEMIC_SESSION
					AND CD.EVENT_SUB_TYPE = ta.EVENT_SUB_TYPE
					AND cd.EVENT_ID = ta.EVENT_ID
					AND cd.SECTION = ta.SECTION
			WHERE c.CALENDAR_DATE = ta.ATTENDANCE_DATE
			ORDER BY c.START_TIME ASC
			) cal
		WHERE CalendarKey IS NULL
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.TRANATTENDANCE att
				WHERE att.PEOPLE_CODE_ID = ta.PEOPLE_CODE_ID
					AND att.ACADEMIC_YEAR = ta.ACADEMIC_YEAR
					AND att.ACADEMIC_TERM = ta.ACADEMIC_TERM
					AND att.ACADEMIC_SESSION = ta.ACADEMIC_SESSION
					AND att.EVENT_ID = ta.EVENT_ID
					AND att.EVENT_SUB_TYPE = ta.EVENT_SUB_TYPE
					AND att.SECTION = ta.SECTION
					AND att.CalendarKey = cal.CALENDAR_KEY
				)
		ORDER BY ta.TranAttendanceId DESC
		)
	UPDATE CTE_ta
	SET CalendarKey = CALENDAR_KEY;
END
GO


