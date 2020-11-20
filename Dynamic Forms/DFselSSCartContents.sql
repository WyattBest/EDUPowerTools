USE [Campus6]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-11-02
-- Description:	Selects the contents of the Self-Service cart by student ID and advisor ID.
-- =============================================
CREATE PROCEDURE [custom].[DFselSSCartContents] @PCID NVARCHAR(10)
	,@AdvisorID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Adjust @PCID
	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID

	SELECT SectionId
		,C.EVENT_ID + ' / ' + C.Event_Sub_Type + ' / ' + C.SECTION [Desc]
	FROM vwsCartSection C
	INNER JOIN [custom].vwOrderedTerms OT
		ON OT.ACADEMIC_YEAR = C.ACADEMIC_YEAR
			AND OT.ACADEMIC_TERM = C.ACADEMIC_TERM
	OUTER APPLY (
		SELECT TOP 1 *
		FROM [custom].vwACADEMIC A
		WHERE 1 = 1
			AND A.PEOPLE_CODE_ID = C.PEOPLE_CODE_ID
			AND A.TermId <= OT.TermId
		ORDER BY A.TermId DESC
		) A
	WHERE 1 = 1
		AND C.PEOPLE_CODE_ID = @PCID
		AND A.ADVISOR = @AdvisorID
END
