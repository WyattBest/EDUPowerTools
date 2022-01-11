USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spUpdateSectionMeetings]    Script Date: 2022-01-11 09:32:54 ******/
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
-- 2020-11-24 Wyatt Best:	Set all meetings to remote after Thanksgiving.
-- 2021-01-08 Wyatt Best:	Bunch of changes for Spring 2021.
-- 2021-01-13 Wyatt Best:	Move 2021-01-18 and 2021-01-21 sections to async format.
-- 2021-03-09 Wyatt Best:	Added year/term limitation on setting ROOM_ID = ZOOM.
--							Updated for Summer 2021.
-- 2021-05-21 Wyatt Best:	Removed exclusion for Pathways to Success.
-- 2021-06-14 Wyatt Best:	Corrected problem with deleted 5/31 meetings causing on-site/online cadence to be off.
-- 2021-06-28 Wyatt Best:	Corrected problem with 7/6 meetings not deleted to make room for Monday, 7/5 translation. Moved 7/6 to 8/17 because 8/17 had been incorrectly deleted.
-- 2021-08-18 Wyatt Best	Updated for Fall 2021. This Fall is quite simple, so all the fun code is gone. See https://github.com/WyattBest/EDUPowerTools/blob/master/spUpdateSectionMeetings.sql for old versions.
-- 2022-01-07 Wyatt Best:	Updated for Spring 2022.
-- 2022-01-11 Wyatt Best:	Corrected ORG_CODE_ID for classes temporarily moved online. Otherwise, they won't show on Self-Service calendar.
--							Moved 1/18 (Tuesday) classes to 4/19 to make room for translated Monday classes.
-- =============================================
ALTER PROCEDURE [custom].[spUpdateSectionMeetings] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Safety check to make sure procedure has been updated for the term
	IF (
			@AcademicYear = '2022'
			AND @AcademicTerm = 'SPRING'
			)
	BEGIN
		BEGIN TRAN

		--Update all synchronous classes to Online, Zoom for the month of Jan 2022
		UPDATE CALENDAR
		SET ORG_CODE_ID = 'O000000001'
			,BUILDING_CODE = 'ONLINE'
			,ROOM_ID = 'ZOOM'
		WHERE CALENDAR_DATE BETWEEN '2022-01-10' AND '2022-01-31'
			AND DATEDIFF(minute, START_TIME, END_TIME) > 10 --Synchronous sections only

		--Update room ONLINE to ZOOM for fully online, synchronous classes
		UPDATE SECTIONSCHEDULE
		SET ROOM_ID = 'ZOOM'
		WHERE ACADEMIC_YEAR = @AcademicYear
			AND ACADEMIC_TERM = @AcademicTerm
			AND ROOM_ID = 'ONLINE'
			AND DATEDIFF(minute, START_TIME, END_TIME) > 10 --Synchronous sections only

		--Delete holidays and extra (15th) meetings
		DELETE C
		FROM CALENDAR C
		INNER JOIN SECTIONSCHEDULE SS
			ON SS.CALENDARDET_EVENT_KEY = C.EVENT_KEY
		INNER JOIN SECTIONS S
			ON SS.ACADEMIC_YEAR = S.ACADEMIC_YEAR
				AND SS.ACADEMIC_TERM = S.ACADEMIC_TERM
				AND SS.ACADEMIC_SESSION = S.ACADEMIC_SESSION
				AND SS.EVENT_ID = S.EVENT_ID
				AND SS.EVENT_SUB_TYPE = S.EVENT_SUB_TYPE
				AND SS.SECTION = S.SECTION
		WHERE C.MEETING_TYPE = 'CLASS'
			AND C.EVENT_TYPE = 'COURSE'
			AND C.CALENDAR_DATE IN (
				'2022-02-21' --President's Day
				--,'2022-04-19' --15th Tuesday meeting
				)
			AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) > 10 --Synchronous sections only
			AND COALESCE(S.NONTRAD_PROGRAM, '') NOT IN ('LDRHS')

		--Delete holidays from Leadership High classes, which meet twice weekly
		DELETE C
		FROM CALENDAR C
		INNER JOIN SECTIONSCHEDULE SS
			ON SS.CALENDARDET_EVENT_KEY = C.EVENT_KEY
		INNER JOIN SECTIONS S
			ON SS.ACADEMIC_YEAR = S.ACADEMIC_YEAR
				AND SS.ACADEMIC_TERM = S.ACADEMIC_TERM
				AND SS.ACADEMIC_SESSION = S.ACADEMIC_SESSION
				AND SS.EVENT_ID = S.EVENT_ID
				AND SS.EVENT_SUB_TYPE = S.EVENT_SUB_TYPE
				AND SS.SECTION = S.SECTION
		WHERE C.MEETING_TYPE = 'CLASS'
			AND C.EVENT_TYPE = 'COURSE'
			AND C.CALENDAR_DATE IN (
				'2022-01-17' --MLK Day
				,'2022-02-21' --President's Day
				)
			AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) > 10 --Synchronous sections only
			AND S.NONTRAD_PROGRAM = 'LDRHS'

		--Delete extra Monday meetings for async sections
		DELETE C
		FROM CALENDAR C
		JOIN SECTIONSCHEDULE SS
			ON SS.CALENDARDET_EVENT_KEY = C.EVENT_KEY
		WHERE C.MEETING_TYPE = 'CLASS'
			AND EVENT_TYPE = 'COURSE'
			AND C.CALENDAR_DATE IN ('2022-04-18')
			AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) < 10 --Asynchronous sections only

		--Translation Day: Move Monday 2022-01-17 sections to Tuesday 2022-01-18
		UPDATE C
		SET CALENDAR_DATE = '2022-01-18'
			,DAY_OF_WEEK = 'TUE'
		FROM CALENDAR C
		INNER JOIN CALENDARDETAIL CD
			ON C.EVENT_KEY = CD.EVENT_KEY
		WHERE MEETING_TYPE = 'CLASS'
			AND C.EVENT_TYPE = 'COURSE'
			AND CALENDAR_DATE = '2022-01-17'
			AND DATEDIFF(minute, C.START_TIME, C.END_TIME) > 10; --Synchronous sections only

		--Update count of scheduled meetings
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
	END
END
