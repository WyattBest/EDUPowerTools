USE [Campus6]
GO

--Use extreme caution and test, test, test! This script comes with no warranty!

--Some schools weren't able to update to PowerCampus 8.8.4 in time for the 2018 tax year 1098-T forms; they chose to run the process in upgraded database copies instead.
--This script brings that data back into the main database. Ellucian recommends re-running the process instead of copying with SQL, but there are various scenarios in which that isn't possible.
--Replace 'OtherDB' with the name of the isolated database contianing 1098-T information.

--The second half of this file is various comparison queries to try and validate the imported data. 

BEGIN TRAN;

--========== Copy the data ==========
--Select the last run for each student in tax year 2018
WITH CTE_1098T
AS (
	SELECT *
		,RANK() OVER (
			PARTITION BY PEOPLE_CODE_ID ORDER BY ReportedInformationId DESC
			) AS [RANK]
	FROM OtherDB.[dbo].[Reported1098TInformation]
	WHERE TaxYear = 2018
	)
SELECT ReportedInformationId
INTO #ImportList
FROM CTE_1098T
WHERE [RANK] = 1;

--Insert into various tables
SET IDENTITY_INSERT [dbo].[Reported1098TInformation] ON;

INSERT INTO [dbo].[Reported1098TInformation] (
	[ReportedInformationId]
	,[TaxYear]
	,[People_Code_Id]
	,[Government_Id]
	,[NameLine1]
	,[NameLine2]
	,[ForeignCountryIndicator]
	,[MailingAddress]
	,[City]
	,[State]
	,[ZipCode]
	,[Tuition]
	,[TuitionAdjustment]
	,[Scholarship]
	,[ScholarshipAdjustment]
	,[CreateDatetime]
	,[Country]
	,[ReportingMethodChanged]
	,[IncludeAmount]
	,[IsHalfTime]
	,[IsGraduated]
	,[IsSSNCertified]
	,[Payment]
	,[PaymentAdjustment]
	)
SELECT R.*
FROM OtherDB.[dbo].[Reported1098TInformation] R
INNER JOIN #ImportList I
	ON I.ReportedInformationId = R.ReportedInformationId;

SET IDENTITY_INSERT [dbo].[Reported1098TInformation] OFF;
SET IDENTITY_INSERT [dbo].[Reported1098TPeriodSummary] ON;

INSERT INTO [dbo].[Reported1098TPeriodSummary] (
	[ReportedPeriodSummaryId]
	,[ReportedInformationId]
	,[TaxYear]
	,[PeopleCodeId]
	,[AcademicYear]
	,[AcademicTerm]
	,[AcaTermStartDate]
	,[AcaTermEndDate]
	,[PriorChargesReported]
	,[CurrentChargesBilled]
	,[TuitionRefund]
	,[CumulativeChargesBilled]
	,[PriorPaymentsReported]
	,[PriorPaymentBalance]
	,[CurrentPaymentAmount]
	,[PaymentRefund]
	,[CurrentNetPaymentAmount]
	,[QTRECap]
	,[CurrentPaymentsReported]
	,[PriorRptPaymentAdjustment]
	,[CumulativeReportedPayment]
	,[TotalScholarshipAmount]
	,[IncludeNextYearAmount]
	,[PendingChargesToReport]
	,[PendingPaymentBalance]
	)
SELECT R.*
FROM OtherDB.[dbo].[Reported1098TPeriodSummary] R
INNER JOIN #ImportList I
	ON I.ReportedInformationId = R.ReportedInformationId;

SET IDENTITY_INSERT [dbo].[Reported1098TPeriodSummary] OFF;
SET IDENTITY_INSERT [dbo].[Reported1098TSummaryDetail] ON;

INSERT INTO [dbo].[Reported1098TSummaryDetail] (
	[ReportedSummaryDetailId]
	,[ReportedPeriodSummaryId]
	,[ChargeCreditNumber]
	,[ChargeCreditCode]
	,[ChargeCreditType]
	,[Amount]
	,[CountForBox1]
	,[CountForBox2]
	,[CountForBox4]
	,[CountForBox5]
	,[CountForBox6]
	)
SELECT R.*
FROM OtherDB.[dbo].[Reported1098TSummaryDetail] R
INNER JOIN [dbo].[Reported1098TPeriodSummary] R2
	ON R2.ReportedPeriodSummaryId = R.ReportedPeriodSummaryId

