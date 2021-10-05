USE PowerCampusIdentity

BEGIN TRAN

--BE SURE TO REVIEW THESE VALUES!
DECLARE @ApplicationId INT = (
		SELECT Applicationid
		FROM auth.AppCatalog
		WHERE [Name] = 'SelfService'
		)
DECLARE @ADStoreId INT = (
		SELECT AppStoreId
		FROM auth.AppStore
		WHERE ApplicationId = @ApplicationId
			AND Mode = 2
		)
	,@ADFSStoreId INT = (
		SELECT AppStoreId
		FROM auth.AppStore
		WHERE ApplicationId = @ApplicationId
			AND Mode = 3
		)

--Correct username case
UPDATE AU
SET UserName = PU.UserName
	,LoweredUserName = LOWER(PU.UserName)
FROM auth.AppUser AU
INNER JOIN campus6.dbo.PersonUser PU
	ON PU.UserName = AU.UserName
WHERE ApplicationId = @ApplicationId

--Set authentication and creation mode mode for regular users
UPDATE auth.AppUser
SET AuthenticationAppStoreId = @ADFSStoreId
	,CreationAppStoreId = @ADStoreId
WHERE ApplicationId = 2
	AND (
		coalesce(AuthenticationAppStoreId, '') <> @ADFSStoreId
		OR coalesce(CreationAppStoreId, '') <> @ADStoreId
		)

--Clean up users not existing in Campus6
DELETE
FROM auth.AppUser
WHERE ApplicationId = @ApplicationId
	AND UserName NOT IN (
		SELECT UserName
		FROM Campus6.dbo.PersonUser
		)

ROLLBACK TRAN
