USE [Campus6]
GO

/****** Object:  View [dbo].[VWUEMAILADDRESSTOP]    Script Date: 2022-10-25 05:41:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[VWUEMAILADDRESSTOP] AS 
SELECT
       Prim.PEOPLE_ORG_CODE_ID
	   ,PrimaryEmail
       ,AlternateEmail
FROM
	(SELECT
			COALESCE(PEOPLE_CODE_ID, ORG_CODE_ID) AS PEOPLE_ORG_CODE_ID
			,E.Email AS [PrimaryEmail]
		FROM EmailAddress E
			LEFT JOIN PEOPLE P
				ON P.PEOPLE_CODE_ID = E.PeopleOrgCodeId
				AND P.PrimaryEmailId = E.EmailAddressId
			LEFT JOIN ORGANIZATION O
				ON O.ORG_CODE_ID = E.PeopleOrgCodeId
				AND O.PrimaryEmailId = E.EmailAddressId
		WHERE (PEOPLE_CODE_ID IS NOT NULL
				OR ORG_CODE_ID IS NOT NULL)) AS Prim
LEFT JOIN
    (SELECT
            PeopleOrgCodeId AS [PEOPLE_ORG_CODE_ID]
            ,Email AS AlternateEmail
            ,RANK() OVER (PARTITION BY PeopleOrgId ORDER BY CREATE_DATE DESC, CREATE_TIME DESC, Email) AS [EmailRank]
    FROM EmailAddress
    WHERE IsActive = '1'
            AND EmailType = 'Personal'
			) AS Alt
		ON Alt.PEOPLE_ORG_CODE_ID = Prim.PEOPLE_ORG_CODE_ID
WHERE (EmailRank = 1
	OR EmailRank IS NULL)
GO

