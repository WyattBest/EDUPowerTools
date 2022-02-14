USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[DFselCourseCatalog]    Script Date: 02/14/2022 15:53:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Archange Malvoisin
-- Create date: 2021-07-20
-- Description:	Returns MCNY Course Catalog.


-- =============================================
CREATE PROCEDURE [custom].[DFselCourseCatalog] 
AS	
BEGIN
	
	SET NOCOUNT ON;
SELECT EVENT_ID + ' - ' + PUBLICATION_NAME_1 AS CourseName
FROM [EVENT]
WHERE PUBLICATION_NAME_1 <> ''
	AND EVENT_STATUS = 'A'
ORDER BY EVENT_ID

END
GO

