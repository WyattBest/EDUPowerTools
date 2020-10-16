USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFinsAction]    Script Date: 2020-10-16 11:55:29 ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [custom].[DFinsAction]
	@action_id			nvarchar(8)
	,@action_name		nvarchar(50) = NULL		--Will default from Action Definition
	,@people_code_id	nvarchar(10)
	,@year				nvarchar(4) =  NULL
	,@term				nvarchar(10) = NULL
	,@session			nvarchar(10) = NULL
	,@sched_datetime	datetime = NULL			--Scheduled Date and Time in the UI
	,@required			nvarchar(1) = 'N'
	,@resp_staff		nvarchar(10) = NULL
	,@completed			nvarchar(1) = 'N'
	,@completed_by		nvarchar(10) = NULL
	,@execution_date	date = NULL				--Completed Date in UI
	,@note				nvarchar(max) = NULL
	,@response			nvarchar(6) = NULL
	,@opid				nvarchar(8) = 'DYNFORMS'
as
/***********************************************************************
Description:
	Inserts a scheduled action. Intended to be used by the Dynamic Forms API.
	Based on MCNY_SP_insert_action.

Created: 2020-07-09 by Wyatt Best

Example usage:
	EXEC [custom].DFinsAction @action_id = 'SYCVIDHS'
		,@people_code_id = 'P000141351'
		,@required = 'Y'
		,@completed = 'Y'
		,@note = 'Health Screening OK'
		,@response = 'POS'
************************************************************************/

DECLARE 
	@unique NVARCHAR(50)
	,@datetime DATETIME = getdate()
	,@today DATETIME = dbo.fnMakeDate(getdate())
	,@now DATETIME = dbo.fnMakeTime(getdate())

SET @sched_datetime = ISNULL(@sched_datetime, GETDATE())

--Verify @action_id staff is real
IF (NOT EXISTS (SELECT * FROM [ACTION] WHERE ACTION_ID = @action_id))
BEGIN
	RAISERROR ('@action_id not found in ACTION.', 11, 1)
	RETURN
END

--Verify @people_code_id is real
IF (NOT EXISTS (SELECT * FROM PEOPLE WHERE PEOPLE_CODE_ID = @people_code_id))
BEGIN
	RAISERROR ('@people_code_id not found in PEOPLE.', 11, 1)
	RETURN
END

--Verify @resp_staff staff is real
IF (@resp_staff  IS NOT NULL AND NOT EXISTS (SELECT * FROM PEOPLE WHERE PEOPLE_CODE_ID = @resp_staff))
BEGIN
	RAISERROR ('@resp_staff not found in PEOPLE.', 11, 1)
	RETURN
END

--Verify @people_code_id is real
IF (NOT EXISTS (SELECT * FROM PEOPLE WHERE PEOPLE_CODE_ID = @people_code_id))
BEGIN
	RAISERROR ('@people_code_id not found in PEOPLE.', 11, 1)
	RETURN
END

--Verify @completed_by staff is real
IF (@completed_by  IS NOT NULL AND NOT EXISTS (SELECT * FROM PEOPLE WHERE PEOPLE_CODE_ID = @completed_by))
BEGIN
	RAISERROR ('@completed_by not found in PEOPLE.', 11, 1)
	RETURN
END

--Verify @response is real
IF (NOT EXISTS (SELECT * FROM CODE_RESPONSE WHERE CODE_VALUE_KEY = @response))
BEGIN
	RAISERROR ('@response not found in CODE_RESPONSE .', 11, 1)
	RETURN
END

--Default ACADEMIC_YEAR, ACADEMIC_TERM, ACADEMIC_SESSION
if (@year = NULL) exec sp_tk_curryear '', '','','', @year output
if (@term = NULL) exec sp_tk_currterm '', '','','', @term output
if (@session = NULL) select @session = ''

