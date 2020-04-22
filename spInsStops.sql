USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE Procedure [custom].[spInsStops]
	@procName nvarchar(100) = NULL
	,@OPID nvarchar(8) = 'Back'
	,@Comments nvarchar(max) = NULL
AS
SET NOCOUNT ON
/***********************************************************************
Description: Inserts stops and logs changes to support DB. Prints the number of stops inserted.
	Duplicate stops will be ignored, and the rest will be placed.
	Inactive stop codes will be ignored, and the rest will be placed.
	Existing, cleared stops from same day will be un-cleared.
	
Parameters:
	@procName - @@PROCID of calling procedure. This is helpful when troubleshooting the support DB log.
	@OPID - Null allowed. This is REVISION_OPID. Defaults to 'Back' for back office.
	@Comments - Recommend NULL. Defaults to appending 'Cleared by System Administrator [DATETIME]' to existing comment.
	#STOPS_TO_ADD - a temporary table that must already exist and should contain columns (PEOPLE_CODE_ID, STOP_REASON)

Usage: Temporary table #STOPS_TO_ADD must already exist. Can be called manually or from other sp_'s.
	EXECUTE [custom].spInsStops 'Manual', 'WBEST', 'Summer 2016 Bursar Hold'
	EXEC MCNY_SP_InsertStop

Revision History:
	2016-06-21	Wyatt Best - Created based off of MCNY_SP_ClearStops
	2016-07-05	Wyatt Best - Added check against PEOPLE. Cleaned up code a little; replaced some extra getdate()s with vars.
	2016-10-21	Wyatt Best - Added method for un-clearing existing, cleared stops for the same day due to PK constraint for PCID, STOP_REASON, STOP_DATE.
	2018-09-05  Michael Geiz - Added comments
	2020-02-28	Wyatt Best - Renamed from dbo.MCNY_SP_InsertStops to [custom].spInsStops
	2020-03-17	Wyatt Best - Tweaked error handling to only attempt rollback of @@trancount > 0.

Usage example
Import data into [Campus6_suppMCNY].[dbo].[tmp_add_Stop]  table

SELECT  --  *
     [PEOPLE_CODE_ID] as PEOPLE_CODE_ID
         ,STOP_REASON as STOP_REASON
  FROM [Campus6_suppMCNY].[dbo].[tmp_add_Stop] 

Run script
SELECT  rtrim([PEOPLE_CODE_ID]) as PEOPLE_CODE_ID
         ,rtrim(STOP_REASON) as STOP_REASON
      INTO #STOPS_TO_ADD
  FROM [Campus6_suppMCNY].[dbo].[tmp_add_Stop] 
  
--  No comments   exec [custom].spInsStops
EXECUTE [custom].spInsStops 'Manual', 'MGeiz', 'Financial Aid Suspended – Not Making SAP'


-- Select * from  #STOPS_TO_ADD
  --drop table #STOPS_TO_ADD 
-- drop table [Campus6_suppMCNY].[dbo].[tmp_add_Stop]

************************************************************************/

