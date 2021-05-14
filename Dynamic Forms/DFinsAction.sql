USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFinsAction]    Script Date: 2021-05-14 10:48:05 ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [custom].[DFinsAction] @action_id NVARCHAR(8)
	,@action_name NVARCHAR(50) = NULL --Will default from Action Definition
	,@people_code_id NVARCHAR(10)
	,@request_date DATE = NULL
	,@request_time TIME = NULL
	,@year NVARCHAR(4) = NULL
	,@term NVARCHAR(10) = NULL
	,@usecurrterm BIT = NULL
	,@session NVARCHAR(10) = NULL
	,@sched_date DATE --Scheduled Date in the UI
	,@sched_time TIME = NULL --Scheduled Time in the UI
	,@start_time TIME = NULL --Not stored directly; used to calculate duration. Doesn't support >24 hours.
	,@end_time TIME = NULL --Not stored directly; used to calculate duration. Doesn't support >24 hours.
	,@required NVARCHAR(1) = 'N'
	,@rating NVARCHAR(3) = NULL
	,@resp_staff NVARCHAR(10) = NULL
	,@completed NVARCHAR(1) = 'N'
	,@completed_by NVARCHAR(10) = NULL
	,@execution_date DATE = NULL --Completed Date in UI
	,@canceled NVARCHAR(1) = 'N'
	,@canceled_reason NVARCHAR(6) = NULL
	,@note NVARCHAR(max) = NULL
	,@response NVARCHAR(6) = NULL
	,@opid NVARCHAR(8) = 'DYNFORMS'
	,@instructions NVARCHAR(max) = NULL
AS
/***********************************************************************
Description:
	Inserts a scheduled action. Intended to be used by the Dynamic Forms API.
	Based on MCNY_SP_insert_action.

Created: 2020-07-09 by Wyatt Best

2021-01-08 Wyatt Best:		Added a bunch more columns.
2021-01-09 Adrian Smith:	Added ' OR @request_date IS NULL' and similar due to API errors from submissions on the morning of 2021-01-09.
2021-05-14 Wyatt Best:		Added @instructions column.
							Made @sched_date required so that some submissions will silently exit. For forms that create multiple actions and may have unused rows.

Example usage:
	EXEC [custom].DFinsAction @action_id = 'SYCVIDHS'
		,@people_code_id = 'P000141351'
		,@required = 'Y'
		,@completed = 'Y'
		,@note = 'Health Screening OK'
		,@response = 'POS'
************************************************************************/
DECLARE @unique NVARCHAR(50)
	,@datetime DATETIME = getdate()
	,@today DATETIME = dbo.fnMakeDate(getdate())
	,@now DATETIME = dbo.fnMakeTime(getdate())

--Dynamic Forms has an annoying habit of passing blanks instead of nulls/omitting parameters
IF @action_name = ''
	SET @action_name = NULL

IF @request_date = ''
	OR @request_date IS NULL
	SET @request_date = GETDATE()

IF @request_time = ''
	OR @request_time IS NULL
	SET @request_time = GETDATE()

IF @sched_date = ''
	RETURN

IF @sched_time = ''
	OR @sched_time IS NULL
	SET @sched_time = GETDATE()

IF @rating = ''
	SET @rating = NULL

IF @resp_staff = ''
	SET @resp_staff = NULL

IF @completed_by = ''
	SET @completed_by = NULL

IF @response = ''
	SET @response = NULL

IF @execution_date = ''
	SET @execution_date = NULL

IF @canceled = ''
	SET @canceled = 'N'
SET @canceled_reason = nullif(@canceled_reason, '')
SET @note = nullif(@note, '')
SET @instructions = nullif(@instructions, '')

IF @opid = ''
	SET @opid = 'DYNFORMS'

--Get current term if Use Current Term flag true
IF @usecurrterm = 1
	SELECT @year = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
			)
		,@term = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)

--Verify @action_id staff is real
IF (
		NOT EXISTS (
			SELECT *
			FROM [ACTION]
			WHERE ACTION_ID = @action_id
			)
		)
BEGIN
	RAISERROR (
			'@action_id not found in ACTION.'
			,11
			,1
			)

	RETURN
END

--Verify @people_code_id is real
IF (
		NOT EXISTS (
			SELECT *
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @people_code_id
			)
		)
BEGIN
	RAISERROR (
			'@people_code_id not found in PEOPLE.'
			,11
			,1
			)

	RETURN
END

--Verify @resp_staff staff is real
IF (
		@resp_staff IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @resp_staff
			)
		)
BEGIN
	RAISERROR (
			'@resp_staff not found in PEOPLE.'
			,11
			,1
			)

	RETURN
