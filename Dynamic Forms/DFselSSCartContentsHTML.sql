USE [Campus6]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-11-02
-- Description:	Selects Self-Service cart sections in HTML table format.
-- =============================================
CREATE PROCEDURE [custom].[DFselSSCartContentsHTML] @PCID NVARCHAR(10)
	,@AdvisorID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Adjust @PCID
	IF LEN(@PCID) = 9
		SET @PCID = 'P' + @PCID

	SELECT (
			'<style type="text/css">table.sections {
				width: 100%;
				border-width: 1px;
				border-color: #a5a5a5;
				border-collapse: collapse
			}

			table.sections th {
				border-width: 1px;
				border-style: solid;
				border-color: #a5a5a5;
				background-color: #dedede;
				text-align: left
			}

			table.sections td {
				border-width: 1px;
				border-style: solid;
				border-color: #a5a5a5;
				padding: 5px;
			}</style>' + (
				SELECT 'sections' AS [@class]
					,(
						SELECT 'Year / Term / Session' [th]
							,'EVENT_ID' [th]
							,'EVENT_SUB_TYPE' [th]
							,'SECTION' [th]
						FOR XML raw('tr')
							,ELEMENTS
							,TYPE
						) AS 'thead'
					,COALESCE((
							SELECT C.ACADEMIC_YEAR + ' / ' + C.ACADEMIC_TERM + ' / ' + C.ACADEMIC_SESSION [td]
								,C.EVENT_ID [td]
								,C.Event_Sub_Type [td]
								,C.SECTION [td]
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
							FOR XML RAW('tr')
								,ELEMENTS
								,TYPE
							), '<td>Nothing found. Perhaps the student is not your advisee?</td><td></td><td></td><td></td>') AS 'tbody'
				FOR XML PATH('table')
				)
			) AS [HTML]
END
