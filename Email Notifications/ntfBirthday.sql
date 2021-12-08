USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[ntfBirthday]    Script Date: 2021-12-08 15:13:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-11-09
-- Description:	Email a happy birthday message to students in the current term.
--				If classes for the current term haven't yet started, include students from the previous term also.
--
-- 2020-12-08 Wyatt Best:		Put into production.
-- =============================================
CREATE PROCEDURE [custom].[ntfBirthday]
AS
BEGIN
	--Stop on all errors.
	SET XACT_ABORT ON
	SET NOCOUNT ON

	--Email subject and body
	DECLARE @Subject NVARCHAR(100) = 'Happy Birthday!'
		,@Body NVARCHAR(MAX) = '<p>Dear {{FIRST_NAME}},</p>
								<p>We want to share a special message on YOUR special day!</p>
								<p>
									Behind you all your
									<br />"Memories"
									<br />Before you, all your
									<br />"Dreams"
									<br />Around you all your
									<br />"Loved ones"
									<br />Within you all you
									<br />"Need"
									<br />Happy Birthday!!!!
								</p>
								<p>
									Peace, Love, and Happiness,
									<br />From your MCNY family
								</p>
								<br />
								<br />
								<br />
								<br />
								<br />
								<p><small>If you do not wish to receive birthday emails from us, just reply to this email and let us know.</small></p>'
	DECLARE @AcademicYear NVARCHAR(4) = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
			)
		,@AcademicTerm NVARCHAR(10) = (
			SELECT dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)
		,@EndTermId INT = [custom].fnGetCurrentTermId()
	DECLARE @StartTermId INT = (
			SELECT CASE 
					--If current term classes have started, don't include previous term.
					WHEN [START_DATE] <= CAST(GETDATE() AS DATE)
						THEN @EndTermId
					ELSE @EndTermId - 1
					END AS TermId
			FROM ACADEMICCALENDAR
			WHERE ACADEMIC_YEAR = @AcademicYear
				AND ACADEMIC_TERM = @AcademicTerm
				AND ACADEMIC_SESSION = '01'
			)

	SELECT TOP 1 'studentlife@mcny.edu' [from]
		,P.PEOPLE_CODE_ID [toId]
		,'wbest@mcny.edu' [bcc] --Debug
		,'P000164272' [bccId] --Debug
		,0 [toTypeFlag]
		,@Subject [subject]
		,@Body [body]
		,1 [formatBodyFlag]
	INTO #Messages
	FROM PEOPLE P
	INNER JOIN [custom].vwACADEMIC A
		ON A.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
	WHERE 1 = 1
		AND A.TermId BETWEEN @StartTermId AND @EndTermId
		AND A.[STATUS] <> 'N'
		AND A.ACADEMIC_FLAG = 'Y'
		--Actually took classes
		AND EXISTS (
			SELECT *
			FROM TRANSCRIPTDETAIL TD
			WHERE TD.PEOPLE_CODE_ID = A.PEOPLE_CODE_ID
				AND TD.ACADEMIC_YEAR = A.ACADEMIC_YEAR
				AND TD.ACADEMIC_TERM = A.ACADEMIC_TERM
				AND TD.ACADEMIC_SESSION = A.ACADEMIC_SESSION
				AND TD.TRANSCRIPT_SEQ = A.TRANSCRIPT_SEQ
				AND TD.ADD_DROP_WAIT = 'A'
			)
		AND DATEPART(MONTH, BIRTH_DATE) = DATEPART(MONTH, getdate())
		AND DATEPART(DAY, BIRTH_DATE) = DATEPART(DAY, getdate())
		--Don't send email twice on same day
		AND NOT EXISTS (
			SELECT *
			FROM MESSAGEQUEUE MQ
			INNER JOIN MESSAGERECIPIENTS MR
				ON MR.MESSAGEID = MQ.MESSAGEID
					AND MR.RECIPIENTTYPE = 'to'
					AND MR.PEOPLECODEID = P.PEOPLE_CODE_ID
					AND CAST(MQ.CREATE_DATE AS DATE) = CAST(GETDATE() AS DATE)
			WHERE MQ.[SUBJECT] = @Subject
			)

	--Supply merge fields in the body
	UPDATE #Messages
	SET body = REPLACE(body, '{{FIRST_NAME}}', dbo.fnPeopleOrgName([toId], 'DN'))

	--Debug
	--SELECT *
	--FROM #MESSAGES;

	--Send emails
	EXEC [custom].[spSendEmails];

	DROP TABLE #Messages;
END
GO

