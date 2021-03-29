USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spUpdatePhoneCountry]    Script Date: 2021-03-29 10:13:14 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-03-18
-- Description:	Correct country codes for phone numbers.
--
-- 2021-03-29 Wyatt Best:	Added feature to delete duplicate numbers.
-- =============================================
CREATE PROCEDURE [custom].[spUpdatePhoneCountry]
AS
BEGIN
	SET NOCOUNT ON;
	
	-----------------------------------
	--Delete duplicate phone numbers of the same type with different countries.
	-----------------------------------

	--Create temp table of duplicates
	SELECT PersonPhoneId
		,PersonId
		,Create_Date + Create_Time [Created] --Debug info
		,CountryId
		--Debug info
		,CASE WHEN PersonPhoneId IN (
					SELECT PrimaryPhoneId
					FROM PEOPLE P
					WHERE P.PersonId = PP.PersonId
					) THEN 1
			ELSE 0
			END AS IsPrimary
		--Rank the duplicates. Primary flag is always Rank 1, otherwise sort by create date.
		--We will preserve the Rank 1 phone number for each duplicate set.
		,RANK() OVER (
			PARTITION BY PersonId
			,PhoneType ORDER BY (
					CASE WHEN PersonPhoneId IN (
								SELECT PrimaryPhoneId
								FROM PEOPLE P
								WHERE P.PersonId = PP.PersonId
								) THEN 1
						ELSE 0
						END
					) DESC
				,Create_Date + Create_Time
			) AS [Rank]
	INTO #Dups
	FROM PersonPhone PP
	WHERE 1 = 1
		AND EXISTS (
			SELECT *
			FROM PersonPhone PP2
			WHERE 1 = 1
				AND PP2.PersonPhoneId <> PP.PersonPhoneId
				AND PP2.PersonId = PP.PersonId
				AND PP2.PhoneNumber = PP.PhoneNumber
				AND PP2.PhoneType = PP.PhoneType
				AND PP2.CountryId <> PP.CountryId
			)

	DECLARE @PhoneId INT

	DECLARE phone_cursor CURSOR FAST_FORWARD
	FOR SELECT PersonPhoneId
	FROM #Dups
	WHERE [Rank] > 1

	OPEN phone_cursor
	FETCH NEXT FROM phone_cursor INTO @PhoneId

	WHILE @@FETCH_STATUS = 0
	BEGIN
		--Use Ellucian's deletion procedure that updates history table
		EXEC dbo.spDelPersonPhone @PhoneId

		FETCH NEXT FROM phone_cursor INTO @PhoneId
	END

	CLOSE phone_cursor
	DEALLOCATE phone_cursor
	DROP TABLE #Dups

	-----------------------------------
	--Update phone number country codes from a table of dialing prefixes
	-----------------------------------
	UPDATE PP
	SET CountryId = DC.CountryId
	FROM PersonPhone PP
	INNER JOIN [custom].DialingCodes DC
		ON LEN(PP.PhoneNumber) = DC.NumberLength
			AND LEFT(PP.PhoneNumber, LEN(DC.Prefix)) = DC.Prefix
	WHERE PP.CountryId = 240

	-----------------------------------
	--Update a few that are too complex for the dialing prefix table
	-----------------------------------

	--Kazakhstan
	UPDATE PersonPhone
	SET CountryId = 122
	WHERE len(PhoneNumber) = 11
		AND left(PhoneNumber, 2) IN (
			'77'
			,'76'
			)
		AND CountryId = 240

	--Russia
	UPDATE PersonPhone
	SET CountryId = 190
	WHERE len(PhoneNumber) = 11
		AND LEFT(PhoneNumber, 1) = '7'
		AND LEFT(PhoneNumber, 2) NOT IN (
			'77'
			,'76'
			)
		AND CountryId = 240
END
GO

