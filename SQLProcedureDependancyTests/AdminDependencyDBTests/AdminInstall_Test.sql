
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

DECLARE @V_Message NVARCHAR(max) = '';

-- switch to DB
USE [{0}];

IF NOT EXISTS (
	SELECT [SysRoutes].[name]
	FROM sys.routes AS [SysRoutes]
	WHERE QUOTENAME( name ) = QUOTENAME( 'AutoCreatedLocal' )
)
	SET @V_Message = @V_Message + 'AutoCreatedLocal' + ' does not exists. ';

IF NOT EXISTS (
	SELECT [SysTypes].[name]
	FROM sys.types AS [SysTypes]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysTypes].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( 'dbo' )
	WHERE QUOTENAME( [SysTypes].[name] ) = QUOTENAME( @V_ParametersTypeName )
)
	SET @V_Message = @V_Message + @V_ParametersTypeName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [server_principals].[name]
	FROM master.sys.server_principals AS [server_principals]
	WHERE QUOTENAME( [server_principals].[name] ) = QUOTENAME( @V_LoginName )
)
	SET @V_Message = @V_Message + @V_LoginName + ' does not exists. ';


IF NOT EXISTS (
	SELECT [schemas].[name]  
	FROM sys.schemas AS [schemas]
	WHERE QUOTENAME( [schemas].[name] ) = QUOTENAME( @V_SchemaName )
)
	SET @V_Message = @V_Message + @V_SchemaName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [database_principals].[name]
	FROM sys.database_principals AS [database_principals]
	WHERE QUOTENAME( [database_principals].[name] ) = QUOTENAME( @V_UserName )
)
	SET @V_Message = @V_Message + @V_UserName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [SysQueues].[name]
	FROM sys.service_queues AS [SysQueues]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysQueues].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysQueues].[name] ) = QUOTENAME( @V_QueueName )
)
	SET @V_Message = @V_Message + @V_QueueName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [services].[name]
	FROM sys.services AS [services]
	WHERE QUOTENAME( [services].[name] ) = QUOTENAME( @V_ServiceName )
)
	SET @V_Message = @V_Message + @V_ServiceName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [SysTables].[name]
	FROM sys.tables AS [SysTables]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysTables].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysTables].[name] ) = QUOTENAME( @V_SubscribersTableName )
)
	SET @V_Message = @V_Message + @V_SubscribersTableName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_InstallProcedureName )
)
	SET @V_Message = @V_Message + @V_InstallProcedureName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_ReceiveProcedureName )
)
	SET @V_Message = @V_Message + @V_ReceiveProcedureName + ' does not exists. ';

IF NOT EXISTS (
	SELECT [SysProcedures].[name]
	FROM sys.procedures AS [SysProcedures]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysProcedures].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysProcedures].[name] ) = QUOTENAME( @V_UninstallProcedureName )
)
	SET @V_Message = @V_Message + @V_UninstallProcedureName + ' does not exists. ';

SELECT @V_Message ;
