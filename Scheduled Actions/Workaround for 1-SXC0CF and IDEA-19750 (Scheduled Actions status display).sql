USE Campus6

-- Workaround for 1-SXC0CF/IDEA-19750 (Scheduled Actions status display)
-- See https://ellucian.service-now.com/community?id=community_question&sys_id=c3d9bb3f1b9b3850eba0a7d5604bcb58

BEGIN TRAN

INSERT INTO [ABT_OBJECTSMODIFY]
SELECT N'd_ff_actionschedule'
	,N'c_action_status'
	,N'expression'
	,N'PUBLIC'
	,N'''If(Not(IsNull(actionschedule_execution_date) or actionschedule_execution_date = Date("0/0/0000")), "Complete", If(actionschedule_canceled = "Y", "Canceled", If(actionschedule_waived = "Y","Waived", If(DaysAfter(actionschedule_scheduled_date,Today()) < 0, "Future", If(DaysAfter(actionschedule_scheduled_date,Today()) = 0,"Today","Past Due")))))'''
	,N'''If(	Not( IsNull(actionschedule_execution_date) or actionschedule_execution_date = Date("0/0/0000")), "Complete", If(DaysAfter(actionschedule_scheduled_date,Today()) < 0, "Future", If(DaysAfter(actionschedule_scheduled_date,Today()) = 0,"Today","Past Due")))'''
	,'2021-10-26 00:00:00.000'
	,'1900-01-01 17:53:50.847'
	,N'WBEST'
	,N'0001'
	,'2021-10-26 00:00:00.000'
	,'1900-01-01 17:53:52.190'
	,N'WBEST'
	,N'0001'
	,N'*'

UNION ALL

SELECT N'd_tab_actionschedule'
	,N'c_action_status'
	,N'expression'
	,N'PUBLIC'
	,N'''If(Not(IsNull(actionschedule_execution_date) or actionschedule_execution_date = Date("0/0/0000")), "Complete", If(actionschedule_canceled = "Y", "Canceled", If(actionschedule_waived = "Y","Waived", If(DaysAfter(actionschedule_scheduled_date,Today()) < 0, "Future", If(DaysAfter(actionschedule_scheduled_date,Today()) = 0,"Today","Past Due")))))'''
	,N'''If(	Not( IsNull(actionschedule_execution_date) or actionschedule_execution_date = Date("0/0/0000")), "Complete", If(DaysAfter(actionschedule_scheduled_date,Today()) < 0, "Future", If(DaysAfter(actionschedule_scheduled_date,Today()) = 0,"Today","Past Due")))'''
	,'2021-10-26 00:00:00.000'
	,'1900-01-01 13:32:47.167'
	,N'WBEST'
	,N'0001'
	,'2021-10-26 00:00:00.000'
	,'1900-01-01 13:32:47.167'
	,N'WBEST'
	,N'0001'
	,N'*';

ROLLBACK TRAN


/*
If(	Not( IsNull(actionschedule_execution_date) or actionschedule_execution_date = Date("0/0/0000")), "Complete", If(DaysAfter(actionschedule_scheduled_date,Today()) < 0, "FF", If(DaysAfter(actionschedule_scheduled_date,Today()) = 0,"Today","Past Due")))

If(	Not( IsNull(actionschedule_execution_date) or actionschedule_execution_date = Date("0/0/0000")), "Complete",
	If ( actionschedule_canceled = "Y", "Canceled",
		If( actionschedule_waived = "Y","Waived",
			If(DaysAfter(actionschedule_scheduled_date,Today()) < 0, "Future",
				If(DaysAfter(actionschedule_scheduled_date,Today()) = 0,"Today","Past Due")
				)
			)
		)
	)
*/