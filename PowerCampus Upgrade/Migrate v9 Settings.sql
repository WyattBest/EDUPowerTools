use [master]
-- =============================================
-- Compatible with Self-Service 9.1.4 and possible higher.
--
-- Author:		Wyatt Best
-- Create date: 2021-07-02
-- Description:	Intended to copy settings from v9.1.2 test DB to v9.1.4 production DB.
--				Why? When upgrading from v8 to v9, institutions often want to copy settings from v9 test to v9 prod,
--				as your newly-upgraded prod DB will not contain any values for the new settings.
--				Copying directly saves a lot of clicking and time during the upgrade window.
--
--				You MUST update the database name vars and run in SQLCMD mode.
-- =============================================

:setvar pc_db_new "Campus6"
:setvar pc_db_old "Campus6_912"
:setvar identity_db_new "PowerCampusIdentity"
:setvar identity_db_old "PowerCampusIdentity_912"

USE $(pc_db_new)

--Copy custom sitemap roles
INSERT INTO SiteMapRole (
	RoleName
	,SortOrder
	,IsCustom
	)
SELECT RoleName
	,SortOrder
	,IsCustom
FROM $(pc_db_old).dbo.SiteMapRole SMO2
WHERE IsCustom = 1
	AND NOT EXISTS (
		SELECT *
		FROM SiteMapRole SMO
		WHERE SMO.RoleName = SMO2.RoleName
		)

--Copy custom sitemap options
INSERT INTO SiteMapOption (
	LinkId
	,ExternalLink
	,IsCustom
	)
SELECT LinkId
	,ExternalLink
	,IsCustom
FROM $(pc_db_old).dbo.SiteMapOption SMO2
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
FROM $(pc_db_old).dbo.SiteMapOptionDetail SMO2
WHERE IsCustom = 1
	AND NOT EXISTS (
		SELECT *
		FROM SiteMapOptionDetail SMO
		WHERE SMO.LinkId = SMO2.LinkId
		)

--Copy sitemap role options
INSERT INTO SiteMapOptionRole (
	SiteMapOptionId
	,SiteMapRoleId
	,IsVisible
	)
SELECT SMOR2.SiteMapOptionId
	,SMR.SiteMapRoleId
	,SMOR2.IsVisible
FROM $(pc_db_old).dbo.SiteMapOptionRole SMOR2
INNER JOIN SiteMapOption SMO2
	ON SMO2.SiteMapOptionId = SMOR2.SiteMapOptionId
INNER JOIN SiteMapRole SMR2
	ON SMR2.SiteMapRoleId = SMOR2.SiteMapRoleId
LEFT JOIN SiteMapOption SMO
	ON SMO.LinkId = SMO2.LinkId
LEFT JOIN SiteMapRole SMR
	ON SMR.RoleName = SMR2.RoleName
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

--Copy Theme and other instutition settings
MERGE dbo.InstitutionSetting AS myTarget
USING (
	SELECT AreaName
		,SectionName
		,LabelName
		,Setting
		,PersonId
	FROM $(pc_db_old).dbo.InstitutionSetting
	--Which settings to copy
	WHERE areaname IN ('Theme')
	) AS mySource
	ON mySource.AreaName = myTarget.AreaName
		AND mySource.SectionName = myTarget.SectionName
		AND mySource.LabelName = myTarget.LabelName
WHEN MATCHED
	THEN
		UPDATE
		SET Setting = mySource.Setting
			,RevisionDatetime = getdate()
			,PersonId = mySource.PersonId
WHEN NOT MATCHED
	THEN
		INSERT (
			AreaName
			,SectionName
			,LabelName
			,Setting
			,CreateDatetime
			,RevisionDatetime
			,PersonId
			)
		VALUES (
			AreaName
			,SectionName
			,LabelName
			,Setting
			,getdate()
			,getdate()
			,PersonId
			);

--Copy Roles and Claims in PowerCampus Identity database
USE [$(identity_db_new)]

DECLARE @ApplicationId INT = (
		SELECT Applicationid
		FROM auth.appcatalog
		WHERE [Name] = 'SelfService'
		)

INSERT INTO auth.AppRole (
	ApplicationId
	,[Name]
	)
SELECT @ApplicationId
	,AR2.[Name]
FROM [$(identity_db_old)].auth.AppRole AR2
INNER JOIN [$(identity_db_old)].auth.AppCatalog AC2
	ON AC2.ApplicationId = AR2.ApplicationId
		AND AC2.[Name] = 'SelfService'
WHERE NOT EXISTS (
		SELECT *
		FROM auth.AppRole AR
		WHERE AR.ApplicationId = @ApplicationId
			AND AR.[Name] = AR2.[Name]
		)

INSERT INTO auth.AppRoleClaim (
	AppRoleId
	,AppClaimId
	)
SELECT AR.AppRoleId
	,AC.AppClaimId
FROM [$(identity_db_old)].auth.AppRoleClaim ARC2
INNER JOIN [$(identity_db_old)].auth.AppRole AR2
	ON AR2.AppRoleId = ARC2.AppRoleId
INNER JOIN [$(identity_db_old)].auth.AppClaim AC2
	ON AC2.AppClaimId = ARC2.AppClaimId
LEFT JOIN auth.AppRole AR
	ON AR.[Name] = AR2.[Name]
LEFT JOIN auth.AppClaim AC
	ON AC.[Name] = AC2.[Name]
WHERE NOT EXISTS (
		SELECT *
		FROM auth.AppRoleClaim ARC
		INNER JOIN auth.AppClaim AC
			ON AC.AppClaimId = ARC.AppClaimId
		INNER JOIN auth.AppRole AR
			ON AR.AppRoleId = ARC.AppRoleId
		WHERE AR.[Name] = AR2.[Name]
			AND AC.[Name] = AC2.[Name]
		)
