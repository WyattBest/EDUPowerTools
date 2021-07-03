USE Campus6

-- =============================================
-- Compatible with Self-Service 9.1.4 and possible higher.
--
-- Author:		Wyatt Best
-- Create date: 2021-07-02
-- Description:	Intended to copy settings from v9.1.2 test DB to v9.1.4 production DB.
--
--				Before upgrading from v8 to v9, you'll probably configure a v9 test env. During the prod upgrade, you will wish to
--				copy settings from your v9 test DB, as your upgraded DB won't contain any of the new settings.
-- =============================================
--Set sheet background color
EXEC spInsUpdAbtSettings 'SYSADMIN'
	,'BACKGROUND'
	,'GRID_BACKGROUND_1'
	,'12632256'
	,0
	,'WBEST'
	,'SQL'

--Set sheet background color
EXEC spInsUpdAbtSettings 'SYSADMIN'
	,'BACKGROUND'
	,'GRID_BACKGROUND_2'
	,'13429452'
	,0
	,'WBEST'
	,'SQL'

--Enable integrated security
EXEC spInsUpdAbtSettings 'SYSADMIN'
	,'LOGON'
	,'SECURITY_MODE'
	,'Integrated'
	,0
	,'WBEST'
	,'SQL'

--Copy domain name code value from test
IF NOT EXISTS (
		SELECT *
		FROM CODE_DOMAIN
		)
	INSERT INTO CODE_DOMAIN
	SELECT *
	FROM Campus6_912.dbo.CODE_DOMAIN

--Set domain name on all operator profiles
UPDATE ABT_USERS
SET DOMAIN = (
		SELECT TOP 1 CODE_VALUE_KEY
		FROM CODE_DOMAIN
		)
WHERE DOMAIN IS NULL

--Copy sitemap external links
INSERT INTO SiteMapOption (
	LinkId
	,ExternalLink
	,IsCustom
	)
SELECT LinkId
	,ExternalLink
	,IsCustom
FROM Campus6_912.dbo.SiteMapOption SMO2
WHERE IsCustom = 1
	AND NOT EXISTS (
		SELECT *
		FROM SiteMapOption SMO
		WHERE smo.LinkId = SMO2.LinkId
		)

INSERT INTO SiteMapOptionDetail (
	SiteMapOptionId
	,LinkId
	,ExternalLink
	,IsCustom
	)
SELECT SiteMapOptionId
	,LinkId
	,ExternalLink
	,IsCustom
FROM Campus6_912.dbo.SiteMapOptionDetail SMO2
WHERE IsCustom = 1
	AND NOT EXISTS (
		SELECT *
		FROM SiteMapOptionDetail SMO
		WHERE SMO.LinkId = SMO2.LinkId
		)

/*
--Copy sitemap roles in PowerCampusIdentity
USE POWERCAMPUSIDENTITy

DECLARE @ApplicationId INT = (
		SELECT Applicationid
		FROM auth.[Application]
		WHERE [Name] = '/PowerCAMPUS'
		)

INSERT INTO AUTH.APPROLE (
	APPLICATIONID
	,[Name]
	)
SELECT applicationid
	,name
FROM powercampusidentity.AUTH.APPROLE AR2
WHERE applicationid = @applicationid
	AND NOT EXISTS (
		SELECT *
		FROM AUTH.APPROLE AR
		WHERE AR.applicationid = @applicationid
			AND
		)
*/
--Copy sitemap roles in Campus6
INSERT INTO SiteMapRole (
	RoleName
	,SortOrder
	,IsCustom
	)
SELECT RoleName
	,SortOrder
	,IsCustom
FROM Campus6_912.dbo.SiteMapRole SMO2
WHERE IsCustom = 1
	AND NOT EXISTS (
		SELECT *
		FROM SiteMapRole SMO
		WHERE SMO.RoleName = SMO2.RoleName
		)

BEGIN TRAN

--Copy sitemap role options
INSERT INTO SiteMapOptionRole (
	SiteMapOptionId
	,SiteMapRoleId
	,IsVisible
	)
SELECT SMOR2.SiteMapOptionId
	,SMOR.SiteMapRoleId
	,SMOR.IsVisible
FROM Campus6_912.dbo.SiteMapOptionRole SMOR2
INNER JOIN SiteMapOption SMO
	ON SMO2.SiteMapOptionId = SMOR2.SiteMapOptionId
INNER JOIN SiteMapRole SMR2
	ON SMR2.SiteMapRoleId = SMOR2.SiteMapRoleId
LEFT JOIN SITEMAPOPTION SMO
	ON SMO.LINKID = SMO2.LINKID
LEFT JOIN SITEMAPROLE SMR
	ON SMR.ROLENAME = SMR2.ROLENAME
WHERE NOT EXISTS (
		SELECT *
		FROM SiteMapOptionRole SMOR
		INNER JOIN SiteMapOption SMO
			ON SMO.SiteMapOptionId = SMOR.SiteMapOptionId
		INNER JOIN SiteMapRole SMR
			ON SMR.SiteMapRoleId = SMOR.SiteMapRoleId
		WHERE SMR.RoleName = SMR2.RoleName
			AND SMO.LinkId = SMO2.LinkId
		)

SELECT *
FROM SiteMapOptionRole SMOR
INNER JOIN SiteMapOption SMO
	ON SMO.SiteMapOptionId = SMOR.SiteMapOptionId
INNER JOIN SiteMapRole SMR
	ON SMR.SiteMapRoleId = SMOR.SiteMapRoleId
