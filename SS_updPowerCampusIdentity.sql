USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[SS_updPowerCampusIdentity]    Script Date: 2021-09-21 10:17:09 ******/
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
-- 2021-09-21 Wyatt Best:	Updated for 9.1.4. PowerCampusIdentity table names changed and many keys were changed to INT instead of UNIQUEIDENTIFIER.
-- =============================================
ALTER PROCEDURE [custom].[SS_updPowerCampusIdentity]
AS
BEGIN
	SET NOCOUNT ON;

	--=============================================================
	--Preliminary mappings from PowerCampus to PowerCampusIdentity
	--=============================================================
	DECLARE @ApplicationId INT = (
			SELECT ApplicationId
			FROM [PowerCampusIdentity].[auth].[Application]
			WHERE [Name] = '/PowerCAMPUS'
			)
	DECLARE @DossierRole INT = (
			SELECT AppRoleId
			FROM [PowerCampusIdentity].[auth].[AppRole]
			WHERE [Name] = 'MCNYDossier'
				AND ApplicationId = @ApplicationId
			)
	DECLARE @RegChangeRole INT = (
			SELECT AppRoleId
			FROM [PowerCampusIdentity].[auth].[APPROLE]
			WHERE [Name] = 'Registrar Change Approval'
				AND ApplicationId = @ApplicationId
			)
	DECLARE @CreationAppStoreId INT = (
			SELECT AppStoreId
			FROM [PowerCampusIdentity].[auth].[AppStore]
			WHERE ApplicationId = @ApplicationId
				AND [Mode] = 2 --Active Directory
				
			)
	DECLARE @AuthenticationAppStoreId INT = (
			SELECT AppStoreId
			FROM [PowerCampusIdentity].[auth].[AppStore]
			WHERE ApplicationId = @ApplicationId
				AND [Mode] = 3 --ADFS
			)

	--Map record types to PowerCampusIdentity roles according to SiteMapRole
	SELECT AppRoleId
		,CODE_VALUE_KEY [RECORDTYPE]
		--,SMR.RoleName						--Debug
	INTO #IdentityRoles
	FROM SiteMapRole SMR
	INNER JOIN PersonTypeRole PTR
		ON PTR.RoleName = SMR.RoleName
	INNER JOIN CODE_RECORDTYPE CRT
		ON CRT.RecordTypeId = PTR.PersonTypeId
	INNER JOIN [PowerCampusIdentity].[auth].[AppRole] aAR
		ON aAR.[Name] = SMR.RoleName
	WHERE ApplicationId = @ApplicationId

	--=============================================================
	--Calculate master table of the desired state.
	--=============================================================
	
	CREATE TABLE #UsersInRoles (
		UserName NVARCHAR(50) NULL
		,AppUserId INT
		,AppRoleId INT
		);
	
	--Match PowerCampus users to Self-Service users based on username
	--Match roles to record types mapped in #IdentityRoles
	INSERT INTO #UsersInRoles
	SELECT
		PU.UserName
		,aAU.AppUserId
		,IR.AppRoleId
		--,PU.PersonId						--Debug
		--,P.PEOPLE_CODE_ID					--Debug
		--,PT.PEOPLE_TYPE [PT.PEOPLE_TYPE]	--Debug
		--,IR.RECORDTYPE [IR.RECORDTYPE]		--Debug
		--,IR.RoleName [IR.RoleName]			--Debug
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
	LEFT JOIN [PowerCampusIdentity].[auth].[AppUser] aAU
		ON aAU.UserName = PU.UserName

	--Add in dossier role for operators based on SS_D_Permissions
	INSERT INTO #UsersInRoles
	SELECT DISTINCT PU.UserName
		,aAU.AppUserId
		,@DossierRole
	FROM ABT_USERPROFILE AUP
	--INNER JOIN [Campus6_suppMCNY].[dbo].[SS_D_Permissions] DPerm
	--	ON DPerm.PROFILE_CODE = AUP.PROFILE_CODE
	INNER JOIN ABT_USERS AU
		ON AUP.OPERATOR_ID = AU.OPERATOR_ID
			AND AU.[STATUS] = 'A'
	INNER JOIN PEOPLE P
		ON AU.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
	INNER JOIN PersonUser PU
		ON P.PersonId = PU.PersonId
	LEFT JOIN [PowerCampusIdentity].[auth].[AppUser] aAU
		ON aAU.UserName = PU.UserName
	
	--Add in Registrar Change Approval role based on operator profiles
	INSERT INTO #UsersInRoles
	SELECT DISTINCT PU.UserName
		,aAU.AppUserId
		,@RegChangeRole
	FROM ABT_USERPROFILE AUP
	INNER JOIN ABT_USERS AU
		ON AUP.OPERATOR_ID = AU.OPERATOR_ID
			AND AU.[STATUS] = 'A'
	INNER JOIN PEOPLE P
		ON AU.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
	INNER JOIN PersonUser PU
		ON P.PersonId = PU.PersonId
	LEFT JOIN [PowerCampusIdentity].[auth].[AppUser] aAU
		ON aAU.UserName = PU.UserName
	WHERE AUP.PROFILE_CODE IN ('REGSTAFF', 'REGISTRAR')

	--Add back in non-federated users, such as SiteAdministrator
	INSERT INTO #UsersInRoles (
		AppUserId
		,AppRoleId
		)
	SELECT aAUR.AppRoleId
		,aAUR.AppRoleId
	FROM [PowerCampusIdentity].[auth].[AppUser] aAU
	INNER JOIN [PowerCampusIdentity].[auth].[AppUserRole] aAUR
		ON aAU.AppUserId = aAUR.AppUserId
	WHERE aAU.[Password] <> ''

	--=============================================================
	--Insert/delete users from PowerCampusIdentity
	--=============================================================
	
	--Debug: select the users we will delete
	SELECT 'DELETE' [Action]
		,aAU.UserName
		,aAU.AppUserId
	FROM [PowerCampusIdentity].[auth].[AppUser] aAU
	LEFT JOIN PersonUser PU
		ON PU.UserName = aAU.UserName
	WHERE PU.UserName IS NULL
		AND [Password] = '' --Only federated users
		AND ApplicationId = @ApplicationId

	--Delete users not in PowerCampus
	DELETE aAU
	FROM [PowerCampusIdentity].[auth].[AppUser] aAU
	LEFT JOIN PersonUser PU
		ON PU.UserName = aAU.UserName
	WHERE PU.UserName IS NULL
		AND [Password] = '' --Only federated users
		AND ApplicationId = @ApplicationId

	--Isolate users not in PowerCampusIdentity and create new UserId's
	;WITH NewUsers_CTE
	AS (
		SELECT DISTINCT UIR.UserName
			,AppUserId
			,E.Email
		FROM #UsersInRoles UIR
		LEFT JOIN [PersonUser] PU
			ON PU.UserName = UIR.UserName
		LEFT JOIN PEOPLE P
			ON P.PersonId = PU.PersonId
		LEFT JOIN EmailAddress E
			ON E.EmailAddressId = P.PrimaryEmailId
		WHERE AppUserId IS NULL
		)
	SELECT UserName
		,Email
	INTO #NewUsers
	FROM NewUsers_CTE
	

	--Debug: Select the users we will insert
	SELECT 'INSERT' [Action]
		,*
	FROM #NewUsers

	--Insert new users into PowerCampusIdentity
	INSERT INTO [PowerCampusIdentity].[auth].[AppUser] (
		[ApplicationId]
		,[UserName]
		,[LoweredUserName]
		,[Email]
		,[LoweredEmail]
		,[Password]
		,[ChangePasswordAtNextLogon]
		,[CreationAppStoreId]
		,[AuthenticationAppStoreId]
		)
	SELECT @ApplicationId
		,UserName
		,LOWER(UserName)
		,Email
		,''
		,''
		,0
		,@CreationAppStoreId
		,@AuthenticationAppStoreId
	FROM #NewUsers;

	--Update master list with new UserId's we just inserted
	UPDATE UIR
	SET UIR.AppUserId = aAU.AppUserId
	FROM #UsersInRoles UIR
	INNER JOIN #NewUsers NU
		ON NU.UserName = UIR.UserName
	INNER JOIN [PowerCampusIdentity].[auth].[AppUser] aAU
		ON aAU.UserName = NU.UserName
	WHERE UIR.AppUserId IS NULL;

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
		,AppUserId INT
		,AppRoleId INT
		);
	
	--Make the actual auth.IdentityUserRole table match our calculated users-in-roles table
	MERGE [PowerCampusIdentity].[auth].[AppUserRole] WITH (HOLDLOCK) AS T
	USING (
			SELECT DISTINCT * FROM #UsersInRoles
			) S
	ON S.AppUserId = T.AppUserId
		AND S.AppRoleId = T.AppRoleId
	WHEN NOT MATCHED BY TARGET
	THEN INSERT (AppUserId, AppRoleId)
		VALUES (S.AppUserId, S.AppRoleId)
	WHEN NOT MATCHED BY SOURCE
		AND T.AppRoleId IN (SELECT AppRoleId FROM #IdentityRoles) --Only edit roles that have record type mappings
	THEN DELETE
	OUTPUT
		$action AS [Action]
		,COALESCE(inserted.AppUserId, deleted.AppUserId) AS AppUserId
		,COALESCE(inserted.AppRoleId, deleted.AppRoleId) AS AppRoleId
		INTO #Changes;
	
	--Output for debugging
	SELECT C.*
		,aAU.UserName
		,aAR.[Name] [Role Name]
		,P.PEOPLE_ID
	FROM #Changes C
	LEFT JOIN [PowerCampusIdentity].[auth].[AppUser] aAU
		ON aAU.AppUserId = C.AppUserId
	LEFT JOIN [PowerCampusIdentity].[auth].[AppRole] aAR
		ON aAR.AppRoleId = C.AppRoleId
	LEFT JOIN PersonUser PU
		ON PU.UserName = aAU.UserName
	LEFT JOIN PEOPLE P
		ON P.PersonId = PU.PersonId;

	DROP TABLE #IdentityRoles
		,#UsersInRoles
		,#Changes

END
