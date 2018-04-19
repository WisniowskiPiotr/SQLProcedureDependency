
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

	IF ( @V_SubscribersCount = 0 )
		BEGIN
			SET @V_Message = @V_Message + '' No subscriber found in TBL_Subscribers. '';
		END
	ELSE
		BEGIN
			SET @V_Message = @V_Message + CAST( @V_SubscribersCount AS NVARCHAR(200) ) + '' - Subscriber count. '' ;
			SELECT @V_SubscriptionHash = [TBL_Subscribers].C_SubscriptionHash,
				@V_TriggerNames = [TBL_Subscribers].C_TriggerNames
			FROM ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' AS [TBL_Subscribers]
			WHERE C_SubscriberString LIKE ''' + @V_SubscriberName + ''' ;

			DECLARE @V_ParametersTypeName SYSNAME;
			SET @V_ParametersTypeName = ''TYPE_' + @V_MainName + '_dbo_TBL_FirstTable_'' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) ;
			IF NOT EXISTS (
				SELECT [SysTypes].[name]
				FROM sys.types AS [SysTypes]
				INNER JOIN sys.schemas AS [SysSchemas]
					ON [SysSchemas].[schema_id] = [SysTypes].[schema_id]
					AND QUOTENAME( [SysSchemas].[name] ) = ''' + QUOTENAME( @V_SchemaName ) + ''' 
				WHERE QUOTENAME( [SysTypes].[name] ) = QUOTENAME( @V_ParametersTypeName )
			)
				BEGIN
					SET @V_Message = @V_Message + @V_ParametersTypeName + '' not found. '';
				END
			
			SET @V_ParametersTypeName = ''TYPE_' + @V_MainName + '_dbo_TBL_SecondTable_'' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) ;
			IF NOT EXISTS (
				SELECT [SysTypes].[name]
				FROM sys.types AS [SysTypes]
				INNER JOIN sys.schemas AS [SysSchemas]
					ON [SysSchemas].[schema_id] = [SysTypes].[schema_id]
					AND QUOTENAME( [SysSchemas].[name] ) = ''' + QUOTENAME( @V_SchemaName ) + ''' 
				WHERE QUOTENAME( [SysTypes].[name] ) = QUOTENAME( @V_ParametersTypeName )
			)
				BEGIN
					SET @V_Message = @V_Message + @V_ParametersTypeName + '' not found. '';
				END

			DECLARE @V_TriggerName SYSNAME ;
			DECLARE @V_TableName SYSNAME ;
			DECLARE @V_TableSchemaName SYSNAME ;

			SELECT @V_TriggerName = TBL_Triggers.name ,
				@V_TableName = TBL_Objects.name ,
				@V_TableSchemaName = TBL_Schemas.name
			FROM STRING_SPLIT( @V_TriggerNames , '';'') AS TBL_TriggerNames
			LEFT OUTER JOIN sys.triggers AS TBL_Triggers
				ON QUOTENAME( TBL_Triggers.name ) = TBL_TriggerNames.value
			LEFT OUTER JOIN sys.objects AS TBL_Objects
				ON TBL_Objects.object_id = TBL_Triggers.parent_id
			LEFT OUTER JOIN sys.schemas AS TBL_Schemas
				ON TBL_Schemas.schema_id = TBL_Objects.schema_id
			WHERE TBL_Triggers.name IS NULL
			GROUP BY TBL_Triggers.name,
				TBL_Objects.name,
				TBL_Schemas.name ;

			IF( @V_TriggerName IS NOT NULL)
				BEGIN
					SET @V_Message = @V_Message + @V_TriggerName + '' not found. '';
				END
		END

	SELECT @V_Message;


';

EXEC ( @V_Cmd );

