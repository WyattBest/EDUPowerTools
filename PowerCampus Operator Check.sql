USE [Campus6]
DECLARE @p1 nvarchar(9) = '000000000'
DECLARE @p2 nvarchar(9) = '000000000'

SELECT DISTINCT
	P.PEOPLE_ID
	,P.PersonId
	,FIRST_NAME
	,LAST_NAME
	,nonqualifiedUserName
	,AU.OPERATOR_ID
	,AU.[STATUS]
	,AUP.PROFILE_CODE
	,AP.PROFILE_NAME
	,AU.LOGON_ID
	,AUP.REVISION_DATE
	,AUP.CREATE_DATE
FROM PersonUser
INNER JOIN PEOPLE AS P ON PersonUser.PersonId = P.PersonId
LEFT JOIN ABT_USERS AS AU ON AU.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
LEFT JOIN ABT_USERPROFILE AS AUP ON AUP.OPERATOR_ID = AU.OPERATOR_ID
LEFT JOIN ABT_PROFILE AS AP ON AUP.PROFILE_CODE = AP.PROFILE_CODE
WHERE P.PEOPLE_ID IN
	(@p1, @p2)

SELECT DISTINCT
	P.PEOPLE_CODE_ID
	--,P.PersonId
	,FIRST_NAME
	,LAST_NAME
	,UserName
	,AU.OPERATOR_ID
	--,ifs.InquiryFormName
	--,ia.InquiryApproverId
	,abts.LABEL_NAME as 'Office'
	,abts.SETTING
FROM PersonUser
INNER JOIN PEOPLE AS P ON PersonUser.PersonId = P.PersonId
LEFT JOIN ABT_USERS AS AU ON AU.PEOPLE_CODE_ID = P.PEOPLE_CODE_ID
LEFT JOIN ABT_USERPROFILE AS AUP ON AUP.OPERATOR_ID = AU.OPERATOR_ID
LEFT JOIN ABT_PROFILE AS AP ON AUP.PROFILE_CODE = AP.PROFILE_CODE
LEFT JOIN InquiryApprover AS ia ON AUP.OPERATOR_ID = IA.OperatorId
LEFT JOIN InquiryFormSetting ifs on ia.InquiryFormSettingId = ifs.InquiryFormSettingId
LEFT JOIN ABT_SETTINGS abts on aup.OPERATOR_ID = abts.SECTION_NAME
	AND SETTING = 'Y'
WHERE P.PEOPLE_ID IN
	(@p1, @p2)

SELECT NEWID() [Random Password]