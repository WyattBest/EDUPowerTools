USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[ntfStudentWeeklySchedule]    Script Date: 2021-09-01 16:24:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-08-31
-- Description:	Emails each enrolled student a personalized scheduled for the upcoming week.
--
-- 2020-09-14 Wyatt Best:	Chopped time portion off of @Monday. Only add 6 days instead of 7.
-- 2020-09-21 Wyatt Best:	Chopped time portion off of CALENDAR_DATE when selecting into #SectionMeetingsSync.
--							Added ORDER BY clause to sync schedule table.
-- 2020-10-05 Wyatt Best:	Exclude nontraditional program LDRHS students.
-- 2021-01-08 Wyatt Best:	Updated for new room name, ZOOM. Also changed hardcoded TermId to variable. Safer if we forget to update this, but dangerous if Acal dates are wrong.
-- 2021-01-14 Wyatt Best:	New functionality to display holiday meetings being held asynchronously in their own table.
--							Added new column to underlying view, REGULAR_DAY. Allows for easier detection of async courses as well as detecting async meetings for sections that are normally sync.
-- 2021-08-23 Wyatt Best:	Added logic to prevent sending when between terms.
-- 2021-08-24 Wyatt Best:	Remove health screening link.
-- =============================================
CREATE PROCEDURE [custom].[ntfStudentWeeklySchedule]
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON; --Stop on all errors.

	DECLARE @Monday DATE = dateadd(day, 1, cast(getdate() AS DATE)) --Intended to be run on Sunday evenings.
		,@TermId INT = (
			SELECT TermId
			FROM [custom].vwOrderedTerms
			WHERE ACADEMIC_YEAR = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
				AND ACADEMIC_TERM = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)
		,@Subject NVARCHAR(100) = 'Class Schedule for the Week'
		,@Body NVARCHAR(MAX) = 
		'<style type="text/css">
			table.merged {
				width: 100%;
				border-width: 1px;
				border-color: #a5a5a5;
				border-collapse: collapse;
			}

			table.merged th {
				border-width: 1px;
				border-style: solid;
				border-color: #a5a5a5;
				background-color: #dedede;
				text-align: left;
				padding: 5px;
			}

			table.merged td {
				border-width: 1px;
				border-style: solid;
				border-color: #a5a5a5;
				background-color: #ffffff;
				padding: 5px;
			}
		</style>
		<p>Dear {{DisplayName}},</p>
		<p>{{Intro}}</p>		
		{{HolidayAdjustmentsHeader}}
		{{HolidaySchedule}}
		<p>Your {{HolidaySnippet1}}synchronous courses, listed below, will meet on their scheduled day and time.</p>
		{{SyncSchedule}}
		<p>Your asynchronous courses require various activities each week in <a href="https://moodle.mcny.edu">Moodle</a> or as directed by your professor instead of meeting on campus or on Zoom.</p>
		{{AsyncSchedule}}
		<p>You can view schedule information any time via the calendar on the home page of <a href="https://selfservice.mcny.edu/">Self-Service</a>.</p>'
		;

	--Don't do anything if between terms
	IF (
			SELECT [START_DATE]
			FROM ACADEMICCALENDAR
			WHERE ACADEMIC_YEAR = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
				AND ACADEMIC_TERM = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
				AND ACADEMIC_SESSION = '01'
			) > DATEADD(day, 6, @Monday)
		RETURN

	--Query all sync section meetings for the week
	SELECT PEOPLE_ID
		,EVENT_ID
		,SECTION
		,EVENT_LONG_NAME
		,BUILDING_CODE
		,ROOM_ID
		,CALENDAR_DATE
		,START_TIME
		,END_TIME
	INTO #SectionMeetingsSync
	FROM [custom].vwSectionMeetingsStudent
	WHERE TermId = @TermId
		AND CAST(CALENDAR_DATE AS DATE) BETWEEN @Monday AND DATEADD(day, 6, @Monday) --Week range
		AND DATEDIFF(minute, START_TIME, END_TIME) > 10;
		--AND REGULAR_DAY <> 'DIST';

	--Query all async sections for the term
	SELECT DISTINCT PEOPLE_ID
		,EVENT_ID
		,SECTION
		,EVENT_LONG_NAME
	INTO #SectionsAsync
	FROM [custom].vwSectionMeetingsStudent
	WHERE TermId = @TermId
		--AND DATEDIFF(minute, START_TIME, END_TIME) < 10;
		AND REGULAR_DAY = 'DIST';

	--Query holiday section meetings moved from sync to async format for the week
	SELECT DISTINCT PEOPLE_ID
		,EVENT_ID
		,SECTION
		,EVENT_LONG_NAME
	INTO #SectionsHoliday
	FROM [custom].vwSectionMeetingsStudent
	WHERE TermId = @TermId
		AND CAST(CALENDAR_DATE AS DATE) BETWEEN @Monday AND DATEADD(day, 6, @Monday) --Week range
		AND REGULAR_DAY <> 'DIST'
		AND DATEDIFF(minute, START_TIME, END_TIME) < 10;

	--Build list of enrolled students and HTML tables of their sync and async course meetings
	SELECT 'selfservice@mcny.edu' [from]
		,A.PEOPLE_CODE_ID [toId]
		--,'wbest@mcny.edu' [to] --Debug
		--,'mmolina@mcny.edu' [cc] --Debug
		,0 [toTypeFlag]
		,@Subject [subject]
		,@Body [body]
		,0 [formatBodyFlag]
		--Fields for merging
		,dbo.fnPeopleOrgName(A.PEOPLE_CODE_ID, 'DN') [DisplayName]
		,(
			SELECT 'merged' AS [@class]
				,(
					SELECT 'Synchronous Courses' [th]
						,'Section' [th]
						,'Date' [th]
						,'Time' [th]
						,'Campus' [th]
						,'Room' [th]
					FOR XML raw('tr')
						,ELEMENTS
						,TYPE
					) AS 'thead'
				,COALESCE((
						SELECT EVENT_ID + ': ' + EVENT_LONG_NAME [td]
							,SECTION [td]
							,FORMAT(CALENDAR_DATE, 'ddd MM/dd') [td]
							,FORMAT(START_TIME, 't') + ' - ' + FORMAT(END_TIME, 't') [td]
							--,FORMAT(CALENDAR_DATE, 'ddd ') + FORMAT(START_TIME, 't') + ' - ' + FORMAT(END_TIME, 't') + ' (' + FORMAT(CALENDAR_DATE, 'MM/dd') + ')' [td]
							--,FORMAT(CALENDAR_DATE + START_TIME, 'ddd, MMM dd, h:mm tt') + ' - ' + FORMAT(END_TIME, 't') [td]
							,CASE BUILDING_CODE
								WHEN '60W'
									THEN 'Manhattan'
								WHEN 'E149ST'
									THEN 'Bronx'
								WHEN 'ONLINE'
									THEN 'Online'
								ELSE 'Unknown'
								END [td]
							,CASE ROOM_ID
								WHEN 'ZOOM'
									THEN 'Zoom'
								WHEN 'ONLINE'
									THEN 'Online'
								ELSE ROOM_ID
								END [td]
						FROM #SectionMeetingsSync SM
						WHERE 1 = 1
							AND SM.PEOPLE_ID = A.PEOPLE_ID
						ORDER BY CALENDAR_DATE
							,START_TIME
						FOR XML RAW('tr')
							,ELEMENTS
							,TYPE
						), '<td>Nothing scheduled.</td><td></td><td></td><td></td><td></td><td></td>') AS 'tbody'
			FOR XML PATH('table')
			) [SyncSchedule]
		,(
			SELECT 'merged' AS [@class]
				,(
					SELECT 'Asynchronous Courses' [th]
						,'Section' [th]
					FOR XML raw('tr')
						,ELEMENTS
						,TYPE
					) AS 'thead'
				,COALESCE((
						SELECT EVENT_ID + ': ' + EVENT_LONG_NAME [td]
							,SECTION [td]
						FROM #SectionsAsync SM
						WHERE 1 = 1
							AND SM.PEOPLE_ID = A.PEOPLE_ID
						FOR XML RAW('tr')
							,ELEMENTS
							,TYPE
						), '<td>Nothing scheduled.</td><td></td>') AS 'tbody'
			FOR XML PATH('table')
			) [AsyncSchedule]
		,(
			SELECT 'merged' AS [@class]
				,(
					SELECT 'Adjusted Courses' [th]
						,'Section' [th]
					FOR XML raw('tr')
						,ELEMENTS
						,TYPE
					) AS 'thead'
				,COALESCE((
						SELECT EVENT_ID + ': ' + EVENT_LONG_NAME [td]
							,SECTION [td]
						FROM #SectionsHoliday SH
						WHERE 1 = 1
							AND SH.PEOPLE_ID = A.PEOPLE_ID
						FOR XML RAW('tr')
							,ELEMENTS
							,TYPE
						), '<td>Nothing scheduled.</td><td></td>') AS 'tbody'
			FOR XML PATH('table')
			) [HolidaySchedule]
		,CASE 
			WHEN EXISTS (
					SELECT *
					FROM #SectionsHoliday SH
					WHERE SH.PEOPLE_ID = A.PEOPLE_ID
					)
				THEN 1
			ELSE 0
			END [HolidayFlag]
	INTO #Messages
	FROM [custom].vwACADEMIC A
	INNER JOIN PEOPLE P
		ON P.PEOPLE_ID = A.PEOPLE_ID
	WHERE 1 = 1
		AND TermId = @TermId
		AND ENROLL_SEPARATION = 'ENRL'
		--Exclude students without any classes scheduled at all
		AND (
			A.PEOPLE_ID IN (
				SELECT PEOPLE_ID
				FROM #SectionMeetingsSync
				)
			OR A.PEOPLE_ID IN (
				SELECT PEOPLE_ID
				FROM #SectionsAsync
				)
			)
		AND (
			NONTRAD_PROGRAM <> 'LDRHS'
			OR NONTRAD_PROGRAM IS NULL
			)
		--AND A.PEOPLE_CODE_ID = 'P000166232'
		;

	--Supply merge fields in the body
	UPDATE #Messages
	SET body = REPLACE(body, '{{DisplayName}}', DisplayName)

	UPDATE #Messages
	SET body = REPLACE(body, '{{Intro}}', CASE 
				WHEN HolidayFlag = 1
					THEN 'Please be aware there has been a change to your class schedule this week.'
				ELSE 'Here''s your class schedule for the week. Classes can be held synchronously on campus or on Zoom, or they can be held online asynchronously.'
				END)

	UPDATE #Messages
	SET body = REPLACE(body, '{{HolidaySnippet1}}', CASE 
				WHEN HolidayFlag = 1
					THEN 'remaining '
				ELSE ''
				END)

	UPDATE #Messages
	SET body = REPLACE(body, '{{HolidayAdjustmentsHeader}}', CASE 
				WHEN HolidayFlag = 1
					THEN '<p>The following courses will not meet synchronously this week due to a holiday.
					Instead, your instructor will require asynchronous participation (assignments, discussion forums, etc.) for this week''s attendance.
					Please check Moodle or contact your instructor for more details.</p>'
				ELSE ''
				END)

	UPDATE #Messages
	SET body = REPLACE(body, '{{HolidaySchedule}}', CASE 
				WHEN HolidayFlag = 1
					THEN HolidaySchedule + '<p>All other classes will follow their regular schedule.</p>'
				ELSE ''
				END)

	UPDATE #Messages
	SET body = REPLACE(body, '{{SyncSchedule}}', SyncSchedule)

	UPDATE #Messages
	SET body = REPLACE(body, '{{AsyncSchedule}}', AsyncSchedule)

	--Debug
	SELECT *
	FROM #Messages

	--Send emails
	--EXEC [custom].[spSendEmails];

	DROP TABLE #SectionMeetingsSync
		,#SectionsAsync
		,#SectionsHoliday
		,#Messages;
END
GO