SET IDENTITY_INSERT [dbo].[Reported1098TSummaryDetail] OFF;
SET IDENTITY_INSERT [dbo].[Reported1098TRefundCode] ON;

INSERT INTO [dbo].[Reported1098TRefundCode] (
	[ReportedRefundCodeId]
	,[TaxYear]
	,[ChargeCreditCode]
	)
SELECT *
FROM OtherDB.[dbo].[Reported1098TRefundCode]
WHERE REPORTEDREFUNDCODEID > 4

SET IDENTITY_INSERT [dbo].[Reported1098TRefundCode] OFF;

DROP TABLE #ImportList;

--========== Compare Between Databases ==========
WITH CTE_1098T
AS (
	SELECT *
		,RANK() OVER (
			PARTITION BY PEOPLE_CODE_ID ORDER BY ReportedInformationId DESC
			) AS [RANK]
	FROM OtherDB.[dbo].[Reported1098TInformation]
	--WHERE ReportedInformationId > 68081
	WHERE TaxYear = 2018
	)
SELECT COUNT(*) [Rows]
	,SUM(Payment) [Payment Amount Sum]
	,SUM(Amount) [Detail Amount Sum]
FROM CTE_1098T I
INNER JOIN Reported1098TPeriodSummary PR
	ON PR.ReportedInformationId = I.ReportedInformationId
INNER JOIN Reported1098TSummaryDetail SD
	ON SD.ReportedPeriodSummaryId = PR.ReportedPeriodSummaryId
WHERE I.TaxYear = 2018;

SELECT COUNT(*) [Rows]
	,SUM(Payment) [Payment Amount Sum]
	,SUM(Amount) [Detail Amount Sum]
FROM [dbo].[Reported1098TInformation] I
INNER JOIN Reported1098TPeriodSummary PR
	ON PR.ReportedInformationId = I.ReportedInformationId
INNER JOIN Reported1098TSummaryDetail SD
	ON SD.ReportedPeriodSummaryId = PR.ReportedPeriodSummaryId
WHERE I.TaxYear = 2018

--Compare Reported1098TInformation
SELECT ReportedInformationId [ReportedInformationId1]
	,CHECKSUM(*) [CHECKSUM1]
INTO #Local
FROM Reported1098TInformation
WHERE TaxYear = 2018

SELECT ReportedInformationId [ReportedInformationId2]
	,CHECKSUM(*) [CHECKSUM2]
INTO #Remote
FROM OtherDB.dbo.Reported1098TInformation
WHERE TaxYear = 2018

SELECT COUNT(*) [Total Rows]
	,SUM(CASE 
			WHEN CHECKSUM1 = CHECKSUM2
				THEN 1
			ELSE 0
			END) [Matched Rows]
FROM #Local
LEFT JOIN #Remote
	ON ReportedInformationId1 = ReportedInformationId2

DROP TABLE #Local
	,#Remote
GO

--Compare Reported1098TPeriodSummary
SELECT ReportedPeriodSummaryId [ReportedPeriodSummaryId1]
	,CHECKSUM(*) [CHECKSUM1]
INTO #Local
FROM Reported1098TPeriodSummary
WHERE TaxYear = 2018

SELECT ReportedPeriodSummaryId [ReportedPeriodSummaryId2]
	,CHECKSUM(*) [CHECKSUM2]
INTO #Remote
FROM OtherDB.dbo.Reported1098TPeriodSummary
WHERE TaxYear = 2018

SELECT COUNT(*) [Total Rows]
	,SUM(CASE 
			WHEN CHECKSUM1 = CHECKSUM2
				THEN 1
			ELSE 0
			END) [Matched Rows]
FROM #Local
LEFT JOIN #Remote
	ON ReportedPeriodSummaryId1 = ReportedPeriodSummaryId2

DROP TABLE #Local
	,#Remote
GO

--Compare Reported1098TSummaryDetail
SELECT ReportedSummaryDetailId [ReportedSummaryDetailId1]
	,CHECKSUM(*) [CHECKSUM1]
INTO #Local
FROM Reported1098TSummaryDetail

SELECT ReportedSummaryDetailId [ReportedSummaryDetailId2]
	,CHECKSUM(*) [CHECKSUM2]
