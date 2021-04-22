USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselCodeValues]    Script Date: 2021-04-22 11:49:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-09-01
-- Description:	Selects from certain code tables. If @CodeValueKey is blank, all values are returned.
--				Feel free to add more tables.
--
-- 2021-04-21 Wyatt Best:	Added CODE_XVAL
-- =============================================
CREATE PROCEDURE [custom].[DFselCodeValues] @CodeTableName VARCHAR(50)
	,@CodeValueKey nvarchar(10) = NULL
	,@CodeXVAL nvarchar(10) = NULL

AS
BEGIN
	SET NOCOUNT ON;

	--Dynamic Forms submits blanks instead of null.
	IF @CodeValueKey = ''
		SET @CodeValueKey = NULL

	IF @CodeXVAL = ''
		SET @CodeXVAL = NULL

	IF @CodeTableName = 'CODE_COLLEGE'
		SELECT CODE_VALUE_KEY, SHORT_DESC, MEDIUM_DESC, LONG_DESC, CODE_XVAL
		FROM CODE_COLLEGE
		WHERE (CODE_VALUE_KEY = @CodeValueKey OR @CodeValueKey IS NULL) AND (CODE_XVAL = @CodeXVAL OR @CodeXVAL IS NULL OR CODE_XVAL = '') AND [STATUS] = 'A'
	
	IF @CodeTableName = 'CODE_CURRICULUM'
		SELECT CODE_VALUE_KEY, SHORT_DESC, MEDIUM_DESC, LONG_DESC, CODE_XVAL
		FROM CODE_CURRICULUM
		WHERE (CODE_VALUE_KEY = @CodeValueKey OR @CodeValueKey IS NULL) AND (CODE_XVAL = @CodeXVAL OR @CodeXVAL IS NULL OR CODE_XVAL = '') AND [STATUS] = 'A'

	IF @CodeTableName = 'CODE_SALUTATION'
		SELECT CODE_VALUE_KEY, SHORT_DESC, MEDIUM_DESC, LONG_DESC, CODE_XVAL
		FROM CODE_SALUTATION
		WHERE (CODE_VALUE_KEY = @CodeValueKey OR @CodeValueKey IS NULL) AND (CODE_XVAL = @CodeXVAL OR @CodeXVAL IS NULL OR CODE_XVAL = '') AND [STATUS] = 'A'
	
	IF @CodeTableName = 'CODE_PREFIX'
		SELECT CODE_VALUE_KEY, SHORT_DESC, MEDIUM_DESC, LONG_DESC, CODE_XVAL
		FROM CODE_PREFIX
		WHERE (CODE_VALUE_KEY = @CodeValueKey OR @CodeValueKey IS NULL) AND (CODE_XVAL = @CodeXVAL OR @CodeXVAL IS NULL OR CODE_XVAL = '') AND [STATUS] = 'A'

	IF @CodeTableName = 'CODE_CANCELREASON'
		SELECT CODE_VALUE_KEY, SHORT_DESC, MEDIUM_DESC, LONG_DESC, CODE_XVAL
		FROM CODE_CANCELREASON
		WHERE (CODE_VALUE_KEY = @CodeValueKey OR @CodeValueKey IS NULL) AND (CODE_XVAL = @CodeXVAL OR @CodeXVAL IS NULL OR CODE_XVAL = '') AND [STATUS] = 'A'

END
GO

