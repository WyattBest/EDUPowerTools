
-- Usage:
--		Print a decent-looking Stop Reason report for distributing to end users.
--
-- History: 
--		2019-09 Wyatt Best: Wrote first version

SELECT CODE_VALUE
	,SHORT_DESC
	,MEDIUM_DESC
	,LONG_DESC AS [Message]
	--,CODE_XDESC as [Internal Note]
	,CASE STOP_REGISTRATION WHEN 'Y' THEN 'Yes' WHEN 'N' THEN 'No' END AS [STOP_REGISTRATION]
	,CASE STOP_GRADES WHEN 'Y' THEN 'Yes' WHEN 'N' THEN 'No' END AS [STOP_GRADES]
	,CASE SHOW_STOP_PICTURE WHEN 'Y' THEN 'Yes' WHEN 'N' THEN 'No' END AS [SHOW_STOP_PICTURE]
	,CAST(CREATE_DATE AS DATE) [CREATE_DATE]
	,CASE [STATUS] WHEN 'A' THEN 'Active' WHEN 'I' THEN 'Inactive' END AS [Status]
FROM CODE_STOPLIST

