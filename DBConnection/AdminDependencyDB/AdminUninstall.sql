
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_DBName SYSNAME = '{0}' ;
DECLARE @V_MainName SYSNAME = '{1}' ;
DECLARE @V_LoginName SYSNAME = @V_MainName ;
DECLARE @V_SchemaName SYSNAME = @V_MainName ;
DECLARE @V_UserName SYSNAME = @V_MainName ;
DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName ;
DECLARE @V_ServiceName SYSNAME = 'S_' + @V_MainName ;
DECLARE @V_SubscribersTableName SYSNAME = 'TBL_SubscribersTable' ;
DECLARE @V_ParametersTypeName SYSNAME = 'TYPE_ParametersType';
DECLARE @V_InstallProcedureName SYSNAME = 'P_InstallSubscription';
DECLARE @V_ReceiveProcedureName SYSNAME = 'P_ReceiveSubscription';
DECLARE @V_UninstallProcedureName SYSNAME = 'P_UninstallSubscription';

-- switch to DB
USE [{0}];

-- drop all triggers
IF EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_UninstallProcedureName )
)
	BEGIN
		--DECLARE @TBL_EmptyProcedureParameters dbo.TYPE_ParametersType;
		EXEC [{1}].[P_UninstallSubscription] @V_SubscriberString = NULL, @V_SubscriptionHash = NULL; --, @TBL_ProcedureParameters = @TBL_EmptyProcedureParameters 
	END	

-- drop uninstall subscription procedure
IF EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_UninstallProcedureName )
)
	BEGIN
		SET @V_Cmd = '
			DROP PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_UninstallProcedureName ) + ' ;
		' ;
		EXEC ( @V_Cmd );
	END

-- drop receive subscription procedure
IF EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_ReceiveProcedureName )
)
	BEGIN
		SET @V_Cmd = '
			DROP PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_ReceiveProcedureName ) + ' ;
		' ;
		EXEC ( @V_Cmd );
	END

-- drop install subscription procedure
IF EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_InstallProcedureName )
)
	BEGIN
		SET @V_Cmd = '
			DROP PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_InstallProcedureName ) + ' ;
		' ;
		EXEC ( @V_Cmd );
	END

-- drop table
IF EXISTS(
	SELECT [SysTables].[name]
	FROM sys.tables AS [SysTables]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysTables].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysTables].[name] ) = QUOTENAME( @V_SubscribersTableName )
)
	BEGIN
		SET @V_Cmd = '
			DROP TABLE ' + QUOTENAME(@V_SchemaName) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' ;
		'
		EXEC ( @V_Cmd );
	END

-- drop service
IF EXISTS(
	SELECT [services].[name]
		FROM sys.services AS [services]
		WHERE QUOTENAME( [services].[name] ) = QUOTENAME( @V_ServiceName )
)
	BEGIN
		SET @V_Cmd = '
			DROP SERVICE ' + QUOTENAME( @V_ServiceName ) + ' ;
		'
		EXEC ( @V_Cmd );
	END

-- drop queue
IF EXISTS (
	SELECT [SysQueues].[name]
	FROM sys.service_queues AS [SysQueues]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysQueues].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysQueues].[name] ) = QUOTENAME( @V_QueueName )
)
	BEGIN
		SET @V_Cmd = '
			DROP QUEUE ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_QueueName ) + ';
		'
		EXEC ( @V_Cmd );
	END

-- drop shema
IF EXISTS (
	SELECT [schemas].[name]  
	FROM sys.schemas AS [schemas]
	WHERE QUOTENAME( [schemas].[name] ) = QUOTENAME( @V_SchemaName )
)
	BEGIN
		SET @V_Cmd = '
			DROP SCHEMA ' + QUOTENAME(@V_SchemaName) + ';
		'
		EXEC( @V_Cmd );
	END

-- drop user
IF EXISTS (
	SELECT [database_principals].[name]
	FROM sys.database_principals AS [database_principals]
	WHERE QUOTENAME( [database_principals].[name] ) = QUOTENAME( @V_UserName )
)
	BEGIN
		SET @V_Cmd = '
			DROP USER ' + QUOTENAME( @V_UserName ) + '
		'
		EXEC( @V_Cmd);
	END

-- drop login
IF EXISTS (
	SELECT [server_principals].[name]
	FROM master.sys.server_principals AS [server_principals]
	WHERE QUOTENAME( [server_principals].[name] ) = QUOTENAME( @V_LoginName )
)
	BEGIN
		SET @V_Cmd = '
			DROP LOGIN ' + QUOTENAME(@V_LoginName) + ';
		'
		EXEC ( @V_Cmd );
	END

-- drop dbo.TYPE_ParametersType
BEGIN TRY
	IF EXISTS (
		SELECT [SysTypes].[name]
		FROM sys.types AS [SysTypes]
		INNER JOIN sys.schemas AS [SysSchemas]
			ON [SysSchemas].[schema_id] = [SysTypes].[schema_id]
			AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( 'dbo' )
		WHERE QUOTENAME( [SysTypes].[name] ) = QUOTENAME( @V_ParametersTypeName )
	)
		BEGIN
			SET @V_Cmd = '
				DROP TYPE [dbo].' + QUOTENAME( @V_ParametersTypeName ) + ' ;
			'
			EXEC ( @V_Cmd );
		END
END TRY
BEGIN CATCH
END CATCH