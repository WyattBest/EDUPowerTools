USE [Campus6]
GO
/****** Object:  StoredProcedure [custom].[DFselStudentSectionsEnrolled]    Script Date: 2021-11-19 15:57:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-12-08
-- Description:	List of courses student is/was enrolled in. Includes faculty contact info.
--				@TermOffset can look backwards or forwards. 0=current term, -1=previous term, etc.
--
-- 2021-11-18 Wyatt Best:		Renamed and added fnValidatePeopleID().
-- 2021-11-19 Wyatt Best:		Added column [EventId+Section+LongName]
-- =============================================
CREATE PROCEDURE [custom].[DFselStudentSectionsEnrolled] @StudentPCID NVARCHAR(10)
	,@TermOffset INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	--Fix PCID
	SET @StudentPCID = [custom].fnValidatePeopleID(@StudentPCID);

	DECLARE @CurTermId INT = (
			SELECT TermId
			FROM [custom].vwOrderedTerms
			WHERE ACADEMIC_YEAR = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_YEAR')
				AND ACADEMIC_TERM = dbo.fnGetAbtSetting('ACA_RECORDS', 'CURRENT_YT', 'CURRENT_TERM')
			)

	SELECT TD.TranscriptDetailId
		,TD.ACADEMIC_YEAR
		,TD.ACADEMIC_TERM
		,TD.EVENT_ID + ' / ' + TD.EVENT_MED_NAME [EventId+Med]
		,TD.EVENT_ID + ' / ' + TD.EVENT_LONG_NAME [EventId+Long]
		,TD.EVENT_ID + ' / ' + TD.SECTION + ': ' + EVENT_LONG_NAME  [EventId+Section+LongName]
		,TD.EVENT_ID
		,TD.SECTION
		,TD.EVENT_MED_NAME
		,TD.EVENT_LONG_NAME
		,dbo.fnPeopleOrgName(oFAC.PERSON_CODE_ID, 'PX |DN |LP |LN, |SX ') [FacultyName]
		,oFAC.PERSON_CODE_ID [FacultyID]
		,FE.PrimaryEmail [FacultyEmail]
	FROM [custom].vwACADEMIC A
	LEFT JOIN TRANSCRIPTDETAIL TD
		ON TD.PEOPLE_ID = A.PEOPLE_ID
			AND TD.ACADEMIC_YEAR = A.ACADEMIC_YEAR
			AND TD.ACADEMIC_TERM = A.ACADEMIC_TERM
			AND TD.ACADEMIC_SESSION = A.ACADEMIC_SESSION
			AND TD.ADD_DROP_WAIT = 'A'
	OUTER APPLY (
		SELECT TOP 1 *
		FROM SECTIONPER FAC
		WHERE FAC.ACADEMIC_YEAR = A.ACADEMIC_YEAR
			AND FAC.ACADEMIC_TERM = A.ACADEMIC_TERM
			AND FAC.ACADEMIC_SESSION = A.ACADEMIC_SESSION
			AND FAC.EVENT_ID = TD.EVENT_ID
			AND FAC.EVENT_SUB_TYPE = TD.EVENT_SUB_TYPE
			AND FAC.SECTION = TD.SECTION
		) oFAC
	LEFT JOIN VWUEMAILADDRESSTOP FE
		ON FE.PEOPLE_ORG_CODE_ID = oFAC.PERSON_CODE_ID
	WHERE 1 = 1
		AND A.PEOPLE_CODE_ID = @StudentPCID
		AND A.TermId = (@CurTermId + @TermOffset)
		AND A.[STATUS] <> 'N'
		AND A.ENROLL_SEPARATION = 'ENRL'
END
