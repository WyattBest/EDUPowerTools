SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Create table for logging deletions
-- =============================================
CREATE TABLE [custom].[Log_VISTAVIEW_Deletion] (
	[VIEW_ID] INT NOT NULL
	,[VIEW_NAME] NVARCHAR(50) NOT NULL
	,[VIEW_DB_NAME] NVARCHAR(30) NOT NULL
	,[DESCRIPTION] NVARCHAR(255) NOT NULL
	,[SYNTAX_ALTERED] NVARCHAR(1) NOT NULL
	,[IS_DISTINCT] NVARCHAR(1) NOT NULL
	,[DateDeleted] DATETIME NOT NULL
	,[Database] NVARCHAR(50) NOT NULL
	);
GO

-- =============================================
-- Author:		Wyatt Best, based on script by Deepali Savkoor (https://ecommunities.ellucian.com/thread/1946)
-- Create date: 2017-10-31
-- Description:	Drops a Vista View from database and removes associated metadata from various tables.
--				Accepts either the view DB name as input. @ConfirmDelProtectedView must be set to 1 in order to
--				delete views with ID's > 9999.
-- =============================================
CREATE PROCEDURE [custom].[spDelVistaView] @viewDbName NVARCHAR(30)
	,@ConfirmDelProtectedView INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql NVARCHAR(max)
	DECLARE @viewId INT

	SELECT @viewId = VIEW_ID
	FROM VISTAVIEW
	WHERE VIEW_DB_NAME = @viewDbName;

	IF (COALESCE(@viewId, 0) = 0)
	BEGIN
		PRINT 'Cannot find the Vista View ' + COALESCE(@viewDbName, '') + '. Nothing to do.'

		RETURN
	END;

	IF (
			@viewId > 9999
			AND @ConfirmDelProtectedView <> 1
			)
	BEGIN
		PRINT 'Will not delete views with ID over 9999 without confirmation flag. These are protected.'

		RETURN
	END;

	BEGIN TRY
		BEGIN TRAN [Tran1]

		--Log deletion
		INSERT INTO [custom].[Log_VISTAVIEW_Deletion]
		SELECT [VIEW_ID]
			,[VIEW_NAME]
			,[VIEW_DB_NAME]
			,[DESCRIPTION]
			,[SYNTAX_ALTERED]
			,[IS_DISTINCT]
			,GETDATE() AS [DateDeleted]
			,DB_NAME() AS [Database]
		FROM VISTAVIEW
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWSYNTAX
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWSORT
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWGROUPS
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWCRITERIA
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWCOMPUTES
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWCOLUMNS
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWJOIN
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM VISTAVIEWJOINCRITERIA
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEWTABLES
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM dbo.VISTAVIEW
		WHERE VIEW_ID = @viewId;

		DELETE
		FROM PBCATCOL
		WHERE PBC_TNAM = @viewDbName;

		DELETE
		FROM PBCATTBL
		WHERE PBT_TNAM = @viewDbName;

		DELETE
		FROM ABT_TABLES
		WHERE TABLE_NAME = @viewDbName;

		SET @sql = 'drop view ' + @viewDbName;

		EXEC sp_executesql @sql;

		COMMIT TRAN [Tran1]

		PRINT @viewDbName + ' has been deleted.'
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION [Tran1]

		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE();

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				);
	END CATCH
END
GO


