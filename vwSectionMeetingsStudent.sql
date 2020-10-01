USE [Campus6]
GO

/****** Object:  View [custom].[vwSectionMeetingsStudent]    Script Date: 2020-10-01 11:08:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [custom].[vwSectionMeetingsStudent]
AS
/***********************************************************************
Description:
	A flattened view of TRANSCRIPTDETAIL, SECTIONS, SECTIONSCHEDULE, CALENDARDETAIL, CALENDAR.
	Useful for querying a student's schedule for a term, finding detailed attendnace information, etc.
	
	Feel free to add columns but be careful not to make the execution plan too slow.

Revision History:
2020-08-31 Wyatt Best: Created

************************************************************************/
SELECT TD.PEOPLE_CODE_ID
	,TD.PEOPLE_ID
	,TermId
	,TD.ACADEMIC_YEAR
	,TD.ACADEMIC_TERM
	,TD.ACADEMIC_SESSION
	,TD.TRANSCRIPT_SEQ
	--,A.PROGRAM [A.PROGRAM]
	--,A.DEGREE [A.DEGREE]
	--,A.CURRICULUM [A.CURRICULUM]
	--,A.PRIMARY_FLAG [A.PRIMARY_FLAG]
	--,ENROLL_SEPARATION [A.ENROLL_SEPARATION]
	,TD.EVENT_ID
	,TD.EVENT_SUB_TYPE
	,TD.SECTION
	,TD.EVENT_MED_NAME
	,TD.EVENT_LONG_NAME
	,S.COLLEGE
	,S.DEPARTMENT
	--,S.[START_DATE]
	--,S.[END_DATE]
	,CALENDAR_DATE
	,C.START_TIME
	,C.END_TIME
	,DAY_OF_WEEK
	,C.BUILDING_CODE
	,C.ROOM_ID
	,SectionId
	,SECTIONSCHEDULE_ID
	,CD.EVENT_KEY
	,CALENDAR_KEY
FROM TRANSCRIPTDETAIL TD
--INNER JOIN [custom].vwACADEMIC A
--	ON A.PEOPLE_ID = TD.PEOPLE_ID
--		AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
--		AND A.ACADEMIC_TERM = TD.ACADEMIC_TERM
--		AND A.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
--		AND A.[STATUS] IN ('A', 'G')
INNER JOIN [custom].vwOrderedTerms OT
	ON OT.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
		AND OT.ACADEMIC_TERM = TD.ACADEMIC_TERM
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
		AND TD.ADD_DROP_WAIT = 'A'
INNER JOIN CALENDARDETAIL CD
	ON CD.EVENT_KEY = SS.CALENDARDET_EVENT_KEY
INNER JOIN CALENDAR C
	ON C.EVENT_KEY = CD.EVENT_KEY
GO