BEGIN
	BEGIN TRY
		DECLARE @datetime	datetime
		DECLARE @today		datetime
		DECLARE @now		datetime
		DECLARE @datestring	nvarchar(12)

		SET @datetime = getdate()
		SET @today = dbo.fnMakeDate(@datetime)
		SET @now = dbo.fnMakeTime(@datetime)
		SET @datestring = CONVERT(nvarchar,@datetime,107)

		SELECT PEOPLE_CODE_ID FROM #STOPS_TO_ADD WHERE LEN(PEOPLE_CODE_ID) <> 10
		IF @@rowcount > 0
			BEGIN RAISERROR ('PEOPLE_CODE_ID must be 10 characters long', 16, 1) END

		SELECT PEOPLE_CODE_ID FROM #STOPS_TO_ADD WHERE SUBSTRING(PEOPLE_CODE_ID,1,1) <> 'P'
		IF @@rowcount > 0
			BEGIN RAISERROR ('PEOPLE_CODE_ID incorrectly formatted', 16, 1) END				

		IF @Comments IS NULL OR @Comments = ''
			SET @Comments = 'Added by System Administrator ' + @datestring
		ELSE
			SET @Comments = @Comments + CHAR(13) + CHAR(10) + 'Added by System Administrator ' + @datestring

		IF @procName IS NULL OR @procName = ''
			BEGIN SET @procName = OBJECT_NAME(@@PROCID) END

		--PRINT @COMMENTS --Dev
		--PRINT @procName --Dev

		--Dedupe, clean, and find new stops to place.
		SELECT DISTINCT
			sta.PEOPLE_CODE_ID
			,sta.STOP_REASON
		INTO #STOPS_TO_ADD_2
		FROM #STOPS_TO_ADD sta
		LEFT JOIN dbo.[STOPLIST] sl ON sta.PEOPLE_CODE_ID = sl.PEOPLE_CODE_ID
			AND sta.STOP_REASON = sl.STOP_REASON
			AND (sl.CLEARED = 'N' --Ignore any existing, uncleared stops
				OR (sl.CLEARED = 'Y' --Ignore existing, cleared stops with same date
					AND sl.STOP_DATE = @today))
		INNER JOIN CODE_STOPLIST csl ON sta.STOP_REASON = csl.CODE_VALUE_KEY -- Only real stop codes
			AND csl.STATUS <> 'I' --Ignore inactive stop codes
		INNER JOIN PEOPLE p ON sta.PEOPLE_CODE_ID = p.PEOPLE_CODE_ID --Ignore any incorrect PEOPLE_CODE_ID's
		WHERE sl.PEOPLE_CODE_ID IS NULL

		--Depude, clean, and find cleared stops with same STOP_DATE to be un-cleared
		SELECT DISTINCT
			sta.PEOPLE_CODE_ID
			,sta.STOP_REASON
		INTO #STOPS_TO_ADD_3
		FROM #STOPS_TO_ADD sta
		INNER JOIN dbo.[STOPLIST] sl ON sta.PEOPLE_CODE_ID = sl.PEOPLE_CODE_ID
			AND sta.STOP_REASON = sl.STOP_REASON
			AND sl.CLEARED = 'Y'
			AND sl.STOP_DATE = @today
		INNER JOIN CODE_STOPLIST csl ON sta.STOP_REASON = csl.CODE_VALUE_KEY -- Only real stop codes
			AND csl.STATUS <> 'I' --Ignore inactive stop codes
		INNER JOIN PEOPLE p ON sta.PEOPLE_CODE_ID = p.PEOPLE_CODE_ID --Ignore any incorrect PEOPLE_CODE_ID's

		BEGIN TRANSACTION [Tran_InsStops]

			--Log changes for new stops
			INSERT INTO [Campus6_suppMCNY].[dbo].[STOPLIST_update_log]
				(PEOPLE_CODE_ID
				,PROCESS
				,CURRENT_CLEARED
				,NEW_CLEARED
				,CURRENT_COMMENTS
				,NEW_COMMENTS
				,UpdateDate
				,STOP_REASON
				,STOP_DATE)
			SELECT
				sta2.PEOPLE_CODE_ID
				,@procName
				,NULL
				,'N'
				,NULL
				,@Comments
				,@datetime
				,sta2.STOP_REASON
				,@today
			FROM #STOPS_TO_ADD_2 sta2

			--Insert New Stops
			INSERT INTO dbo.[STOPLIST]
				(PEOPLE_CODE
				,PEOPLE_ID
				,PEOPLE_CODE_ID
				,STOP_REASON
				,STOP_DATE
				,CLEARED
				,CLEARED_DATE
				,COMMENTS
				,CREATE_DATE
				,CREATE_TIME
				,CREATE_OPID
				,CREATE_TERMINAL
				,REVISION_DATE
				,REVISION_TIME
				,REVISION_OPID
				,REVISION_TERMINAL
				,ABT_JOIN)
			SELECT
				SUBSTRING(sta2.PEOPLE_CODE_ID,1,1)
				,SUBSTRING(sta2.PEOPLE_CODE_ID,2,9)
				,sta2.PEOPLE_CODE_ID
				,sta2.STOP_REASON
				,@today
				,CLEARED = 'N'
				,NULL
				,@Comments
				,@today
				,@now
				,@OPID
				,'0001'
				,@today
				,@now
				,@OPID
				,'0001'
				,'*'
			FROM #STOPS_TO_ADD_2 sta2

			PRINT CAST(@@ROWCOUNT AS varchar) + ' stop(s) inserted'

			--Log changes for un-cleared stops
			INSERT INTO [Campus6_suppMCNY].[dbo].[STOPLIST_update_log]
					(PEOPLE_CODE_ID
					,PROCESS
					,CURRENT_CLEARED
					,NEW_CLEARED
					,CURRENT_COMMENTS
					,NEW_COMMENTS
					,UpdateDate
					,STOP_REASON
					,STOP_DATE)
			SELECT
				sta3.PEOPLE_CODE_ID
				,@procName
				,sl.CLEARED
				,'N'
				,sl.COMMENTS
				,CASE WHEN LEN(COALESCE(sl.COMMENTS,'')) > 0 THEN sl.COMMENTS + CHAR(13)+CHAR(10) + @Comments ELSE @Comments END --Append linebreak and new comment if there's an existing comment, else just new comment.
				,@datetime
				,sta3.STOP_REASON
				,sl.STOP_DATE
			FROM #STOPS_TO_ADD_3 sta3
			INNER JOIN dbo.[STOPLIST] sl ON sl.PEOPLE_CODE_ID = sta3.PEOPLE_CODE_ID
				AND sl.STOP_REASON = sta3.STOP_REASON
				AND sl.CLEARED = 'Y'
				AND sl.STOP_DATE = @today
			
			--Un-clear existing stops with same STOP_DATE
			UPDATE dbo.[STOPLIST]
			SET CLEARED = 'N'
				,COMMENTS = CASE WHEN LEN(COALESCE(sl.COMMENTS,'')) > 0 THEN sl.COMMENTS + CHAR(13)+CHAR(10) + @Comments ELSE @Comments END --Append linebreak and new comment if there's an existing comment, else just new comment.
				,CLEARED_DATE = NULL
				,REVISION_DATE = @today
				,REVISION_TIME = @now
				,REVISION_OPID = @OPID
				,REVISION_TERMINAL = '0001'
			FROM #STOPS_TO_ADD_3 sta3
			INNER JOIN dbo.[STOPLIST] sl ON sl.PEOPLE_CODE_ID = sta3.PEOPLE_CODE_ID
				AND sl.STOP_REASON = sta3.STOP_REASON
				AND sl.CLEARED = 'Y'
				AND sl.STOP_DATE = @today

			PRINT CAST(@@ROWCOUNT AS varchar) + ' stop(s) un-cleared'

		COMMIT TRANSACTION [Tran1]
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
		BEGIN
			ROLLBACK TRANSACTION [Tran_InsStops]
			PRINT 'Error detected. Transaction [Tran_InsStops] rolled back.'
		END
			
		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		SELECT
			@ErrorMessage = ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();

		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);  
	END CATCH
END

GO