END

--Verify @people_code_id is real
IF (
		NOT EXISTS (
			SELECT *
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @people_code_id
			)
		)
BEGIN
	RAISERROR (
			'@people_code_id not found in PEOPLE.'
			,11
			,1
			)

	RETURN
END

--Verify @completed_by staff is real
IF (
		@completed_by IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @completed_by
			)
		)
BEGIN
	RAISERROR (
			'@completed_by not found in PEOPLE.'
			,11
			,1
			)

	RETURN
END

--Verify if @rating is real
IF (
		@rating IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM CODE_RATING
			WHERE CODE_VALUE_KEY = @rating
			)
		)
BEGIN
	RAISERROR (
			'@rating not found in CODE_RATING.'
			,11
			,1
			)

	RETURN
END

--Verify @response is real
IF (
		@response IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM CODE_RESPONSE
			WHERE CODE_VALUE_KEY = @response
			)
		)
BEGIN
	RAISERROR (
			'@response not found in CODE_RESPONSE.'
			,11
			,1
			)

	RETURN
END

--Verify @canceled_reason is real
IF (
		@canceled_reason IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM CODE_CANCELREASON
			WHERE CODE_VALUE_KEY = @canceled_reason
			)
		)
BEGIN
	RAISERROR (
			'@canceled_reason not found in CODE_CANCELREASON.'
			,11
			,1
			)

	RETURN
END

--Default ACADEMIC_YEAR, ACADEMIC_TERM, ACADEMIC_SESSION
IF (@year = NULL)
	EXEC sp_tk_curryear ''
		,''
		,''
		,''
		,@year OUTPUT

IF (@term = NULL)
	EXEC sp_tk_currterm ''
		,''
		,''
		,''
		,@term OUTPUT

IF (@session = NULL)
	SELECT @session = ''

SELECT @unique = @action_id + convert(NVARCHAR(4), datepart(yy, @datetime)) + convert(NVARCHAR(2), datepart(mm, @datetime)) + convert(NVARCHAR(2), datepart(dd, @datetime)) + convert(NVARCHAR(2), datepart(hh, @datetime)) + convert(NVARCHAR(2), datepart(mi, @datetime)) + convert(NVARCHAR(4), datepart(ms, @datetime))

--Default some values for completed actions
IF @completed = 'Y'
	AND @completed_by IS NULL
	SET @completed_by = @people_code_id
--Sanity check on execution date
SET @execution_date = (
		CASE WHEN @execution_date IS NOT NULL
				AND @completed = 'N' THEN NULL WHEN @execution_date IS NULL
				AND @completed = 'Y' THEN @today ELSE @execution_date END
		)

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
	,Instruction
	)
SELECT @action_id [ACTION_ID]
	,substring(@people_code_id, 1, 1) [PEOPLE_ORG_CODE]
	,substring(@people_code_id, 2, 9) [PEOPLE_ORG_ID]
	,@people_code_id [PEOPLE_ORG_CODE_ID]
	,@request_date [REQUEST_DATE]
	,@request_time [REQUEST_TIME]
	,dbo.fnMakeDate(@sched_date) [SCHEDULED_DATE]
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
	,@rating [RATING]
	,@response [RESPONSE]
	,'' [CONTACT]
	,dbo.fnMakeTime(@sched_time) [SCHEDULED_TIME]
	,@note [NOTE]
	,@unique [UNIQUE_KEY]
	,@completed [COMPLETED]
	,'N' [WAIVED]
	,'' [WAIVED_REASON]
	,@canceled [CANCELED]
	,@canceled_reason [CANCELED_REASON]
	,0 [NUM_OF_REMINDERS]
	,@year [ACADEMIC_YEAR]
	,@term [ACADEMIC_TERM]
	,@session [ACADEMIC_SESSION]
	,0 [RULE_ID]
	,0 [SEQ_NUM]
	,'   ' + (CASE WHEN DATEDIFF(hour, @start_time, @end_time) > 0 THEN RIGHT('  ' + CAST(FLOOR(DATEDIFF(MINUTE, @start_time, @end_time) / 60) AS NVARCHAR(10)), 2) ELSE '  ' END) + CASE WHEN DATEDIFF(MINUTE, @start_time, @end_time) > 0 THEN RIGHT('  ' + CAST(DATEDIFF(MINUTE, @start_time, @end_time) % 60 AS NVARCHAR(10)), 2) ELSE '  ' END [Duration]
	,NULL [DOCUMENT]
	,@instructions [Instruction]
FROM [ACTION] A
WHERE ACTION_ID = @action_id
