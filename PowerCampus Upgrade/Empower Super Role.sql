USE PowerCampusIdentity

-- =============================================
-- Compatible with Self-Service 9.1.4 and possible higher.
--
-- Author:		Wyatt Best
-- Create date: 2021-07-02
-- Description:	Grants a role (selected by name) all permissions in Self-Service.
--				This is specifically useful for testing; nobody wants to see all this stuff in real life.
--				Compatible with Self-Service 9.1.4 and possible higher.
-- =============================================
DECLARE @SuperRoleName NVARCHAR(255) = 'All Access Testing'
DECLARE @SuperRoleId INT = (
		SELECT AppRoleid
		FROM AUTH.AppRole
		WHERE [Name] = 'All Access Testing'
		)

--SELECT @SuperRoleId [@SuperRoleId]
INSERT INTO AUTH.AppRoleCLAIM (
	AppRoleId
	,AppClaimId
	)
SELECT @SuperRoleId
	,AppClaimId
FROM auth.AppClaim AC
WHERE NOT EXISTS (
		SELECT *
		FROM auth.AppRoleClaim ARC
		WHERE AppRoleId = @SuperRoleId
			AND AC.AppClaimId = ARC.AppClaimId
		)

USE CAMPUS6

SET @SuperRoleId = (
		SELECT sitemaproleid
		FROM sitemaprole
		WHERE rolename = @superrolename
		)

--SELECT @SuperRoleId [@SuperRoleId]
INSERT INTO SiteMapOptionRole (
	sitemapoptionid
	,sitemaproleid
	,isvisible
	)
SELECT sitemapoptionid
	,@SuperRoleId
	,1
FROM sitemapoption SMO
WHERE NOT EXISTS (
		SELECT *
		FROM sitemapoptionrole SMOR
		WHERE sitemaproleid = @SuperRoleId
			AND SMOR.sitemapoptionid = SMO.sitemapoptionid
		)

INSERT INTO SiteMapOptiondetailRole (
	sitemapoptiondetailid
	,sitemaproleid
	,isvisible
	)
SELECT sitemapoptiondetailid
	,@SuperRoleId
	,1
FROM sitemapoptiondetail SMO
WHERE NOT EXISTS (
		SELECT *
		FROM sitemapoptiondetailrole SMOR
		WHERE sitemaproleid = @SuperRoleId
			AND SMOR.sitemapoptiondetailid = SMO.sitemapoptiondetailid
		)
