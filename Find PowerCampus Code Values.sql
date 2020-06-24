use Campus6;

-- Usage:
--		Finds instances of a particular code value (text string) by column name.
--		More info in Messages tab, or you can set SSMS to text output mode (Ctrl + T).
--
-- Example: Find all instances of 'CHE019' in column 'CURRICULUM'
--		DECLARE @SearchColumn nvarchar(100) = 'CURRICULUM';
--		DECLARE @SearchValue nvarchar(100) = 'CHE019';
--
-- History: 
-- 2019-09-11 Wyatt Best:	Wrote first version
-- 2019-09-12 Wyatt Best:	Added alternate output if nothing found.
-- 2020-06-24 Wyatt Best:	Added optional limit by ACADEMIC_YEAR and ACADEMIC_TERM.
--							Limited searches to [dbo] schema to prevent unexpected behavior.

DECLARE @SearchColumn NVARCHAR(100) = 'SECTION' --Column name
	,@SearchValue NVARCHAR(100) = 'DST1' --Code value to search for
	--Optional. If @AcademicYear and @AcademicTerm are not NULL, results will be limited in tables containing these columns.
	,@AcademicYear NVARCHAR(4) = '2020'
	,@AcademicTerm NVARCHAR(10) = 'FALL';


/*
NO NEED TO MODIFY ANYTHING BELOW THIS LINE
*/

DECLARE @TargetTable NVARCHAR(100)
	,@TargetColumn NVARCHAR(100)
	,@TableYTCols BIT
	,@TargetId UNIQUEIDENTIFIER
	,@TestSql NVARCHAR(max)
	,@Sql NVARCHAR(max)
	,@YTSql NVARCHAR(max)
	,@TestCount INT
	,@FoundCount INT;

--Build search list of tables containing the target column.
SELECT T1.TABLE_NAME
	,COLUMN_NAME
	,NEWID() AS ID
	,CASE 
		WHEN EXISTS (
				SELECT *
				FROM INFORMATION_SCHEMA.TABLES T2
				INNER JOIN INFORMATION_SCHEMA.COLUMNS C2
					ON C2.TABLE_NAME = T2.TABLE_NAME
						AND C2.TABLE_SCHEMA = T2.TABLE_SCHEMA
				WHERE T2.TABLE_NAME = T1.TABLE_NAME
					AND T2.TABLE_SCHEMA = 'dbo'
					AND T2.TABLE_TYPE = 'BASE TABLE'
					AND COLUMN_NAME IN ('ACADEMIC_YEAR', 'ACADEMIC_TERM')
					AND (
						@AcademicYear IS NOT NULL
						AND @AcademicTerm IS NOT NULL
						)
				)
			THEN 1
		ELSE 0
		END AS YTCols
INTO #ToSearch
FROM INFORMATION_SCHEMA.COLUMNS C1
INNER JOIN INFORMATION_SCHEMA.TABLES T1
	ON C1.TABLE_NAME = T1.TABLE_NAME
		AND C1.TABLE_SCHEMA = T1.TABLE_SCHEMA
		AND T1.TABLE_SCHEMA = 'dbo'
		AND T1.TABLE_TYPE = 'BASE TABLE'
WHERE COLUMN_NAME IN (@SearchColumn, 'CODE_VALUE_KEY')
	AND DATA_TYPE IN ('NVARCHAR', 'VARCHAR');




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
		,@TableYTCols = YTCols
	FROM #ToSearch;

	--WHERE clause for academic year and term
	IF (@TableYTCols = 1)
		SELECT @YTSql = ' AND ACADEMIC_YEAR = ''' + @AcademicYear + ''' AND ACADEMIC_TERM = ''' + @AcademicTerm + '''';
	ELSE
		SELECT @YTSql = '';

	--First check if search table contains target value
	SELECT @TestSql = 'SELECT @Cnt = COUNT(*) FROM ' + @TargetTable + ' WHERE ' + @TargetColumn + ' = ''' + @SearchValue + '''' + @YTSql;
	EXEC SP_EXECUTESQL @TestSql, N'@Cnt INT OUTPUT', @Cnt = @TestCount OUTPUT

	--If target value is found, return matching rows from table currently being searched
	IF (@TestCount > 0)
	BEGIN
		SELECT @Sql = 'SELECT * FROM ' + @TargetTable + ' WHERE ' + @TargetColumn + ' = ''' + @SearchValue + '''' + @YTSql;
		
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