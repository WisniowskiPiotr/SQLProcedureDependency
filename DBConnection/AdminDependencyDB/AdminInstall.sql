
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_DBName SYSNAME = '{0}' ;
DECLARE @V_MainName SYSNAME = '{1}' ;
DECLARE @V_Password NVARCHAR(max) = '{2}' ;
DECLARE @V_InstallSubscriptionProcedureBody NVARCHAR(max) = '{3}';
DECLARE @V_ReceiveSubscriptionProcedureBody NVARCHAR(max) = '{4}';
DECLARE @V_UninstallSubscriptionProcedureBody NVARCHAR(max) = '{5}';

-- switch to DB
USE [{0}];

-- test requirements 
DECLARE @V_CompatibilityLvl int = 0 ;
DECLARE @V_IsBrokerEnabled bit = 0 ;
SELECT @V_CompatibilityLvl = [databases].[compatibility_level],
	@V_IsBrokerEnabled = [databases].[is_broker_enabled]
FROM sys.databases AS [databases]
WHERE QUOTENAME( [name] ) = QUOTENAME( @V_DBName ) ;  

IF( @V_CompatibilityLvl < 130)
	BEGIN;
		THROW 99999, 'In order of using DependencyDB package compatibility level must be greater or equal to 130. Required by STRING_SPLIT function.', 1;
	END
IF( @V_IsBrokerEnabled = 0)
	BEGIN;
		THROW 99998, 'Please enable Broker in Your DB. You can do this by query: ''ALTER DATABASE [<dbname>] SET enable_broker WITH ROLLBACK IMMEDIATE;''', 1;
	END

-- switch to DB
SET @V_Cmd = '
	USE ' + QUOTENAME( @V_DBName ) + ' ; 
' ;
EXEC ( @V_Cmd );

-- create route
IF NOT EXISTS (
	SELECT [SysRoutes].[name]
	FROM sys.routes AS [SysRoutes]
	WHERE QUOTENAME( name ) = QUOTENAME( 'AutoCreatedLocal' )
)
	BEGIN
		CREATE ROUTE [AutoCreatedLocal] WITH ADDRESS = N'LOCAL';
	END

-- create dbo.TYPE_ParametersType
DECLARE @V_ParametersTypeName SYSNAME = 'TYPE_ParametersType';
IF NOT EXISTS (
	SELECT [SysTypes].[name]
	FROM sys.types AS [SysTypes]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysTypes].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( 'dbo' )
	WHERE QUOTENAME( [SysTypes].[name] ) = QUOTENAME( @V_ParametersTypeName )
)
	BEGIN
		SET @V_Cmd = '
			CREATE TYPE [dbo].' + QUOTENAME( @V_ParametersTypeName ) + '
			AS TABLE(
			[PName] [NVARCHAR](100) NULL,
			[PType] [NVARCHAR](20) NULL,
			[PValue] [NVARCHAR](4000) NULL);
		'
		EXEC ( @V_Cmd );
	END

-- create or recreate login
DECLARE @V_LoginName SYSNAME = @V_MainName ;
BEGIN TRANSACTION
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
	SET @V_Cmd = '
		CREATE LOGIN ' + QUOTENAME(@V_LoginName) + '
			WITH PASSWORD = ''' + @V_Password + ''', 
			CHECK_EXPIRATION = OFF, 
			CHECK_POLICY = OFF,
			DEFAULT_DATABASE = ' + QUOTENAME(@V_DBName) + ';
		'
	EXEC ( @V_Cmd )
COMMIT TRANSACTION

-- create shema
DECLARE @V_SchemaName SYSNAME = @V_MainName;
IF NOT EXISTS (
	SELECT [schemas].[name]  
	FROM sys.schemas AS [schemas]
	WHERE QUOTENAME( [schemas].[name] ) = QUOTENAME( @V_SchemaName )
)
	BEGIN
		SET @V_Cmd = '
			CREATE SCHEMA ' + QUOTENAME(@V_SchemaName) + ';
		'
		EXEC( @V_Cmd );
	END

