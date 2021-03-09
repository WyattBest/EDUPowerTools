USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spUpdateSectionMeetings]    Script Date: 2021-03-09 11:21:12 ******/
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
-- =============================================
ALTER PROCEDURE [custom].[spUpdateSectionMeetings] @AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN

	--Update room ONLINE to ZOOM for fully online, synchronous classes
	UPDATE SECTIONSCHEDULE
	SET ROOM_ID = 'ZOOM'
	WHERE ACADEMIC_YEAR = @AcademicYear
		AND ACADEMIC_TERM = @AcademicTerm
		AND ROOM_ID = 'ONLINE'
		AND DATEDIFF(minute, START_TIME, END_TIME) > 10 --Synchronous sections only
		AND [DAY] = 'DIST'

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
		,1 [TargetPattern] --Example use: Difference Schools have classes on campus on odd/even weeks.
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
		--AND S.SECTION NOT LIKE 'DST%'
		AND SS.[DAY] <> 'DIST'
		AND SS.ROOM_ID <> 'ZOOM'
		AND (
			S.NONTRAD_PROGRAM <> 'PTS' --Exclude Pathways to Success
			OR S.NONTRAD_PROGRAM IS NULL
			);

	-- Debug
	--SELECT *
	--FROM #SectionMeetings SM
	--ORDER BY CALENDAR_DATE

	--Delete holidays and extra Tuesday and Wednesday meetings
	DELETE C
	FROM CALENDAR C
	JOIN SECTIONSCHEDULE SS
		ON SS.CALENDARDET_EVENT_KEY = C.EVENT_KEY
	WHERE C.MEETING_TYPE = 'CLASS'
		AND EVENT_TYPE = 'COURSE'
		AND C.CALENDAR_DATE IN (
			'2021-05-31'
			,'2021-08-17' --Not a holiday, but Tuesday classes would otherwise have 15 meetings
			)
		AND DATEDIFF(minute, SS.START_TIME, SS.END_TIME) > 10 --Synchronous sections only
		--AND SS.[DAY] <> 'MON' --Don't delete classes translated from 2020-10-12

	--Translation Day: Move Monday 2021-07-05 sections to Tuesday 2021-07-06
	UPDATE C
	SET CALENDAR_DATE = '2021-07-06'
		,DAY_OF_WEEK = 'TUE'
	FROM CALENDAR C
	INNER JOIN CALENDARDETAIL CD
		ON C.EVENT_KEY = CD.EVENT_KEY
	WHERE MEETING_TYPE = 'CLASS'
		AND C.EVENT_TYPE = 'COURSE'
		AND CALENDAR_DATE = '2021-07-05'
		AND DATEDIFF(minute, C.START_TIME, C.END_TIME) > 10 --Synchronous sections only

	--Move alternating weeks to ONLINE
	UPDATE C
	SET ORG_CODE_ID = 'O000000001'
		,BUILDING_CODE = 'ONLINE'
		,ROOM_ID = 'ZOOM'
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

	----Holiday: Move Monday 2021-01-18 and 2021-01-21 sections to async format
	--UPDATE C
	--SET ORG_CODE_ID = 'O000000001'
	--	,BUILDING_CODE = 'ONLINE'
	--	,ROOM_ID = 'ONLINE'
	--	,START_TIME = '01:12'
	--	,END_TIME = '01:13'
	--FROM CALENDAR C
	--INNER JOIN CALENDARDETAIL CD
	--	ON C.EVENT_KEY = CD.EVENT_KEY
	--WHERE MEETING_TYPE = 'CLASS'
	--	AND C.EVENT_TYPE = 'COURSE'
	--	AND CALENDAR_DATE IN (
	--		'2021-01-18'
	--		,'2021-02-15'
	--		)
	--	--AND DATEDIFF(minute, C.START_TIME, C.END_TIME) > 10 --Synchronous sections only
	--	AND CD.[DAY] <> 'DIST';
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
