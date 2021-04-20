USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselActionCodes]    Script Date: 2021-04-20 14:23:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-12-08
-- Description:	Returns Action definitions for a specific office (or all offices).
-- =============================================
CREATE PROCEDURE [custom].[DFselActionCodes] @Office NVARCHAR(10) = NULL
	,@Type NVARCHAR(6) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms has an annoying habit of passing blanks instead of nulls/omitting parameters
	IF @Office = ''
		SET @Office = NULL

	IF @Type = ''
		SET @Type = NULL

	SELECT ACTION_ID
		,ACTION_NAME
		,ACTION_NAME + ' (' + ACTION_ID + ')' [NameCode]
		,ACTION_ID + ' - ' + ACTION_NAME [CodeName]
		,OFFICE
		,[TYPE]
		,NOTE
	FROM [ACTION]
	WHERE (
			OFFICE = @Office
			OR @Office IS NULL
			)
		AND (
			[TYPE] = @Type
			OR @Type IS NULL
			)
		AND [STATUS] = 'A'
	ORDER BY ACTION_NAME
END
GO

