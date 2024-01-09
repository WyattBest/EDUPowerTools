USE PowerCampusIdentity_test

-- =============================================
-- Compatible with Self-Service 9.2.3 and possible higher.
--
-- Author:		Wyatt Best
-- Create date: 2021-07-02
-- Description:	Grants a role (selected by name) all permissions in Self-Service.
--				This is specifically useful for testing; nobody wants to see all this stuff in real life.
--
-- 2024-01-09 Wyatt Best:	Tested with 9.2.3 and cleaned up a little.
-- =============================================
DECLARE @SuperRoleName NVARCHAR(255) = 'Administrator'
	,@ApplicationId INT = 2
DECLARE @SuperRoleId INT = (
		SELECT AppRoleId
		FROM auth.AppRole
		WHERE [Name] = @SuperRoleName
			AND ApplicationId = @ApplicationId
		);

SELECT @SuperRoleId [@SuperRoleId];

INSERT INTO auth.AppRoleClaim (
	AppRoleId
	,AppClaimId
	)
SELECT @SuperRoleId
	,AppClaimId
FROM auth.AppClaim AC
WHERE 1 = 1
	AND ApplicationId = @ApplicationId
	AND NOT EXISTS (
		SELECT *
		FROM auth.AppRoleClaim ARC
		WHERE AppRoleId = @SuperRoleId
			AND AC.AppClaimId = ARC.AppClaimId
			AND ApplicationId = @ApplicationId
		);

USE CAMPUS6

SET @SuperRoleId = (
		SELECT SiteMapRoleId
		FROM SiteMapRole
		WHERE RoleName = @SuperRoleName
		);

SELECT @SuperRoleId [@SuperRoleId];

INSERT INTO SiteMapOptionRole (
	SiteMapOptionId
	,SiteMapRoleId
	,IsVisible
	)
SELECT SiteMapOptionId
	,@SuperRoleId
	,1
FROM SiteMapOption SMO
WHERE NOT EXISTS (
		SELECT *
		FROM SiteMapOptionRole SMOR
		WHERE SiteMapRoleId = @SuperRoleId
			AND SMOR.SiteMapOptionId = SMO.sitemapoptionid
		);

INSERT INTO SiteMapOptionDetailRole(
	SiteMapOptionDetailId
	,SiteMapRoleId
	,IsVisible
	)
SELECT SiteMapOptionDetailId
	,@SuperRoleId
	,1
FROM SiteMapOptionDetail SMO
WHERE NOT EXISTS (
		SELECT *
		FROM SiteMapOptionDetailRole SMOR
		WHERE SiteMapRoleId = @SuperRoleId
			AND SMOR.SiteMapOptionDetailId = SMO.SiteMapOptionDetailId
		);
