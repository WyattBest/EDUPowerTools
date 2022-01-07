USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spUpdateSectionMeetings]    Script Date: 2022-01-07 14:30:46 ******/
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
-- =============================================
CREATE PROCEDURE [custom].[spUpdateSectionMeetings] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Safety check to make sure procedure has been updated for the term
	IF (
			@AcademicYear = '2021'
			AND @AcademicTerm = 'FALL'
			)
	BEGIN
		BEGIN TRAN

		--Update room ONLINE to ZOOM for fully online, synchronous classes
		UPDATE SECTIONSCHEDULE
		SET ROOM_ID = 'ZOOM'
		WHERE ACADEMIC_YEAR = @AcademicYear
			AND ACADEMIC_TERM = @AcademicTerm
			AND ROOM_ID = 'ONLINE'
			AND DATEDIFF(minute, START_TIME, END_TIME) > 10 --Synchronous sections only
			--AND [DAY] = 'DIST'

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
				'2021-10-11' --Columbus Day
				,'2021-11-25'
				,'2021-11-26'
				,'2021-11-27'
				,'2021-12-14' --15th Tuesday meeting
				,'2021-12-15' --15th Wednesday meeting
				--,'2021-12-20' --15th Monday meeting
				)
			AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) > 10 --Synchronous sections only
			AND COALESCE(S.NONTRAD_PROGRAM, '') NOT IN ('LDRHS')

		--Delete holidays and extra (29th) meetings from Leadership High classes, which meet twice weekly
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
				'2021-10-11' --Columbus Day
				,'2021-11-25'
				,'2021-11-26'
				,'2021-11-27'
				,'2021-12-16' --29th meeting (Thursday)
				,'2021-12-20' --29th meeting (Monday)
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
			AND C.CALENDAR_DATE IN ('2021-12-20')
			AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) < 10;--Asynchronous sections only

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
			--DROP TABLE #SectionMeetings;
	END
END
GO

