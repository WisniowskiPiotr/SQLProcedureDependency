
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON; 

DECLARE @V_DBName SYSNAME = '{0}' ;
DECLARE @V_MainName SYSNAME = '{1}' ;
DECLARE @V_LoginName SYSNAME = '{2}' ;
DECLARE @V_SchemaName SYSNAME = '{3}' ;
DECLARE @V_UserName SYSNAME = '{4}' ;
DECLARE @V_QueueName SYSNAME = '{5}' ;
DECLARE @V_ServiceName SYSNAME = '{6}' ;
DECLARE @V_SubscribersTableName SYSNAME = '{7}' ;
DECLARE @V_ParametersTypeName SYSNAME = 'TYPE_ParametersType';
DECLARE @V_InstallProcedureName SYSNAME = 'P_InstallSubscription';
DECLARE @V_ReceiveProcedureName SYSNAME = 'P_ReceiveSubscription';
DECLARE @V_UninstallProcedureName SYSNAME = 'P_UninstallSubscription';
DECLARE @V_SubscriberName SYSNAME = '{8}';

USE [{0}];

SET @V_Cmd = '

	DECLARE @V_Message NVARCHAR(max) = '''';
	DECLARE @V_SubscriptionHash INT;
	DECLARE @V_TriggerNames NVARCHAR(max);
	DECLARE @V_SubscribersCount INT;

	SELECT @V_SubscribersCount = COUNT( [TBL_Subscribers].C_SubscribersTableId )
		FROM ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' AS [TBL_Subscribers]
		WHERE C_SubscriberString LIKE ''' + @V_SubscriberName + '''

	IF ( @V_SubscribersCount != 0 )
		BEGIN
			SET @V_Message = @V_Message + '' Subscriber found in TBL_Subscribers. '';
		END
	ELSE
		BEGIN

			DECLARE @V_ParametersTypeName SYSNAME;
			SET @V_ParametersTypeName = ''TYPE_' + @V_MainName + '_dbo_%'' ;
			IF EXISTS (
				SELECT [SysTypes].[name]
				FROM sys.types AS [SysTypes]
				INNER JOIN sys.schemas AS [SysSchemas]
					ON [SysSchemas].[schema_id] = [SysTypes].[schema_id]
					AND QUOTENAME( [SysSchemas].[name] ) = ''' + QUOTENAME( @V_SchemaName ) + ''' 
				WHERE QUOTENAME( [SysTypes].[name] ) LIKE QUOTENAME( @V_ParametersTypeName )
			)
				BEGIN
					SET @V_Message = @V_Message + @V_ParametersTypeName + '' found. '';
				END

			DECLARE @V_TriggerName SYSNAME = ''T_' + @V_MainName + '_dbo_%'' ;
			IF EXISTS (
				SELECT TBL_Triggers.name 
				FROM sys.triggers AS TBL_Triggers
				WHERE TBL_Triggers.name LIKE @V_TriggerName
			)
				BEGIN
					SET @V_Message = @V_Message + @V_TriggerName + '' found. '';
				END
		END

	SELECT @V_Message;


';

EXEC ( @V_Cmd );