INTO #Remote
FROM OtherDB.dbo.Reported1098TSummaryDetail SD
WHERE ReportedPeriodSummaryId IN (
		SELECT ReportedPeriodSummaryId
		FROM OtherDB.dbo.Reported1098TPeriodSummary
		WHERE TaxYear = 2018
		)

SELECT COUNT(*) [Total Rows]
	,SUM(CASE 
			WHEN CHECKSUM1 = CHECKSUM2
				THEN 1
			ELSE 0
			END) [Matched Rows]
FROM #Local
LEFT JOIN #Remote
	ON ReportedSummaryDetailId1 = ReportedSummaryDetailId2

DROP TABLE #Local
	,#Remote
GO

--Random manual comparison
SELECT TOP 5 I.ReportedInformationId
	,I.NameLine1
	,I.Payment
	,I.PaymentAdjustment
	,I.Scholarship
	,PS.ReportedPeriodSummaryId
	,PS.AcademicYear
	,PS.AcademicTerm
	,PS.CumulativeChargesBilled
	,PS.CurrentPaymentsReported
	,SD.ReportedSummaryDetailId
	,SD.Amount
	,SD.ChargeCreditCode
INTO #Local
FROM [dbo].[Reported1098TInformation] I
INNER JOIN Reported1098TPeriodSummary PS
	ON PS.ReportedInformationId = I.ReportedInformationId
INNER JOIN Reported1098TSummaryDetail SD
	ON SD.ReportedPeriodSummaryId = PS.ReportedPeriodSummaryId
WHERE I.TaxYear = 2018
ORDER BY NEWID()

SELECT I.ReportedInformationId
	,I.NameLine1
	,I.Payment
	,I.PaymentAdjustment
	,I.Scholarship
	,PS.ReportedPeriodSummaryId
	,PS.AcademicYear
	,PS.AcademicTerm
	,PS.CumulativeChargesBilled
	,PS.CurrentPaymentsReported
	,SD.ReportedSummaryDetailId
	,SD.Amount
	,SD.ChargeCreditCode
INTO #Remote
FROM OtherDB.dbo.[Reported1098TInformation] I
INNER JOIN OtherDB.dbo.Reported1098TPeriodSummary PS
	ON PS.ReportedInformationId = I.ReportedInformationId
INNER JOIN OtherDB.dbo.Reported1098TSummaryDetail SD
	ON SD.ReportedPeriodSummaryId = PS.ReportedPeriodSummaryId
INNER JOIN #Local L
	ON L.ReportedInformationId = I.ReportedInformationId
		AND L.ReportedPeriodSummaryId = PS.ReportedPeriodSummaryId
		AND L.ReportedSummaryDetailId = SD.ReportedSummaryDetailId

SELECT *
FROM #Local

SELECT *
FROM #Remote

DROP TABLE #Local
	,#Remote

SELECT TOP 100 *
FROM Reported1098TInformation
WHERE REPORTEDINFORMATIONID BETWEEN 68075
		AND 82390
ORDER BY REPORTEDINFORMATIONID

SELECT People_Code_Id
	,COUNT(People_Code_Id) [Count]
FROM Reported1098TInformation
WHERE TaxYear = 2018
GROUP BY People_Code_Id
HAVING COUNT(People_Code_Id) > 1
GO

--========== Rudimentary check of table identity generation ==========
SELECT TOP 1 'Reported1098TInformation'
	,ReportedInformationId
	,IDENT_CURRENT('Reported1098TInformation')
FROM Reported1098TInformation
ORDER BY ReportedInformationId DESC

SELECT TOP 1 'Reported1098TPeriodSummary'
	,ReportedPeriodSummaryId
	,IDENT_CURRENT('Reported1098TPeriodSummary')
FROM Reported1098TPeriodSummary
ORDER BY ReportedPeriodSummaryId DESC

SELECT TOP 1 'Reported1098TRefundCode'
	,ReportedRefundCodeId
	,IDENT_CURRENT('Reported1098TRefundCode')
FROM Reported1098TRefundCode
ORDER BY ReportedRefundCodeId DESC

SELECT TOP 1 'Reported1098TSummaryDetail'
	,ReportedSummaryDetailId
	,IDENT_CURRENT('Reported1098TSummaryDetail')
FROM Reported1098TSummaryDetail
ORDER BY ReportedSummaryDetailId DESC

ROLLBACK TRAN