-- create user
DECLARE @V_UserName SYSNAME = @V_MainName;
IF NOT EXISTS (
	SELECT [database_principals].[name]
	FROM sys.database_principals AS [database_principals]
	WHERE QUOTENAME( [database_principals].[name] ) = QUOTENAME( @V_UserName )
)
	BEGIN
		SET @V_Cmd = '
			CREATE USER ' + QUOTENAME( @V_UserName ) + '
			FOR LOGIN ' + QUOTENAME( @V_LoginName ) + '
			WITH DEFAULT_SCHEMA = ' + QUOTENAME( @V_SchemaName ) +' ;
		'
		EXEC( @V_Cmd);
	END
ELSE
	BEGIN
		SET @V_Cmd = '
			ALTER USER ' + QUOTENAME( @V_UserName ) + '
			WITH DEFAULT_SCHEMA = ' + QUOTENAME( @V_SchemaName ) +',
			LOGIN = ' + QUOTENAME( @V_LoginName ) + ';
		'
		EXEC( @V_Cmd);
	END

-- create queue
DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
IF NOT EXISTS (
	SELECT [SysQueues].[name]
	FROM sys.service_queues AS [SysQueues]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysQueues].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysQueues].[name] ) = QUOTENAME( @V_QueueName )
)
	BEGIN
		SET @V_Cmd = '
			CREATE QUEUE ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_QueueName ) + ';
		'
		EXEC ( @V_Cmd );
	END

-- create service
DECLARE @V_ServiceName SYSNAME = 'S_' + @V_MainName;
IF NOT EXISTS(
	SELECT [services].[name]
	FROM sys.services AS [services]
	WHERE QUOTENAME( [services].[name] ) = QUOTENAME( @V_ServiceName )
)
	BEGIN
		SET @V_Cmd = '
			CREATE SERVICE ' + QUOTENAME( @V_ServiceName ) + ' 
			ON QUEUE ' + QUOTENAME (@V_SchemaName ) + '.' + QUOTENAME( @V_QueueName ) + '
			([DEFAULT]) ;
		'
		EXEC ( @V_Cmd );
	END


-- create table
DECLARE @V_SubscribersTableName SYSNAME = 'TBL_SubscribersTable';
DECLARE @V_SubscribersTableConstraintName SYSNAME = 'CS_' + @V_SchemaName + '_' + @V_SubscribersTableName + '_C_SubscribersTableId';
DECLARE @V_SubscribersTableHashIndexName SYSNAME = 'IND_' + @V_SchemaName + '_'+ @V_SubscribersTableName + '_C_SubscriptionHash';
DECLARE @V_SubscribersTableValidIndexName SYSNAME = 'IND_' + @V_SchemaName + '_'+ @V_SubscribersTableName + '_C_ValidTill';
IF NOT EXISTS(
	SELECT [SysTables].[name]
	FROM sys.tables AS [SysTables]
	INNER JOIN sys.schemas AS [SysSchemas]
		ON [SysSchemas].[schema_id] = [SysTables].[schema_id]
		AND QUOTENAME( [SysSchemas].[name] ) = QUOTENAME( @V_SchemaName )
	WHERE QUOTENAME( [SysTables].[name] ) = QUOTENAME( @V_SubscribersTableName )
)
	BEGIN
		SET @V_Cmd = '
			CREATE TABLE ' + QUOTENAME(@V_SchemaName) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' (
				[C_SubscribersTableId] INT IDENTITY(1,1) NOT NULL,
				[C_SubscriberString] NVARCHAR(200) NOT NULL,
				[C_SubscriptionHash] INT NOT NULL,
				[C_ProcedureSchemaName] SYSNAME NOT NULL,
				[C_ProcedureName] SYSNAME NOT NULL,
				[C_ProcedureParameters] NVARCHAR(max) NOT NULL,
				[C_TriggerNames] NVARCHAR(max) NOT NULL,
				[C_ValidTill] DateTime NOT NULL,
				CONSTRAINT ' + QUOTENAME( @V_SubscribersTableConstraintName ) + ' PRIMARY KEY CLUSTERED (
					[C_SubscribersTableId] ASC
				)
			) ;
			CREATE NONCLUSTERED INDEX ' + QUOTENAME( @V_SubscribersTableHashIndexName ) + ' ON ' + QUOTENAME(@V_SchemaName) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' (
				[C_SubscriptionHash] ASC
			) ;
			CREATE NONCLUSTERED INDEX ' + QUOTENAME( @V_SubscribersTableValidIndexName ) + ' ON ' + QUOTENAME(@V_SchemaName) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' (
				[C_ValidTill] ASC
			) ;
		'
		EXEC ( @V_Cmd );
	END

