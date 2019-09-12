
-- Usage:
--		Finds instances of a particular code value (text string) by column name.
--		More info in Messages tab, or you can set SSMS to text output mode (Ctrl + T).
--
-- Example: Find all instances of 'CHE019' in column 'CURRICULUM'
--		DECLARE @SearchColumn nvarchar(100) = 'CURRICULUM';
--		DECLARE @SearchValue nvarchar(100) = 'CHE019';
--
-- History: 
--		2019-09-11 Wyatt Best: Wrote first version
--		2019-09-12 Wyatt Best: Added alternate output if nothing found.

DECLARE @SearchColumn nvarchar(100) = 'CURRICULUM'; --Column name
DECLARE @SearchValue nvarchar(100) = 'CHE19'; --Code value to search for

/*
NO NEED TO MODIFY ANYTHING BELOW THIS LINE
*/

DECLARE @TargetTable NVARCHAR(100);
DECLARE @TargetColumn NVARCHAR(100);
DECLARE @TargetId UNIQUEIDENTIFIER;
DECLARE @TestSql nvarchar(max);
DECLARE @Sql nvarchar(max);
DECLARE @TestCount int;
DECLARE @FoundCount int;


--Build search list of tables containing the target column.
SELECT
	TAB.TABLE_NAME
	,COLUMN_NAME
	,NEWID() AS ID
INTO #ToSearch
FROM INFORMATION_SCHEMA.COLUMNS COL
	INNER JOIN INFORMATION_SCHEMA.TABLES TAB
		ON COL.TABLE_NAME = TAB.TABLE_NAME
		AND TAB.TABLE_TYPE = 'BASE TABLE'
WHERE COLUMN_NAME IN (@SearchColumn,'CODE_VALUE_KEY')
	AND DATA_TYPE IN ('NVARCHAR','VARCHAR');

CREATE TABLE #Results
	(
	TABLE_NAME NVARCHAR(100)
	,INSTANCES INT
	);

--Loop through search list
WHILE (SELECT COUNT(*) FROM #ToSearch) > 0
BEGIN
	--NOCOUNT is used most of the time to avoid cluttering up the results
	SET NOCOUNT ON;

	SELECT TOP 1 @TargetTable = TABLE_NAME
		,@TargetColumn = COLUMN_NAME
		,@TargetId = ID
	FROM #ToSearch;

	--First check if search table contains target value
	SELECT @TestSql = 'SELECT @Cnt = COUNT(*) FROM ' + @TargetTable + ' WHERE ' + @TargetColumn + ' = ''' + @SearchValue + '''' ;
	EXEC SP_EXECUTESQL @TestSql, N'@Cnt INT OUTPUT', @Cnt = @TestCount OUTPUT

	--If target value is found, return matching rows from table currently being searched
	IF (@TestCount > 0)
	BEGIN
		SELECT @Sql = 'SELECT * FROM ' + @TargetTable + ' WHERE ' + @TargetColumn + ' = ''' + @SearchValue + '''' ;
		
		PRINT @Sql;
		SET NOCOUNT OFF
		EXEC SP_EXECUTESQL @Sql;
		SELECT @FoundCount = @@ROWCOUNT;
		SET NOCOUNT ON

		--Log results for summary
		INSERT INTO #Results
		VALUES (@TargetTable, @FoundCount);

		PRINT '
			';
	END
	
	--Remove the table we just searched from the search list
	DELETE FROM #ToSearch
	WHERE ID = @TargetId;
END

--Summary
IF ((SELECT COUNT(*) FROM #Results) > 0)
	SELECT * FROM #Results
ELSE
	PRINT 'Nothing found.'

DROP TABLE #ToSearch, #Results;