select @unique=@action_id +
convert(nvarchar(4),datepart(yy,@datetime)) +
convert(nvarchar(2),datepart(mm,@datetime)) +
convert(nvarchar(2),datepart(dd,@datetime)) +
convert(nvarchar(2),datepart(hh,@datetime)) +
convert(nvarchar(2),datepart(mi,@datetime)) +
convert(nvarchar(4),datepart(ms,@datetime))

--Default some values for completed actions
IF @completed = 'Y' AND @completed_by IS NULL
	SET @completed_by = @people_code_id

SET @execution_date =
	(CASE
		WHEN @execution_date IS NOT NULL AND @completed = 'N' THEN NULL
		WHEN @execution_date IS NULL AND @completed = 'Y' THEN @today
	END)

--Insert the scheduled action
INSERT INTO ACTIONSCHEDULE (
	ACTION_ID
	,PEOPLE_ORG_CODE
	,PEOPLE_ORG_ID
	,PEOPLE_ORG_CODE_ID
	,REQUEST_DATE
	,REQUEST_TIME
	,SCHEDULED_DATE
	,EXECUTION_DATE
	,CREATE_DATE
	,CREATE_TIME
	,CREATE_OPID
	,CREATE_TERMINAL
	,REVISION_DATE
	,REVISION_TIME
	,REVISION_OPID
	,REVISION_TERMINAL
	,ABT_JOIN
	,ACTION_NAME
	,OFFICE
	,[TYPE]
	,RESP_STAFF
	,COMPLETED_BY
	,[REQUIRED]
	,[PRIORITY]
	,RATING
	,RESPONSE
	,CONTACT
	,SCHEDULED_TIME
	,NOTE
	,UNIQUE_KEY
	,COMPLETED
	,WAIVED
	,WAIVED_REASON
	,CANCELED
	,CANCELED_REASON
	,NUM_OF_REMINDERS
	,ACADEMIC_YEAR
	,ACADEMIC_TERM
	,ACADEMIC_SESSION
	,RULE_ID
	,SEQ_NUM
	,DURATION
	,DOCUMENT
	)
SELECT @action_id [ACTION_ID]
	,substring(@people_code_id, 1, 1) [PEOPLE_ORG_CODE]
	,substring(@people_code_id, 2, 9) [PEOPLE_ORG_ID]
	,@people_code_id [PEOPLE_ORG_CODE_ID]
	,@today [REQUEST_DATE]
	,@now [REQUEST_TIME]
	,dbo.fnMakeDate(@sched_datetime) [SCHEDULED_DATE]
	,@execution_date [EXECUTION_DATE]
	,@today [CREATE_DATE]
	,@now [CREATE_TIME]
	,@opid [CREATE_OPID]
	,'0001' [CREATE_TERMINAL]
	,@today [REVISION_DATE]
	,@now [REVISION_TIME]
	,@opid [REVISION_OPID]
	,'0001' [REVISION_TERMINAL]
	,'*' [ABT_JOIN]
	,coalesce(@action_name, A.ACTION_NAME) [ACTION_NAME]
	,OFFICE
	,[TYPE]
	,@resp_staff [RESP_STAFF]
	,@completed_by [COMPLETED_BY]
	,REQUIRED [REQUIRED]
	,PRIORITY [PRIORITY]
	,'' [RATING]
	,@response [RESPONSE]
	,'' [CONTACT]
	,dbo.fnMakeTime(@sched_datetime) [SCHEDULED_TIME]
	,@note [NOTE]
	,@unique [UNIQUE_KEY]
	,@completed [COMPLETED]
	,'N' [WAIVED]
	,'' [WAIVED_REASON]
	,'N' [CANCELED]
	,'' [CANCELED_REASON]
	,0 [NUM_OF_REMINDERS]
	,@year [ACADEMIC_YEAR]
	,@term [ACADEMIC_TERM]
	,@session [ACADEMIC_SESSION]
	,0 [RULE_ID]
	,0 [SEQ_NUM]
	,NULL [DURATION]
	,NULL [DOCUMENT]
FROM [ACTION] A
WHERE ACTION_ID = @action_id

GO

