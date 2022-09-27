USE [Campus6]
GO
/****** Object:  StoredProcedure [custom].[insAttendanceForLateRegistrants]    Script Date: 2022-09-27 14:35:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-11-03
-- Description:	Inserts ABSENT records in TRANATTENDANCE automatically if students register after a class meeting occured.
--				Has some logic to exclude withdrawn students, cancelled sections, sections created after attendance date, etc.
--				Created for PowerCampus 9.1.4
--
-- 2021-11-09 Wyatt Best:		Put into production.
-- 2022-09-27 Wyatt Best:		Added PRIMARY_FLAG = 'Y' to prevent duplicate insertions.
-- =============================================
ALTER PROCEDURE [custom].[insAttendanceForLateRegistrants]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @AcademicYear NVARCHAR(4) = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
			)
		,@AcademicTerm NVARCHAR(10) = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)
		,@Today DATETIME = dbo.fnmakedate(getdate())
		,@Now DATETIME = dbo.fnmaketime(getdate())
		,@Opid NVARCHAR(8) = 'SYSTEM'
		,@AttendanceStatus NVARCHAR(20) = 'ABSENT'
		,@Comment NVARCHAR(100) = 'Student registered after this meeting and was automatically marked absent.'

	INSERT INTO [dbo].[TRANATTENDANCE] (
		[PEOPLE_CODE]
		,[PEOPLE_ID]
		,[PEOPLE_CODE_ID]
		,[ACADEMIC_YEAR]
		,[ACADEMIC_TERM]
		,[ACADEMIC_SESSION]
		,[EVENT_ID]
		,[EVENT_SUB_TYPE]
		,[SECTION]
		,[ATTENDANCE_DATE]
		,[ATTENDANCE_STATUS]
		,[CREATE_DATE]
		,[CREATE_TIME]
		,[CREATE_OPID]
		,[CREATE_TERMINAL]
		,[REVISION_DATE]
		,[REVISION_TIME]
		,[REVISION_OPID]
		,[REVISION_TERMINAL]
		,[ABT_JOIN]
		,[COMMENTS]
		,[CalendarKey]
		)
	SELECT TD.[PEOPLE_CODE]
		,TD.[PEOPLE_ID]
		,TD.[PEOPLE_CODE_ID]
		,TD.[ACADEMIC_YEAR]
		,TD.[ACADEMIC_TERM]
		,TD.[ACADEMIC_SESSION]
		,TD.[EVENT_ID]
		,TD.[EVENT_SUB_TYPE]
		,TD.[SECTION]
		,C.CALENDAR_DATE AS [ATTENDANCE_DATE]
		,@AttendanceStatus AS [ATTENDANCE_STATUS]
		,@Today AS [CREATE_DATE]
		,@Now AS [CREATE_TIME]
		,@Opid AS [CREATE_OPID]
		,'0001' AS [CREATE_TERMINAL]
		,@Today AS [REVISION_DATE]
		,@Now AS [REVISION_TIME]
		,@Opid AS [REVISION_OPID]
		,'0001' AS [REVISION_TERMINAL]
		,'*' AS [ABT_JOIN]
		,@Comment AS [COMMENTS]
		,CALENDAR_KEY AS [CALENDAR_KEY]
	FROM TRANSCRIPTDETAIL TD
	INNER JOIN ACADEMIC A
		ON A.PEOPLE_CODE_ID = TD.PEOPLE_CODE_ID
			AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
			AND A.ACADEMIC_TERM = TD.ACADEMIC_TERM
			AND A.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
			AND A.[STATUS] <> 'N'
			AND A.PRIMARY_FLAG= 'Y'
			--Exclude students who withdrew from the term
			AND A.ENROLL_SEPARATION IN (
				SELECT CODE_VALUE_KEY
				FROM CODE_ENROLLMENT
				WHERE REQUIRE_SEPDATE = 'N'
				)
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
			AND TA.PEOPLE_CODE_ID = TD.PEOPLE_CODE_ID
	WHERE TD.ACADEMIC_YEAR = @AcademicYear
		AND TD.ACADEMIC_TERM = @AcademicTerm
		--Exclude students who dropped section
		AND TD.ADD_DROP_WAIT = 'A'
		--Attendance record not exists
		AND TA.EVENT_ID IS NULL
		--Exclude students who withdrew from the section (not dropped)
		AND TD.FINAL_GRADE NOT IN (
			SELECT GRADE
			FROM GRADEVALUES GV
			WHERE GV.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
				AND GV.ACADEMIC_TERM = TD.ACADEMIC_TERM
				AND GV.CREDIT_TYPE = TD.CREDIT_TYPE
				AND WITHDRAWN_GRADE = 'Y'
			)
		--Registered later than the attendance date
		AND TD.STATUS_DATE > C.CALENDAR_DATE
		--Exclude sections created later than the attendance date
		AND (S.CREATE_DATE + S.CREATE_TIME) < (C.CALENDAR_DATE + C.END_TIME)
	OPTION (FORCE ORDER)
END
