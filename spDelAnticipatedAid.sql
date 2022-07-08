USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[spDelAnticipatedAid]    Script Date: 06/15/2022 11:40:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-12-06
-- Description:	Deletes all batches containing anticipated aid records.
--				Intended to be run before importing fresh anticipated aid.
--
-- 2022-06-15	Wyatt Best: Added ability to ignore a list of aid codes to accommodate manual loading from non-PowerFAIDS sources.
--							Such aid needs to be loaded in its own batch.
-- =============================================
CREATE PROCEDURE [custom].[spDelAnticipatedAid]
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN TranDelAnticipatedAid;

	DECLARE @IgnoredAidCodes TABLE (ChargeCreditCode NVARCHAR(10))

	INSERT INTO @IgnoredAidCodes
	VALUES ('AIDGTAPSP')
		,('AIDGTAPSU')
		,('AIDGTAPFA')

	BEGIN TRY
		DECLARE @BatchNumber NVARCHAR(20)
			,@Opid NVARCHAR(8) = 'SYSTEM'

		SELECT DISTINCT BATCH
		INTO #AnticBatches
		FROM CHARGECREDIT
		WHERE ANTICIPATED_FLAG = 'Y'
			AND CHARGE_CREDIT_CODE NOT IN (
				SELECT ChargeCreditCode
				FROM @IgnoredAidCodes
				)

		--Loop through all the batches with anticipated aid and delete them
		WHILE EXISTS (
				SELECT *
				FROM #AnticBatches
				)
		BEGIN
			SET @BatchNumber = (
					SELECT TOP 1 BATCH
					FROM #AnticBatches
					)

			--Error check that batch number contains only anticipated aid records
			IF EXISTS (
					SELECT *
					FROM CHARGECREDIT
					WHERE BATCH = @BatchNumber
						AND ANTICIPATED_FLAG = 'N'
					)
			BEGIN
				RAISERROR (
						'Batch %s contains CHARGECREDIT records that are not flagged anticipated. This procedure is only intended to delete anticipated aid batches.'
						,11
						,1
						,@BatchNumber
						)
			END

			--Error check that batch number contains no posted records
			IF EXISTS (
					SELECT *
					FROM CHARGECREDIT
					WHERE BATCH = @BatchNumber
						AND POSTED_FLAG = 'Y'
					)
			BEGIN
				RAISERROR (
						'Batch %s contains posted CHARGECREDIT records. Batches with posted records cannot be deleted.'
						,11
						,1
						,@BatchNumber
						)
			END

			--spDelChargeCreditTaxByBatch expects this temporay table as input
			CREATE TABLE #DeletedBatch (BatchNumber NVARCHAR(20) NOT NULL PRIMARY KEY)

			INSERT INTO #DeletedBatch (BatchNumber)
			VALUES (@BatchNumber)

			DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())

			--Delete taxes from ChargeCreditTax and CHARGECREDIT
			EXECUTE dbo.spDelChargeCreditTaxByBatch

			UPDATE BATCHHEADER
			SET BATCHHEADER.DELETED_FLAG = 'Y'
				,BATCHHEADER.DELETED_DATE = @Today
				,BATCHHEADER.DELETE_OPID = @Opid
			WHERE BATCHHEADER.BATCH_NUMBER = @BatchNumber
				AND BATCHHEADER.BATCH_TYPE = 'IMPORT'
				AND BATCHHEADER.TABLENAME = 'CHARGECREDIT'

			DELETE
			FROM InvoiceDetail
			WHERE InvoiceDetail.ChargeCreditNumber IN (
					SELECT CHARGECREDITNUMBER
					FROM CHARGECREDIT
					WHERE CHARGECREDIT.BATCH = @BatchNumber
					)

			DELETE
			FROM CHARGECREDIT
			WHERE BATCH = @BatchNumber

			DROP TABLE #DeletedBatch;

			DELETE
			FROM #AnticBatches
			WHERE BATCH = @BatchNumber
		END

		DROP TABLE #AnticBatches;
	END TRY

	BEGIN CATCH
		SELECT ERROR_NUMBER() AS ErrorNumber
			,ERROR_SEVERITY() AS ErrorSeverity
			,ERROR_STATE() AS ErrorState
			,ERROR_PROCEDURE() AS ErrorProcedure
			,ERROR_LINE() AS ErrorLine
			,ERROR_MESSAGE() AS ErrorMessage;

		IF @@TRANCOUNT > 0
			ROLLBACK TRAN TranDelAnticipatedAid;
	END CATCH;

	IF @@TRANCOUNT > 0
		COMMIT TRAN TranDelAnticipatedAid;
END
