-- =============================================
-- Compatible with PowerCampus 9.1.4 and possible higher.
--
-- Author:		Wyatt Best
-- Create date: 2021-11-15
-- Description:	Restores a deleted Vista View from a database copy.
--				Will ONLY work on copies of the same database because it copies VIEW_ID without checking that it's available,
--				copies security OPID's without checking, etc.
--
--				To use, set the ViewID parameter.
-- =============================================

:setvar pc_db_new "Campus6"
:setvar pc_db_old "Campus6_2020YearEnd"

USE [$(pc_db_new)]
BEGIN TRAN Tran_CopyView

DECLARE @ViewID INT = '??' --Change me
DECLARE @ViewDBName NVARCHAR(30) = (
		SELECT VIEW_DB_NAME
		FROM $(pc_db_old).dbo.[VISTAVIEW]
		WHERE VIEW_ID = @ViewID
		)

INSERT INTO [dbo].[VISTAVIEW]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEW]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWCOLUMNS]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWCOLUMNS]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWCOMPUTES]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWCOMPUTES]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWCRITERIA]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWCRITERIA]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWGROUPS]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWGROUPS]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWJOIN]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWJOIN]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWJOINCRITERIA]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWJOINCRITERIA]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWSORT]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWSORT]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWSYNTAX]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWSYNTAX]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[VISTAVIEWTABLES]
SELECT * FROM $(pc_db_old).dbo.[VISTAVIEWTABLES]
WHERE VIEW_ID = @ViewID

INSERT INTO [dbo].[PBCATCOL]
SELECT * FROM $(pc_db_old).dbo.[PBCATCOL]
WHERE PBC_TNAM = @ViewDBName

INSERT INTO [dbo].[PBCATTBL]
SELECT * FROM $(pc_db_old).dbo.[PBCATTBL]
WHERE PBT_TNAM = @ViewDBName

INSERT INTO [dbo].[ABT_TABLES]
SELECT * FROM $(pc_db_old).dbo.[ABT_TABLES]
WHERE TABLE_NAME = @ViewDBName

--SYSTEM entry will be added automatically
INSERT INTO [dbo].[ABT_TABLESECURITY]
SELECT * FROM $(pc_db_old).dbo.[ABT_TABLESECURITY]
WHERE TABLE_NAME = @ViewDBName
	AND SECURITY_ID <>'SYSTEM'

COMMIT TRAN Tran_CopyView