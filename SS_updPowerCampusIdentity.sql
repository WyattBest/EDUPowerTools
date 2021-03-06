USE [Campus6]
GO
/****** Object:  StoredProcedure [custom].[SS_updPowerCampusIdentity]    Script Date: 2020-06-18 15:03:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Wyatt Best
-- Create date: 2019-10-25
--
-- Description:	Updates IdentityUser and IdentityUserRole table in PowerCampusIdentity database.
--				Typically, Self-Service roles are mapped at login time based on Record Types. However, we wish to use Operator permissions and other data points for setting permissions and to delete clean up old users not in PersonUser.
--				We also have custom Self-Service roles used for our custom Dossier.
--				Users:
--					Inserts users into auth.IdentityUser from PersonUser as long as they have at least one role.
--					Deletes users from auth.IdentityUser if they can't be found in PersonUser.
--				Roles:
--					Maps Self-Service roles to PowerCampus record types as well as to select operator profiles.
--					Custom Dossier profiles are joined from [Campus6_suppMCNY].[dbo].[SS_D_Permissions].
--
-- 2019-11-08 Wyatt Best:	Added functionality to also sync auth.IdentityUser table and renamed from custom.SS_updIdentityRoles to custom.SS_updPowerCampusIdentity
-- 2019-11-22 Wyatt Best:	Added DISTINCT in final merge statement to cover cases when Dossier rights are added from two different sources.
-- 2019-12-19 Wyatt Best:	Added IdentityUserStoreId column for new user insert; this is new in 9.0.2
-- =============================================

CREATE PROCEDURE [custom].[SS_updPowerCampusIdentity]
AS
BEGIN
	SET NOCOUNT ON;

	--=============================================================
	--Preliminary mappings from PowerCampus to PowerCampusIdentity
	--=============================================================
	DECLARE @ApplicationId UNIQUEIDENTIFIER = (
			SELECT ApplicationId
			FROM [PowerCampusIdentity].[auth].[IdentityApplication]
			WHERE ApplicationName = '/PowerCAMPUS'
			)
	DECLARE @DossierRole UNIQUEIDENTIFIER = (
			SELECT RoleId
			FROM [PowerCampusIdentity].[auth].[IdentityRole]
			WHERE RoleName = 'MCNYDossier'
			)
	DECLARE @RegChangeRole UNIQUEIDENTIFIER = (
			SELECT RoleId
			FROM [PowerCampusIdentity].[auth].[IdentityRole]
			WHERE RoleName = 'Registrar Change Approval'
			)
	DECLARE @IdentityUserStoreId INT = 3 --New users will be created with this UserStore from [auth].[IdentityUserStore]


	--Map record types to PowerCampusIdentity roles according to SiteMapRole
	SELECT RoleId
		,CODE_VALUE_KEY [RECORDTYPE]
	INTO #IdentityRoles
	FROM SiteMapRole SMR
	INNER JOIN PersonTypeRole PTR
		ON PTR.RoleName = SMR.RoleName
	INNER JOIN CODE_RECORDTYPE CRT
		ON CRT.RecordTypeId = PTR.PersonTypeId
	INNER JOIN [PowerCampusIdentity].[auth].[IdentityRole] aIR
		ON aIR.RoleName = SMR.RoleName
	WHERE ApplicationId = @ApplicationId

	--=============================================================
	--Calculate master table of the desired state.
	--=============================================================
	
	CREATE TABLE #UsersInRoles (
		UserName NVARCHAR(50) NULL
		,UserId UNIQUEIDENTIFIER
		,RoleId UNIQUEIDENTIFIER
		);
	
	--Match PowerCampus users to Self-Service users based on username
	--Match roles to record types mapped in #IdentityRoles
	INSERT INTO #UsersInRoles
	SELECT
		PU.UserName
		,aIU.UserId
		,IR.RoleId
		--PU.PersonId						--Debug
		--,P.PEOPLE_CODE_ID					--Debug
		--,PT.PEOPLE_TYPE [PT.PEOPLE_TYPE]	--Debug
		--,IR.RECORDTYPE [IR.RECORDTYPE]	--Debug
		--,IR.RoleName [IR.RoleName],		--Debug
	FROM PersonUser PU
	INNER JOIN PEOPLE P
		ON P.PersonId = PU.PersonId
	INNER JOIN PEOPLETYPE PT
		ON PT.PEOPLE_ID = P.PEOPLE_ID
	INNER JOIN CODE_RECORDTYPE CRT
		ON CRT.CODE_VALUE_KEY = PT.PEOPLE_TYPE
			AND CRT.[STATUS] = 'A'
	INNER JOIN #IdentityRoles IR
		ON IR.RECORDTYPE = PT.PEOPLE_TYPE
	LEFT JOIN [PowerCampusIdentity].[auth].[IdentityUser] aIU
		ON aIU.UserName = PU.UserName

	--Add in dossier role for operators based on SS_D_Permissions
	INSERT INTO #UsersInRoles
	SELECT DISTINCT PU.UserName
		,UserId
		,@DossierRole
	FROM ABT_USERPROFILE AUP
	INNER JOIN [Campus6_suppMCNY].[dbo].[SS_D_Permissions] DPerm
		ON DPerm.PROFILE_CODE = AUP.PROFILE_CODE
	INNER JOIN ABT_USERS AU
		ON AUP.OPERATOR_ID = AU.OPERATOR_ID
			AND AU.[STATUS] = 'A'
	INNER JOIN PEOPLE P
		ON AU.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
	INNER JOIN PersonUser PU
		ON P.PersonId = PU.PersonId
	LEFT JOIN [PowerCampusIdentity].[auth].[IdentityUser] aIU
		ON aIU.UserName = PU.UserName
	
	--Add in Registrar Change Approval role based on operator profiles
	INSERT INTO #UsersInRoles
	SELECT DISTINCT  PU.UserName
		,UserId
		,@RegChangeRole
	FROM ABT_USERPROFILE AUP
	INNER JOIN ABT_USERS AU
		ON AUP.OPERATOR_ID = AU.OPERATOR_ID
			AND AU.[STATUS] = 'A'
	INNER JOIN PEOPLE P
		ON AU.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
	INNER JOIN PersonUser PU
		ON P.PersonId = PU.PersonId
	LEFT JOIN [PowerCampusIdentity].[auth].[IdentityUser] aIU
		ON aIU.UserName = PU.UserName
	WHERE AUP.PROFILE_CODE IN ('REGSTAFF', 'REGISTRAR')

	--Add back in non-federated users, such as SiteAdministrator
	INSERT INTO #UsersInRoles (
		UserId
		,RoleId
		)
	SELECT aIUR.UserId
		,aIUR.RoleId
	FROM [PowerCampusIdentity].[auth].[IdentityUser] aIU
	INNER JOIN [PowerCampusIdentity].[auth].[IdentityUserRole] aIUR
		ON aIU.UserId = aIUR.UserId
	WHERE aIU.[Password] <> ''

	--=============================================================
	--Insert/delete users from PowerCampusIdentity
	--=============================================================
	
	--Debug: select the users we will delete
	--SELECT 'DELETE' [Action]
	--	,aIU.UserName
	--	,UserId
	--FROM [PowerCampusIdentity].[auth].[IdentityUser] aIU
	--LEFT JOIN PersonUser PU
	--	ON PU.UserName = aIU.UserName
	--WHERE PU.UserName IS NULL
	--	AND [Password] = '' --Only federated users

	--Delete users not in PowerCampus
	DELETE aIU
	FROM [PowerCampusIdentity].[auth].[IdentityUser] aIU
	LEFT JOIN PersonUser PU
		ON PU.UserName = aIU.UserName
	WHERE PU.UserName IS NULL
		AND [Password] = '' --Only federated users

	--Isolate users not in PowerCampusIdentity and create new UserId's
	;WITH NewUsers_CTE
	AS (
		SELECT DISTINCT UserName
		FROM #UsersInRoles
		WHERE UserId IS NULL
		)
	SELECT UserName
		,NEWID() [UserId]
	INTO #NewUsers
	FROM NewUsers_CTE

	--Debug: Select the users we will insert
	--SELECT 'INSERT' [Action]
	--	,*
	--FROM #NewUsers

	--Insert new users into PowerCampusIdentity
	INSERT INTO [PowerCampusIdentity].[auth].[IdentityUser] (
		[ApplicationId]
		,[UserId]
		,[UserName]
		,[LoweredUserName]
		,[Email]
		,[LoweredEmail]
		,[Password]
		,[LastLoginDate]
		,[LastPasswordChangedDate]
		,[LastLockoutDate]
		,[IdentityUserStoreId]
		)
	SELECT @ApplicationId
		,UserId
		,UserName
		,LOWER(UserName)
		,''
		,''
		,''
		,NULL
		,NULL
		,NULL
		,@IdentityUserStoreId
	FROM #NewUsers;

	--Update master list with new UserId's we just inserted
	UPDATE UIR
	SET UIR.UserId = NU.UserId
	FROM #UsersInRoles UIR
	INNER JOIN #NewUsers NU
		ON NU.UserName = UIR.UserName
	WHERE UIR.UserId IS NULL;

	DROP TABLE #NewUsers;

	--=============================================================
	--Insert/delete roles from PowerCampusIdentity
	--=============================================================
	--Mutate the temp table for slight speed gain
	ALTER TABLE #UsersInRoles
	DROP COLUMN UserName;
	
	--Temp table to hold output
	CREATE TABLE #Changes (
		[Action] NVARCHAR(10)
		,UserId UNIQUEIDENTIFIER
		,RoleId UNIQUEIDENTIFIER
		);
	
	--Make the actual auth.IdentityUserRole table match our calculated users-in-roles table
	MERGE [PowerCampusIdentity].[auth].[IdentityUserRole] WITH (HOLDLOCK) AS T
	USING (
			SELECT DISTINCT * FROM #UsersInRoles
			) S
	ON S.UserId = T.UserId
		AND S.RoleId = T.RoleId
	WHEN NOT MATCHED BY TARGET
	THEN INSERT (UserId, RoleId)
		VALUES (S.UserId, S.RoleId)
	WHEN NOT MATCHED BY SOURCE
		AND T.RoleId IN (SELECT RoleId FROM #IdentityRoles) --Only edit roles that have record type mappings
	THEN DELETE
	OUTPUT
		$action AS [Action]
		,COALESCE(inserted.UserId, deleted.UserId) AS UserId
		,COALESCE(inserted.RoleId, deleted.RoleId) AS RoleId
		INTO #Changes;
	
	--Output for debugging
	--SELECT C.*
	--	,aIU.UserName
	--	,aIR.RoleName
	--	,P.PEOPLE_ID
	--FROM #Changes C
	--LEFT JOIN [PowerCampusIdentity].[auth].[IdentityUser] aIU
	--	ON aIU.UserId = C.UserId
	--LEFT JOIN [PowerCampusIdentity].[auth].[IdentityRole] aIR
	--	ON aIR.RoleId = C.RoleId
	--LEFT JOIN PersonUser PU
	--	ON PU.UserName = aIU.UserName
	--LEFT JOIN PEOPLE P
	--	ON P.PersonId = PU.PersonId;

	DROP TABLE #IdentityRoles
		,#UsersInRoles
		,#Changes

END
