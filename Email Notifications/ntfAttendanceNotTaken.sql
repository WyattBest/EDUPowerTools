USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[ntfAttendanceNotTaken]    Script Date: 01/25/2021 10:25:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-01-06
-- Description:	Send email to faculty one week after section meeting if attendance not recorded for one or more students.
--
-- 2020-01-08 Wyatt Best:	Changed date logic to 8 days after meeting for distance courses and 2 days after meeting for in-person courses.
--							Changed email sender to program director, who will be stored in curriculum code table "Version 4.X Code" field.
-- 2020-02-19 Wyatt Best:	Put into production.
-- 2020-04-15 Wyatt Best:	Because Summer 2020 may be entirely remote, adjusted synchronous sections to 8 days grace.
-- 2020-05-26 Wyatt Best:	Excluded independent study sections.
-- 2020-07-22 Wyatt Best:	Excluded MBA foundation courses.
-- 2020-08-06 Wyatt Best:	Excluded students who withdrew from the entire term.
-- 2020-08-31 Wyatt Best:	Fix error in last change (PEOPLE_CODE vs PEOPLE_ID in join).
-- 2020-10-09 Wyatt Best:	Exclude students who withdrew from section (not dropped).
-- 2021-01-25 Wyatt Best:	Changed COUNT(TD.PEOPLE_ID) to COUNT(DISTINCT TD.PEOPLE_ID) to account for students who have multiple PDC's in a term.
--							Changed criteria to look at preceding academic week (Mon-Sun) instead of days after meeting. Process will only run on Tuesday mornings.
-- =============================================
CREATE PROCEDURE [custom].[ntfAttendanceNotTaken]
AS
BEGIN
	SET XACT_ABORT ON --Stop on all errors.
	SET NOCOUNT ON;

	--If it's not Tuesday, exit immediately
	IF DATEPART(WEEKDAY, GETDATE()) <> 3
		RETURN

	BEGIN TRAN SendEmails

	--Email subject and body
	DECLARE @Subject NVARCHAR(100) = 'Attendance Not Taken'
		,@Body NVARCHAR(MAX) = '<p>Dear Professor {{LAST_NAME}},</p>
									<p>According to the college''s records, you did not report attendance for {{Missing}} {{students}} in <strong>{{EVENT_ID}} / {{SECTION}}</strong> on class meeting date <strong>{{CALENDAR_DATE}}</strong>.</p>
									<p>Please address this matter as soon as possible.</p>
									<p><a href="https://selfservice.mcny.edu/Classes/CourseManagement">Self-Service Course Management</a></p>'
	DECLARE @AcademicYear NVARCHAR(4) = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
			)
		,@AcademicTerm NVARCHAR(10) = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)

	--Build list of section meetings missing attendance and count of students missing attendance
	SELECT TD.ACADEMIC_YEAR
		,TD.ACADEMIC_TERM
		,TD.ACADEMIC_SESSION
		,TD.EVENT_ID
		,TD.SECTION
		,TD.EVENT_SUB_TYPE
		,S.CURRICULUM
		,CALENDAR_DATE
		,COUNT(DISTINCT TD.PEOPLE_ID) [Missing] --Number of students missing attendance for this meeting
	INTO #AttendanceNotTaken
	FROM TRANSCRIPTDETAIL TD
	INNER JOIN [custom].vwACADEMIC A
		ON A.PEOPLE_ID = TD.PEOPLE_ID
			AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
			AND A.ACADEMIC_TERM = TD.ACADEMIC_TERM
			AND A.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
			AND A.ENROLL_SEPARATION = 'ENRL' --Exclude students who withdrew from the term
	INNER JOIN SECTIONS S
		ON S.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
			AND S.ACADEMIC_TERM = TD.ACADEMIC_TERM
			AND S.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
			AND S.EVENT_ID = TD.EVENT_ID
			AND S.EVENT_SUB_TYPE = TD.EVENT_SUB_TYPE
			AND S.SECTION = TD.SECTION
			AND S.EVENT_STATUS = 'A'
	INNER JOIN SECTIONSCHEDULE SS
		ON TD.ACADEMIC_YEAR = SS.ACADEMIC_YEAR
			AND TD.ACADEMIC_TERM = SS.ACADEMIC_TERM
			AND TD.ACADEMIC_SESSION = SS.ACADEMIC_SESSION
			AND TD.EVENT_ID = SS.EVENT_ID
			AND TD.EVENT_SUB_TYPE = SS.EVENT_SUB_TYPE
			AND TD.SECTION = SS.SECTION
	INNER JOIN CALENDARDETAIL CD
		ON CD.EVENT_KEY = SS.CALENDARDET_EVENT_KEY
	INNER JOIN CALENDAR C
		ON C.EVENT_KEY = CD.EVENT_KEY
	LEFT JOIN TRANATTENDANCE TA
		ON TA.CalendarKey = C.CALENDAR_KEY
			AND TA.PEOPLE_ID = TD.PEOPLE_ID
	WHERE TD.ACADEMIC_YEAR = @AcademicYear
		AND TD.ACADEMIC_TERM = @AcademicTerm
		AND TD.ADD_DROP_WAIT = 'A' --Exclude students who dropped
		--Exclude students who withdrew from the section (not dropped)
		AND TD.FINAL_GRADE NOT IN (
			SELECT GRADE
			FROM GRADEVALUES GV
			WHERE GV.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
				AND GV.ACADEMIC_TERM = TD.ACADEMIC_TERM
				AND GV.CREDIT_TYPE = TD.CREDIT_TYPE
				AND WITHDRAWN_GRADE = 'Y'
			)
		--AND (
		--	(
		--		--Eight days after for online courses
		--		LEFT(S.SECTION, 1) = 'D'
		--		AND DATEDIFF(DAY, CALENDAR_DATE, GETDATE()) = 8
		--		)
		--	OR (
		--		--Two days after for in-person courses
		--		LEFT(S.SECTION, 1) <> 'D'
		--		--AND DATEDIFF(DAY, CALENDAR_DATE, GETDATE()) = 2
		--		AND DATEDIFF(DAY, CALENDAR_DATE, GETDATE()) = 8
		--		)
		--	)
		AND CALENDAR_DATE BETWEEN CAST(GETDATE() - 7 AS DATE) AND CAST(GETDATE() - 1 AS DATE) --Within the previous academic week (Monday-Sunday)
		AND TA.TranAttendanceId IS NULL --Only students WITHOUT attendance recorded
		AND S.SECTION NOT LIKE 'MIS%' --Do not include independent study sections
		AND S.SECTION NOT LIKE 'MBA 50[1-4] FDN' --Do not include MBA foundation sections
	GROUP BY c.CALENDAR_KEY
		,TD.ACADEMIC_YEAR
		,TD.ACADEMIC_TERM
		,TD.ACADEMIC_SESSION
		,TD.EVENT_ID
		,TD.SECTION
		,TD.EVENT_SUB_TYPE
		,CALENDAR_DATE
		,S.CURRICULUM

	--Create #Messages table and join to SECTIONPER for faculty (recipient) and CODE_CURRICULUM for program director (sender)
	SELECT CODE_CURRICULUM.CODE_XVAL [fromId]
		,FAC.PEOPLE_CODE_ID [toId]
		,0 [toTypeFlag]
		,@Subject [subject]
		,@Body [body]
		,0 [formatBodyFlag]
		--Fields for merging
		,FAC.PEOPLE_CODE_ID
		,Missing
		,A.EVENT_ID
		,A.SECTION
		,CALENDAR_DATE
	INTO #Messages
	FROM #AttendanceNotTaken A
	INNER JOIN SECTIONPER SP
		ON SP.ACADEMIC_YEAR = A.ACADEMIC_YEAR
			AND SP.ACADEMIC_TERM = A.ACADEMIC_TERM
			AND SP.ACADEMIC_SESSION = A.ACADEMIC_SESSION
			AND SP.EVENT_ID = A.EVENT_ID
			AND SP.EVENT_SUB_TYPE = A.EVENT_SUB_TYPE
			AND SP.SECTION = A.SECTION
			AND [PERCENTAGE] > 0
	INNER JOIN PEOPLE FAC
		ON FAC.PEOPLE_CODE_ID = SP.PERSON_CODE_ID
	LEFT JOIN CODE_CURRICULUM
		ON CODE_VALUE_KEY = CURRICULUM

	--Supply merge fields in the body
	UPDATE #Messages
	SET body = REPLACE(body, '{{Missing}}', Missing)

	UPDATE #Messages
	SET body = REPLACE(body, '{{students}}', CASE 
				WHEN Missing > 1
					THEN 'students'
				ELSE 'student'
				END)

	UPDATE #Messages
	SET body = REPLACE(body, '{{LAST_NAME}}', dbo.fnPeopleOrgName(PEOPLE_CODE_ID, 'LN')) --Display name using Ellucian's name format fuction

	UPDATE #Messages
	SET body = REPLACE(body, '{{EVENT_ID}}', EVENT_ID)

	UPDATE #Messages
	SET body = REPLACE(body, '{{SECTION}}', SECTION)

	UPDATE #Messages
	SET body = REPLACE(body, '{{CALENDAR_DATE}}', FORMAT(CALENDAR_DATE, 'D'))

	--Send emails
	EXEC [custom].[spSendEmails];

	DROP TABLE #Messages
		,#AttendanceNotTaken;

	COMMIT TRAN SendEmails
END
GO

