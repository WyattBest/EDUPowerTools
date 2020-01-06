-------------------------------------
--	2017-05-19, Wyatt Best, MCNY.edu
--	Fixes duplicate addresses caused by CR-000129768.
--	Cleans up misc duplicate addresses.
--	Runs sp to restore any records missing from ADDRESS.
--
--	Please run in test environment and consider whether you really want duplicates removed before running in production.
--	May not be effective if your collation is case-sensitive.
--
-- Update 2017-09-08 WB: Added COALESCE functions to address comparisons.
-- Update 2018-01-02 WB: Removed EMAIL_ADDRESS comparisons, since email addresses are no longer stored in this table. This causes many more duplicates to be detected.
--						Added version check.
--						Excluded recurring addresses.
--						Added MCNY-specific line to exclude 'EMAL' code type addresses.
-- Update 2019-12-11 WB: Updated PowerCampus version numbers. Defect is still unfixed.
-------------------------------------

USE Campus6
DECLARE @Rowcount INT

IF (SELECT
		CASE WHEN PARSENAME(SETTING,1) >= 0
			AND PARSENAME(SETTING,2) = 0
			AND PARSENAME(SETTING,3) = 9
			THEN 1 ELSE 0
		END AS VersionCheck
	FROM ABT_SETTINGS
	WHERE AREA_NAME = 'SYSADMIN'
		AND SECTION_NAME = 'DATABASE'
		AND LABEL_NAME = 'VERSION') = 1
	BEGIN
		BEGIN TRAN
			SELECT DISTINCT ADS.PEOPLE_ORG_CODE_ID
			FROM ADDRESSSCHEDULE ADS
				LEFT JOIN ADDRESS ADR ON ADR.PEOPLE_ORG_CODE_ID = ADS.PEOPLE_ORG_CODE_ID
					AND ADR.ADDRESS_TYPE = ADS.ADDRESS_TYPE
			WHERE ADS.STATUS = 'A'
				AND ADR.PEOPLE_ORG_CODE_ID IS NULL
			ORDER BY ADS.PEOPLE_ORG_CODE_ID

			PRINT 'Found ' + LTRIM(STR(@@ROWCOUNT)) + ' people with Active ADDRESSSCHEDULE records not in ADDRESS.';

			SELECT
				PEOPLE_ORG_CODE_ID
				,ADDRESS_TYPE
				,[START_DATE]
				,END_DATE
				,ADDRESS_LINE_1
				,ADDRESS_LINE_2
				,ADDRESS_LINE_3
				,ADDRESS_LINE_4
				,CITY
				,[STATE]
				,ZIP_CODE
				,COUNTRY
				,COUNTY
				--,EMAIL_ADDRESS
				,NO_MAIL
			INTO #GoodAddress
			FROM ADDRESSSCHEDULE AS1
			WHERE [STATUS] = 'A'
				AND EXISTS (SELECT *
							FROM ADDRESSSCHEDULE AS2
							WHERE AS2.PEOPLE_ORG_CODE_ID = AS1.PEOPLE_ORG_CODE_ID
								AND AS2.ADDRESS_TYPE = AS1.ADDRESS_TYPE
								AND COALESCE(AS2.ADDRESS_LINE_1,'') = COALESCE(AS1.ADDRESS_LINE_1,'')
								AND COALESCE(AS2.ADDRESS_LINE_2,'') = COALESCE(AS1.ADDRESS_LINE_2,'')
								AND COALESCE(AS2.ADDRESS_LINE_3,'') = COALESCE(AS1.ADDRESS_LINE_3,'')
								AND COALESCE(AS2.ADDRESS_LINE_4,'') = COALESCE(AS1.ADDRESS_LINE_4,'')
								AND COALESCE(AS2.CITY,'') = COALESCE(AS1.CITY,'')
								AND COALESCE(AS2.[STATE],'') = COALESCE(AS1.[STATE],'')
								AND COALESCE(AS2.ZIP_CODE,'') = COALESCE(AS1.ZIP_CODE,'')
								AND COALESCE(AS2.COUNTRY,'') = COALESCE(AS1.COUNTRY,'')
								AND COALESCE(AS2.COUNTY,'') = COALESCE(AS1.COUNTY,'')
								--AND COALESCE(AS2.EMAIL_ADDRESS,'') = COALESCE(AS1.EMAIL_ADDRESS,'')
								AND COALESCE(AS2.NO_MAIL,'') = COALESCE(AS1.NO_MAIL,'')
								AND AS2.[STATUS] = 'I'
								AND AS2.END_DATE = DATEADD(DAY,-1,AS1.START_DATE)
								--AND AS2.END_DATE < AS1.START_DATE
								AND AS1.ADDRESS_TYPE <> 'EMAL' --MCNY specific line to exclude historical Email-type addresses.
								AND AS1.RECURRING = 'N'
								)
				AND AS1.END_DATE IS NULL;

			SELECT * FROM #GoodAddress
			ORDER BY PEOPLE_ORG_CODE_ID

			--PRINT 'Found ' + LTRIM(STR(@@ROWCOUNT)) + ' duplicate addresses to roll back.';

			DELETE ADS
			FROM ADDRESSSCHEDULE ADS
				INNER JOIN #GoodAddress ON #GoodAddress.PEOPLE_ORG_CODE_ID = ADS.PEOPLE_ORG_CODE_ID
				AND ADS.[START_DATE] =  #GoodAddress.[START_DATE]
				AND ADS.END_DATE IS NULL
				AND COALESCE(ADS.ADDRESS_LINE_1,'') = COALESCE(#GoodAddress.ADDRESS_LINE_1,'')
				AND COALESCE(ADS.ADDRESS_LINE_2,'') = COALESCE(#GoodAddress.ADDRESS_LINE_2,'')
				AND COALESCE(ADS.ADDRESS_LINE_3,'') = COALESCE(#GoodAddress.ADDRESS_LINE_3,'')
				AND COALESCE(ADS.ADDRESS_LINE_4,'') = COALESCE(#GoodAddress.ADDRESS_LINE_4,'')
				AND COALESCE(ADS.CITY,'') = COALESCE(#GoodAddress.CITY,'')
				AND COALESCE(ADS.[STATE],'') = COALESCE(#GoodAddress.[STATE],'')
				AND COALESCE(ADS.ZIP_CODE,'') = COALESCE(#GoodAddress.ZIP_CODE,'')
				AND COALESCE(ADS.COUNTRY,'') = COALESCE(#GoodAddress.COUNTRY,'')
				AND COALESCE(ADS.COUNTY,'') = COALESCE(#GoodAddress.COUNTY,'')
				--AND COALESCE(ADS.EMAIL_ADDRESS,'') = COALESCE(#GoodAddress.EMAIL_ADDRESS,'')
				AND COALESCE(ADS.NO_MAIL,'') = COALESCE(#GoodAddress.NO_MAIL,'')
	
			PRINT 'Deleted ' + LTRIM(STR(@@ROWCOUNT)) + ' active addresses that duplicate previous addresses and have adjacent end and start dates.';
			PRINT 'These records were probably caused by CR-000129768.'
	
			--!! DANGER, WILL ROBINSON !!
			--Dedupe ADDRESSSCHEDULE. You might not want duplicates removed!
			--Needed because otherwise the next UPDATE  step might cause the triggers on ADDRESS to
			--violate ADDRESS_PK on ADDRESS by trying re-activate duplicate records.
			DELETE FROM ADDRESSSCHEDULE
			WHERE SEQUENCE_NO NOT IN (SELECT MIN(SEQUENCE_NO)
								FROM ADDRESSSCHEDULE
								GROUP BY
									PEOPLE_ORG_CODE_ID
									,ADDRESS_TYPE
									,END_DATE
									,ADDRESS_LINE_1
									,ADDRESS_LINE_2
									,ADDRESS_LINE_3
									,ADDRESS_LINE_4
									,CITY
									,[STATE]
									,ZIP_CODE
									,COUNTRY
									,COUNTY
									--,EMAIL_ADDRESS
									,NO_MAIL)
				AND [STATUS] = 'I'

			PRINT 'Deleted ' + LTRIM(STR(@@ROWCOUNT)) + ' duplicate, inactive addresses with identical end dates, keeping record with lowest (oldest) SEQUENCE_NO.'

			UPDATE ADDRESSSCHEDULE
			SET END_DATE = NULL
				,[STATUS] = 'A'
			FROM #GoodAddress
			WHERE ADDRESSSCHEDULE.PEOPLE_ORG_CODE_ID = #GoodAddress.PEOPLE_ORG_CODE_ID
				AND ADDRESSSCHEDULE.END_DATE = DATEADD(DAY,-1,#GoodAddress.[START_DATE])
				AND COALESCE(ADDRESSSCHEDULE.ADDRESS_LINE_1,'') = COALESCE(#GoodAddress.ADDRESS_LINE_1,'')
				AND COALESCE(ADDRESSSCHEDULE.ADDRESS_LINE_2,'') = COALESCE(#GoodAddress.ADDRESS_LINE_2,'')
				AND COALESCE(ADDRESSSCHEDULE.ADDRESS_LINE_3,'') = COALESCE(#GoodAddress.ADDRESS_LINE_3,'')
				AND COALESCE(ADDRESSSCHEDULE.ADDRESS_LINE_4,'') = COALESCE(#GoodAddress.ADDRESS_LINE_4,'')
				AND COALESCE(ADDRESSSCHEDULE.CITY,'') = COALESCE(#GoodAddress.CITY,'')
				AND COALESCE(ADDRESSSCHEDULE.[STATE],'') = COALESCE(#GoodAddress.[STATE],'')
				AND COALESCE(ADDRESSSCHEDULE.ZIP_CODE,'') = COALESCE(#GoodAddress.ZIP_CODE,'')
				AND COALESCE(ADDRESSSCHEDULE.COUNTRY,'') = COALESCE(#GoodAddress.COUNTRY,'')
				AND COALESCE(ADDRESSSCHEDULE.COUNTY,'') = COALESCE(#GoodAddress.COUNTY,'')
				--AND COALESCE(ADDRESSSCHEDULE.EMAIL_ADDRESS,'') = COALESCE(#GoodAddress.EMAIL_ADDRESS,'')
				AND COALESCE(ADDRESSSCHEDULE.NO_MAIL,'') = COALESCE(#GoodAddress.NO_MAIL,'')
	
			SET @Rowcount = @@ROWCOUNT
			PRINT 'Re-actived ' + LTRIM(STR(@Rowcount)) + ' old addresses to replace newer duplicates deleted in earlier step.';
			IF @Rowcount > 0
				PRINT 'You may find more results by running this script again.';

			SELECT DISTINCT ADS.PEOPLE_ORG_CODE_ID
			FROM ADDRESSSCHEDULE ADS
				LEFT JOIN ADDRESS ADR ON ADR.PEOPLE_ORG_CODE_ID = ADS.PEOPLE_ORG_CODE_ID
					AND ADR.ADDRESS_TYPE = ADS.ADDRESS_TYPE
			WHERE ADS.STATUS = 'A'
				AND ADR.PEOPLE_ORG_CODE_ID IS NULL
			ORDER BY ADS.PEOPLE_ORG_CODE_ID

			SET @Rowcount = @@ROWCOUNT
			PRINT 'Found ' + LTRIM(STR(@Rowcount)) + ' people with Active ADDRESSSCHEDULE records not in ADDRESS.';
	
			IF @Rowcount > 0
				BEGIN
					PRINT 'Executing Ellucian stored proc spAddrScheduledProcess to update ADDRESS table.'
					EXEC dbo.spAddrScheduledProcess

					SELECT DISTINCT ADS.PEOPLE_ORG_CODE_ID
					FROM ADDRESSSCHEDULE ADS
						LEFT JOIN ADDRESS ADR ON ADR.PEOPLE_ORG_CODE_ID = ADS.PEOPLE_ORG_CODE_ID
							AND ADR.ADDRESS_TYPE = ADS.ADDRESS_TYPE
					WHERE ADS.STATUS = 'A'
						AND ADR.PEOPLE_ORG_CODE_ID IS NULL
					ORDER BY ADS.PEOPLE_ORG_CODE_ID

					PRINT 'Found ' + LTRIM(STR(@@ROWCOUNT)) + ' people with Active ADDRESSSCHEDULE records not in ADDRESS.'
				END;
			ELSE
				PRINT 'Skipping stored proc to update ADDRESS table.'
	
			DROP TABLE #GoodAddress
			PRINT ''
		--ROLLBACK TRAN; PRINT 'Transaction rolled back. Please check output, then comment out this line.'
		COMMIT TRAN; PRINT 'Transaction committed.'
	END;
ELSE PRINT 'This script is only designed to work with PowerCampus version 9.0.x'