-- create uninstall subscription procedure
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<0>', @V_DBName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<1>', @V_MainName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<2>', @V_LoginName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<3>', @V_SchemaName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<4>', @V_UserName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<5>', @V_QueueName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<6>', @V_ServiceName);
SET @V_UninstallSubscriptionProcedureBody = REPLACE( @V_UninstallSubscriptionProcedureBody , '<7>', @V_SubscribersTableName);

DECLARE @V_UninstallProcedureName SYSNAME = 'P_UninstallSubscription';
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
			ALTER PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_UninstallProcedureName ) + '
			--' + @V_UninstallSubscriptionProcedureBody + '
		' ;
	END
ELSE
	BEGIN
		SET @V_Cmd = '
			CREATE PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_UninstallProcedureName ) + '
			--' + @V_UninstallSubscriptionProcedureBody + '
		' ;
	END
EXEC ( @V_Cmd );

-- create install subscription procedure
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<0>', @V_DBName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<1>', @V_MainName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<2>', @V_LoginName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<3>', @V_SchemaName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<4>', @V_UserName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<5>', @V_QueueName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<6>', @V_ServiceName);
SET @V_InstallSubscriptionProcedureBody = REPLACE( @V_InstallSubscriptionProcedureBody , '<7>', @V_SubscribersTableName);

DECLARE @V_InstallProcedureName SYSNAME = 'P_InstallSubscription';
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
			ALTER PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_InstallProcedureName ) + '
			--' + @V_InstallSubscriptionProcedureBody + '
		' ;
	END
ELSE
	BEGIN
		SET @V_Cmd = '
			CREATE PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_InstallProcedureName ) + '
			--' + @V_InstallSubscriptionProcedureBody + '
		' ;
	END
EXEC ( @V_Cmd );

-- create receive subscription procedure
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<0>', @V_DBName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<1>', @V_MainName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<2>', @V_LoginName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<3>', @V_SchemaName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<4>', @V_UserName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<5>', @V_QueueName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<6>', @V_ServiceName);
SET @V_ReceiveSubscriptionProcedureBody = REPLACE( @V_ReceiveSubscriptionProcedureBody , '<7>', @V_SubscribersTableName);

DECLARE @V_ReceiveProcedureName SYSNAME = 'P_ReceiveSubscription';
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
			ALTER PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_ReceiveProcedureName ) + '
			--' + @V_ReceiveSubscriptionProcedureBody + '
		' ;
	END
ELSE
	BEGIN
		SET @V_Cmd = '
			CREATE PROCEDURE ' + QUOTENAME( @V_SchemaName ) + '.' +  QUOTENAME( @V_ReceiveProcedureName ) + '
			--' + @V_ReceiveSubscriptionProcedureBody  + '
		' ;
	END
EXEC ( @V_Cmd );

-- grant Provilages
SET @V_Cmd = '
	ALTER AUTHORIZATION ON SCHEMA::' + QUOTENAME( @V_SchemaName )  + ' TO  ' + QUOTENAME( @V_UserName ) + ';
	GRANT SUBSCRIBE QUERY NOTIFICATIONS TO ' + QUOTENAME( @V_UserName )  + ';
	GRANT CONTROL ON CONTRACT::[DEFAULT] TO ' + QUOTENAME( @V_UserName )  + ';
	GRANT CREATE TYPE TO ' + QUOTENAME( @V_UserName )  + ';
	GRANT EXECUTE ON TYPE::[dbo].[TYPE_ParametersType] TO ' + QUOTENAME( @V_UserName )  + ';
'
EXEC( @V_Cmd );
