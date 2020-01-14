USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spSendEmails]    Script Date: 2020-01-14 10:40:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2018-07-10
-- Description:	Easily send emails via MESSAGEQUEUE. Adds MCNY header, footer, and optionally body styling.
--
--				Features:	A) Set-based. No loops or dynamic SQL!
--							B) Accepts PEOPLE_CODE_ID's and/or emails. Easy to send messages without looking up addresses.
--							B) Most columns are optional.
--							C) Message are automatically de-duplicated. Messages where a [to] email can't be found will be discarded.
--							D) Can accept and return an input key with each message, making it easy to use Scheduled Actions to generate messages and mark actions complete.
--
--				Requires #Messages table as input; this table should already exist in the session.
--				Outputs a similarly constructed table containing messages sent along with new MESSAGEID's from MESSAGEQUEUE.
--				Depends on MCNY custom functions Get_MCNYEmail and Get_AltEmail.
--
-- Changelog:
-- 2019-10-31 Wyatt Best:	Updated https://selfservice.mcny.edu/SST/App_Themes/Default/Images/MCNY_logo_cp.gif to https://legacy.mcny.edu/App_Themes/Default/Images/MCNY_logo_cp.gif
--							Moved to [custom] schema and renamed from [dbo].[MCNY_SP_SendEmails]
-- 2019-12-05 Wyatt Best:	Made some columns optional. Made [toId] nullable. Added more validation logic.
--
-- TODO:
--		Replace XACT_ABORT with TRY/CATCH.
--		Add validation of PEOPLE_CODE_ID's.
--		Replace Get_MCNYEmail and Get_AltEmail with vista view.
--
-- Usage: Select some emails into #Messages table as shown above. Then EXEC [dbo].[MCNY_SP_SendEmails].
--		  People Code Id's can be used instead of actual email addresses.
--		  Columns marked with 'O' are optional columns that do not need to exist.
/*
	CREATE TABLE #Messages (
		[from] NVARCHAR(255) NOT NULL			--an email address
O		,[fromId] NVARCHAR(10) NULL				--sender People Code Id
O		,[to] NVARCHAR(255) NULL				--an email address. If NULL, will be automatically supplied from toId.
O		,[toId] NVARCHAR(10) NULL				--recipient People Code Id. If NULL, [to] must exist.
		,[toTypeFlag] SMALLINT NOT NULL			--Flag 0/1 to control which email to select for [to]. 0 = Campus address, 1 = Alternate address.
O		,[cc] NVARCHAR(255) NULL				--an email address. If NULL, will be automatically supplied from ccId.
O		,[ccId] NVARCHAR(10) NULL				--cc recipient People Code Id
O		,[bcc] NVARCHAR(255) NULL				--an email address. If NULL, will be automatically supplied from bccId.
O		,[bccId] NVARCHAR(10) NULL				--bcc recipient People Code Id
		,[subject] NVARCHAR(255) NOT NULL		--email subject line
		,[body] NVARCHAR(MAX) NOT NULL			--email body (HTML ok)
		,[formatBodyFlag] SMALLINT NOT NULL		--Flag 0/1 to indicate whether body should be wrapped with styling
O		,[uniqueKey] NVARCHAR(255) NULL	UNIQUE	--Can be used by caller to compare input and output rows. Suggest using [ACTIONSCHEDULE].[UNIQUE_KEY] for this purpose.
		);


--Simple example usage

	SELECT 'helpdesk@mcny.edu'		[from]
		,PEOPLE_CODE_ID				[toId]
		,0							[toTypeFlag] --Use Campus email
		,'Welcome'					[subject]
		,'You''re receiving this email because you''re enrolled at our wonderful school!' [body]
		,1							[formatBodyFlag]
	INTO #Messages
	FROM ACADEMIC
	WHERE ACADEMIC_YEAR = '2020'
		AND ACADEMIC_TERM = 'SPRING'
		AND CREDITS > 0

	EXEC [custom].spSendEmails;

*/
-- =============================================
CREATE PROCEDURE [custom].[spSendEmails]
	
