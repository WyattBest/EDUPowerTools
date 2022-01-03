-- =============================================
-- Author:		Wyatt Best
-- Create date: 2022-01-03
-- Description:	Update ABT_OBJECTS with missing help links.
--
-- Can we insert new rows into ABT_OBJECTS? For example, d_ff_code_actionstatus for index.html#c_action_status.html
-- =============================================
DECLARE @Opid NVARCHAR(8) = 'WBEST'
	,@Today DATETIME = dbo.fnmakedate(getdate())
	,@Now DATETIME = dbo.fnmaketime(getdate())

BEGIN TRAN

UPDATE ABT_OBJECTS
SET HELP_NAME = 'index.html#c_donor_processing.html'
	,REVISION_DATE = @Today
	,REVISION_TIME = @Now
	,REVISION_OPID = @Opid
WHERE [OBJECT_NAME] = 'w_s_donor_processing'
	AND (
		HELP_NAME IS NULL
		OR HELP_NAME = ''
		)

ROLLBACK TRAN
