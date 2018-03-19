DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_LoginName SYSNAME = 'L_' + @V_MainName;
DECLARE @V_SchemaName SYSNAME = 'S_' + @V_MainName;
DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
DECLARE @V_ServiceName SYSNAME = 'Service' + @V_MainName;
DECLARE @V_TableName SYSNAME = 'TBL_Subscribers' ;

DECLARE @V_SubscriberString VARCHAR(max) = '{1}';
DECLARE @V_SubscriptionHash VARCHAR(max) = '{2}';
DECLARE @V_ReferencedSchema SYSNAME = '{3}';
DECLARE @V_ReferencedTable SYSNAME = '{4}';
DECLARE @V_TriggerName SYSNAME = 'T_' + @V_MainName + '_' + @V_ReferencedSchema + '_' + @V_ReferencedTable + '_' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) ;
			

SET @V_Cmd = '
IF 
	EXISTS (
		SELECT C_SubscribersTableId
		FROM ' + QUOTENAME( @V_SchemaName ) + '.[TBL_SubscribersTable] AS TBL_Subscribers
		WHERE TBL_Subscribers.C_SubscriberString = ''{1}''
			AND TBL_Subscribers.C_SubscriptionHash = ''{2}''
	)
	AND
	EXISTS (
		SELECT name
		FROM sys.triggers
		WHERE 
			name = ''' + @V_TriggerName + ''' 
	)
	BEGIN
		SELECT 1
	END
ELSE
	BEGIN
		SELECT 0
	END
	'

EXECUTE ( @V_Cmd ) ;