AS
BEGIN
	
	SET NOCOUNT ON;
	SET XACT_ABORT ON; --Stop on all errors.

	DECLARE @Today datetime = dbo.fnMakeDate(getdate())
	DECLARE @Now datetime = dbo.fnMakeTime(getdate())

	--Make sure we have a recipient column specified
	IF 'to' NOT IN (
			SELECT [name]
			FROM tempdb.sys.columns
			WHERE [object_id] = OBJECT_ID('tempdb..#Messages')
			)
	BEGIN
		IF 'toId' NOT IN (
				SELECT [name]
				FROM tempdb.sys.columns
				WHERE [object_id] = OBJECT_ID('tempdb..#Messages')
				)
		BEGIN
			RAISERROR('#Messages must contain at least one recipient column ([to], [toId]).', 11, 1)
		END
	END

	CREATE TABLE #MessagesStrict (
		[msKey] INT IDENTITY PRIMARY KEY		--Identity key used internally by the procedure
		,[from] NVARCHAR(255) NOT NULL			--an email address
		,[fromId] NVARCHAR(10) NULL				--sender People Code Id
		,[to] NVARCHAR(255) NULL				--an email address. If NULL, will be automatically supplied from toId.
		,[toId] NVARCHAR(10) NULL				--recipient People Code Id
		,[toTypeFlag] SMALLINT NOT NULL			--Flag 0/1 to control which email to select for [to]. 0 = Campus address, 1 = Alternate address.
		,[cc] NVARCHAR(255) NULL				--an email address. If NULL, will be automatically supplied from ccId.
		,[ccId] NVARCHAR(10) NULL				--cc recipient People Code Id
		,[bcc] NVARCHAR(255) NULL				--an email address. If NULL, will be automatically supplied from bccId.
		,[bccId] NVARCHAR(10) NULL				--bcc recipient People Code Id
		,[subject] NVARCHAR(255) NOT NULL		--email subject line
		,[body] NVARCHAR(MAX) NOT NULL			--email body (HTML ok)
		,[formatBodyFlag] SMALLINT NOT NULL		--Flag 0/1 to indicate whether body should be wrapped with styling
		,[uniqueKey] NVARCHAR(255) NULL			--Can be used by caller to compare input and output rows. Suggest using [ACTIONSCHEDULE].[UNIQUE_KEY] for this purpose. Add [toId] to comparison, as [UNIQUE_KEY] isn't always unique.
		,[MESSAGEID] INT NULL					--Will be used later to link MESSAGEQUE to MESSAGERECIPIENTS
		);

	
	--Add optional columns
	IF 'fromId' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [fromId] NVARCHAR(255) NULL
	END;

	IF 'to' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [to] NVARCHAR(255) NULL
	END;

	IF 'toId' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [toId] NVARCHAR(10) NULL
	END;
	
	IF 'cc' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [cc] NVARCHAR(255) NULL
	END;

	IF 'ccId' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [ccId] NVARCHAR(255) NULL
	END;

	IF 'bcc' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [bcc] NVARCHAR(255) NULL
	END;

	IF 'bccId' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [bccId] NVARCHAR(255) NULL
	END;

	IF 'uniqueKey' NOT IN (SELECT [name] FROM tempdb.sys.columns WHERE [object_id] = OBJECT_ID('tempdb..#Messages'))
	BEGIN
		ALTER TABLE #Messages
		ADD [uniqueKey] NVARCHAR(255) NULL
	END;
	
	--A stupid step to prevent compiler from erroring because it doesn't recognize the new columns as existing.
	--Might be able to remove in a future version of SQL Server.
	SELECT * INTO #MessagesIntermediate
	FROM #Messages;

	--Create a 'strict' version, discarding any extra input and de-duplicating.
	INSERT INTO #MessagesStrict (
		[from]
		,[fromId]
		,[to]
		,[toId]
		,[toTypeFlag]
		,[cc]
		,[ccId]
		,[bcc]
		,[bccId]
		,[subject]
		,[body]
		,[formatBodyFlag]
		,[uniqueKey]
		)
	SELECT DISTINCT
		[from]
		,[fromId]
		,[to]
		,[toId]
		,[toTypeFlag]
		,[cc]
		,[ccId]
		,[bcc]
		,[bccId]
		,[subject]
		,[body]
		,[formatBodyFlag]
		,[uniqueKey]
	FROM #MessagesIntermediate;

    BEGIN TRAN MCNY_SP_SendEmails
		
		--Supply [to] campus addresses
		UPDATE #MessagesStrict
		SET [to] = [dbo].[Get_MCNYEmail]([toId])
		WHERE [to] IS NULL
			AND [toTypeFlag] = 0;

		--Supply [to] secondary addresses
		UPDATE #MessagesStrict
		SET [to] = [dbo].[Get_AltEmail]([toId])
		WHERE [to] IS NULL
			AND [toTypeFlag] = 1;
		
		--Delete messages where correct address couldn't be found
		DELETE FROM #MessagesStrict
		WHERE [to] IS NULL;

		--Supply [cc]
		UPDATE #MessagesStrict
		SET [cc] = [dbo].[fnGetPrimaryEmail]([ccId])
		WHERE [cc] IS NULL
			AND [ccId] IS NOT NULL;

		--Supply [bcc]
		UPDATE #MessagesStrict
		SET [bcc] = [dbo].[fnGetPrimaryEmail]([bccId])
		WHERE [bcc] IS NULL
			AND [bccId] IS NOT NULL;

		--Format bodies with inner styling (formatBodyFlag)
		UPDATE #MessagesStrict
		SET [body] = '<div style=''Margin-top:0;font-weight:normal;color:#677483;font-family:sans-serif;font-size:16px;line-height:25px;Margin-bottom:15px;''>' + [body] +'</div>'
		WHERE [formatBodyFlag] = 1;

		--Declare a table to hold new MESSAGEID's
		DECLARE @MessageIds TABLE
			([msKey] INT NOT NULL
			,[MESSAGEID] INT NOT NULL);

		--Insert into MESSAGEQUEUE. A MERGE statement is used to allow returning columns we didn't actually insert, specifically #MessagesStrict.sortKey.
		--MCNY header and footer are also added.
		MERGE INTO [MESSAGEQUEUE]
		USING #MessagesStrict M
			ON 1 = 0 --Will never be true, so no UPDATEs will ever happen
		WHEN NOT MATCHED
			THEN
				INSERT (
					[MESSAGESOURCE]
					,[SUBJECT]
					,[BODY]
					,[BODYFORMAT]
					,[TIMESENT]
					,[SENDER_EMAIL]
					,[PEOPLECODEID]
					,[HIDERECIPIENTS]
					,[SENDTIME]
					,[STATUS]
					,[CREATE_OPID]
					,[CREATE_TERMINAL]
					,[CREATE_DATE]
					,[CREATE_TIME]
					,[REVISION_OPID]
					,[REVISION_TERMINAL]
					,[REVISION_DATE]
					,[REVISION_TIME]
					)
				VALUES (
					''
					,M.[subject]
					,'<table class=''wrapper'' style=''border-spacing:0;width:100%;background-color:#f1f2f6;table-layout:fixed;''><tr><td align=''center'' class=''text-logo'' style=''padding-right:0;padding-left:0;vertical-align:top;padding-top:24px;padding-bottom:0;font-family:sans-serif;font-size:14px;color:#bec7cf;''><center><div class=''spacer body-buffer'' style=''font-size:20px;line-height:10px;display:block;''>&nbsp;</div><table class=''gmail hide'' style=''border-spacing:0;width:650px;min-width:650px;''><tr><td style=''padding-top:0;padding-bottom:0;padding-right:0;padding-left:0;vertical-align:top;font-size:1px;line-height:1px;''></td></tr></table><img src=''https://legacy.mcny.edu/App_Themes/Default/Images/MCNY_logo_cp.gif'' alt=''Metropolitan College of New York'' style=''border-width:0;-ms-interpolation-mode:bicubic;''></center></td></tr></table><table class=''wrapper'' style=''border-spacing:0;width:100%;background-color:#f1f2f6;table-layout:fixed;''><tr><td class=''main-content'' align=''center'' style=''padding-top:0;padding-bottom:0;padding-right:0;padding-left:0;vertical-align:top;''><div class=''spacer hide'' style=''font-size:10px;line-height:20px;height:20px;display:block;''>&nbsp;</div><center><table class=''table-top'' width=''610'' style=''border-spacing:0;Margin:0 auto;''><tr><td width=''100%'' style=''padding-top:0;padding-bottom:0;padding-right:0;padding-left:0;vertical-align:top;''></td></tr></table><!--[if gte mso 9]><table width=''610'' style=''border-spacing:0;''><tr><td style=''border-bottom-width:1px;border-bottom-style:solid;border-bottom-color:#e2e3e7;padding-top:0;padding-bottom:0;padding-right:0;padding-left:0;vertical-align:top;''>&nbsp;</td></tr></table><![endif]--><table class=''standard-white viewport'' width=''612'' style=''border-spacing:0;Margin:0 auto;''><tr><td class=''viewport'' width=''608'' bgcolor=''#ffffff'' style=''padding-top:0;padding-bottom:0;padding-right:0;padding-left:0;vertical-align:top;Margin:0 auto;''><table class=''public-canvas-top'' width=''100%'' style=''border-spacing:0;''><tr><td class=''pad-top pad-sides pad-bottom'' style=''vertical-align:top;padding-top:60px;padding-bottom:70px;padding-left:70px;padding-right:70px;''><table class=''download'' width=''100%'' style=''border-spacing:0;''><tr><td class=''copy'' style=''padding-top:0;padding-right:0;padding-left:0;vertical-align:top;padding-bottom:7px;text-align:left;''>'
						+ M.[body] +
						'</td></tr></table></td></tr></table></td></tr></table></center><center><div class=''spacer body-buffer'' style=''font-size:20px;line-height:30px;display:block;''>&nbsp;</div><p style=''Margin-top:0;font-weight:normal;color:#677483;font-family:sans-serif;font-size:14px;line-height:25px;Margin-bottom:15px;''>Metropolitan College of New York &middot; 60 West St &middot; New York, NY &middot; 10006 &middot; 212.343.1234</p><div class=''spacer body-buffer'' style=''font-size:20px;line-height:10px;display:block;''>&nbsp;</div></center></td></tr></table>'
					,1
					,NULL
					,M.[from]
					,M.[fromId]
					,0
					,@Now
					,'N'
					,'SYSADMIN'
					,'0001'
					,@Today
					,@Now
					,'SYSADMIN'
					,'0001'
					,@Today
					,@Now
					)
		OUTPUT M.[msKey], inserted.[MESSAGEID]
		INTO @MessageIds;

		--Associate MESSAGEIDs with #MessagesStrict
		UPDATE #MessagesStrict
		SET #MessagesStrict.[MESSAGEID] = MIDS.[MESSAGEID]
		FROM @MessageIds MIDS
		WHERE #MessagesStrict.[msKey] = MIDS.[msKey];

		ALTER TABLE #MessagesStrict ALTER COLUMN [MESSAGEID] INT NOT NULL; --A little extra validation

		--Insert [to] recipients into MESSAGERECIPIENTS
		INSERT INTO [MESSAGERECIPIENTS] (
			[MESSAGEID]
			,[RECIPIENTTYPE]
			,[EMAILADDRESS]
			,[PEOPLECODEID]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			)
		SELECT
			M.[MESSAGEID]
			,'to'
			,M.[to]
			,M.[toId]
			,'SYSADMIN'
			,'0001'
			,@Today
			,@Now
			,'SYSADMIN'
			,'0001'
			,@Today
			,@Now
		FROM #MessagesStrict M

		--Insert [cc] recipients into MESSAGERECIPIENTS
		INSERT INTO [MESSAGERECIPIENTS] (
			[MESSAGEID]
			,[RECIPIENTTYPE]
			,[EMAILADDRESS]
			,[PEOPLECODEID]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			)
		SELECT
			M.[MESSAGEID]
			,'cc'
			,M.[cc]
			,M.[ccId]
			,'SYSADMIN'
			,'0001'
			,@Today
			,@Now
			,'SYSADMIN'
			,'0001'
			,@Today
			,@Now
		FROM #MessagesStrict M
		WHERE M.[cc] IS NOT NULL

		--Insert [to] recipients into MESSAGERECIPIENTS
		INSERT INTO [MESSAGERECIPIENTS] (
			[MESSAGEID]
			,[RECIPIENTTYPE]
			,[EMAILADDRESS]
			,[PEOPLECODEID]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			)
		SELECT
			M.[MESSAGEID]
			,'bcc'
			,M.[bcc]
			,M.[bccId]
			,'SYSADMIN'
			,'0001'
			,@Today
			,@Now
			,'SYSADMIN'
			,'0001'
			,@Today
			,@Now
		FROM #MessagesStrict M
		WHERE M.[bcc] IS NOT NULL

		--Select the results as output
		SELECT
			[from]
			,[fromId]
			,[to]
			,[toId]
			,[toTypeFlag]
			,[cc]
			,[ccId]
			,[bcc]
			,[bccId]
			,[subject]
			,[body]
			,[formatBodyFlag]
			,[uniqueKey]
			,[MESSAGEID]
		FROM #MessagesStrict;

	COMMIT TRAN MCNY_SP_SendEmails
	
	DROP TABLE #MessagesIntermediate;

END
GO

