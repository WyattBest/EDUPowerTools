USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spUpdateSectionMeetings]    Script Date: 2020-09-23 11:53:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-08-27
-- Description:	Updates CALENDAR and SECTIONS to accomodate holidays, hybrid schedules, etc.
--				Needs to be updated each term!
--
-- 2020-09-02 Wyatt Best:	Changed logic from completely excluding DST% from holiday adjustments to looking at meeting length to determine sync vs async.
--							Set Community Health Education programs to start on second week.
-- =============================================
CREATE PROCEDURE [custom].[spUpdateSectionMeetings] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Make sure procedure has been updated for the current term
	IF (
			(
				SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
				) = @AcademicYear
			AND (
				SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
				) = @AcademicTerm
			)
	BEGIN
		--Build a list of on-campus section meetings and classify according to College, Week Number, and whether that week number is even/odd.
		SELECT S.ACADEMIC_YEAR
			,S.ACADEMIC_TERM
			,S.ACADEMIC_SESSION
			,S.EVENT_ID
			,S.EVENT_SUB_TYPE
			,S.SECTION
			,COLLEGE
			,SS.BUILDING_CODE
			,SS.ROOM_ID
			,CALENDARDET_EVENT_KEY
			,CALENDAR_KEY
			,CASE 
				WHEN CURRICULUM = 'CHE19'
					THEN 2
				WHEN COLLEGE = 'ACSHSE'
					THEN 1
				WHEN COLLEGE = 'PUBAFF'
					THEN 1
				WHEN COLLEGE = 'BUSNES'
					THEN 2
				END AS [TargetPattern]
			,RANK() OVER (
				PARTITION BY C.EVENT_KEY ORDER BY CALENDAR_DATE
				) [WeekNumber]
			-- Test even/odd and then align it with the TargetPattern
			,(
				(
					RANK() OVER (
						PARTITION BY C.EVENT_KEY ORDER BY CALENDAR_DATE
						) - 1
					) % 2
				) + 1 [WeekOddEven]
			,C.CALENDAR_DATE
		INTO #SectionMeetings
		FROM SECTIONS S
		INNER JOIN SECTIONSCHEDULE SS
			ON SS.ACADEMIC_YEAR = S.ACADEMIC_YEAR
				AND SS.ACADEMIC_TERM = S.ACADEMIC_TERM
				AND SS.ACADEMIC_SESSION = S.ACADEMIC_SESSION
				AND SS.EVENT_ID = S.EVENT_ID
				AND SS.EVENT_SUB_TYPE = S.EVENT_SUB_TYPE
				AND SS.SECTION = S.SECTION
		INNER JOIN CALENDAR C
			ON SS.CALENDARDET_EVENT_KEY = C.EVENT_KEY
		WHERE 1 = 1
			AND S.ACADEMIC_YEAR = @AcademicYear
			AND S.ACADEMIC_TERM = @AcademicTerm
			AND S.SECTION NOT LIKE 'DST%';

		-- Debug
		--SELECT *
		--FROM #SectionMeetings SM
		--ORDER BY CALENDAR_DATE

		BEGIN TRAN

		--Delete holidays and extra Tuesday and Wednesday meetings
		DELETE C
		FROM CALENDAR C
		JOIN SECTIONSCHEDULE SS
			ON SS.CALENDARDET_EVENT_KEY = C.EVENT_KEY
		WHERE C.MEETING_TYPE = 'CLASS'
			AND EVENT_TYPE = 'COURSE'
			AND C.CALENDAR_DATE IN (
				'2020-09-07'
				,'2020-10-13' --Not a holiday, but Tuesday classes would otherwise have 15 meetings
				,'2020-11-26'
				,'2020-11-27'
				,'2020-11-28'
				,'2020-12-16' --Not a holiday, but Wednesday classes would otherwise have 15 meetings
				)
			AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) > 10 --Synchronous sections only
			AND SS.[DAY] <> 'MON' --Don't delete classes translated from 2020-10-12

		--Translation Day: Move Monday 2020-10-13 sections to Tuesday 2020-10-13
		UPDATE C
		SET CALENDAR_DATE = '2020-10-13'
			,DAY_OF_WEEK = 'TUE'
		FROM CALENDAR C
		INNER JOIN CALENDARDETAIL CD
			ON C.EVENT_KEY = CD.EVENT_KEY
		WHERE MEETING_TYPE = 'CLASS'
			AND C.EVENT_TYPE = 'COURSE'
			AND CALENDAR_DATE = '2020-10-12'
			AND DATEDIFF(minute, C.START_TIME, C.END_TIME) > 10 --Synchronous sections only

		--Move alternating weeks to ONLINE
		UPDATE C
		SET BUILDING_CODE = 'ONLINE'
			,ROOM_ID = 'ONLINE'
		FROM CALENDAR C
		INNER JOIN #SectionMeetings SM
			ON SM.CALENDAR_KEY = C.CALENDAR_KEY
		WHERE TargetPattern <> WeekOddEven;

		--Move alternating weeks to on campus (necessary for subsequent runs when the number of weeks has changed)
		UPDATE C
		SET BUILDING_CODE = SM.BUILDING_CODE
			,ROOM_ID = SM.ROOM_ID
		FROM CALENDAR C
		INNER JOIN #SectionMeetings SM
			ON SM.CALENDAR_KEY = C.CALENDAR_KEY
		WHERE TargetPattern = WeekOddEven;

		--Update SCHEDULED_MEETINGS counter (for consistent display in client)
		WITH CTE_SectionMeetings
		AS (
			SELECT COUNT(*) [SectionMeetings]
				,ACADEMIC_YEAR
				,ACADEMIC_TERM
				,ACADEMIC_SESSION
				,EVENT_ID
				,EVENT_SUB_TYPE
				,SECTION
			FROM CALENDAR C
			INNER JOIN CALENDARDETAIL CD
				ON CD.EVENT_KEY = C.EVENT_KEY
			WHERE ACADEMIC_YEAR = @AcademicYear
				AND ACADEMIC_TERM = @AcademicTerm
			GROUP BY ACADEMIC_YEAR
				,ACADEMIC_TERM
				,ACADEMIC_SESSION
				,EVENT_ID
				,EVENT_SUB_TYPE
				,SECTION
			)
		UPDATE S
		SET SCHEDULED_MEETINGS = SectionMeetings
		FROM SECTIONS S
		INNER JOIN CTE_SectionMeetings CTE
			ON CTE.ACADEMIC_YEAR = S.ACADEMIC_YEAR
				AND CTE.ACADEMIC_TERM = S.ACADEMIC_TERM
				AND CTE.ACADEMIC_SESSION = S.ACADEMIC_SESSION
				AND CTE.EVENT_ID = S.EVENT_ID
				AND CTE.EVENT_SUB_TYPE = S.EVENT_SUB_TYPE
				AND CTE.SECTION = S.SECTION

		COMMIT TRAN

		DROP TABLE #SectionMeetings;
	END
END
GO

