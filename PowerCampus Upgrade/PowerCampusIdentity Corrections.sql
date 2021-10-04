USE PowerCampusIdentity

BEGIN TRAN

--Correct username case
--Check ApplicationId first!
UPDATE AU
SET UserName = PU.UserName
	,LoweredUserName = LOWER(PU.UserName)
FROM auth.AppUser AU
INNER JOIN campus6.dbo.PersonUser PU
	ON PU.UserName = AU.UserName
WHERE ApplicationId = 2

--Set authentication mode for regular users
UPDATE auth.AppUser
SET AuthenticationAppStoreId = 3
WHERE ApplicationId = 2
	AND AuthenticationAppStoreId <> 3

--Clean up users not existing in Campus6
DELETE
FROM auth.AppUser
WHERE ApplicationId = 2
	AND UserName NOT IN (
		SELECT UserName
		FROM campus6.dbo.PersonUser
		)

ROLLBACK TRAN
