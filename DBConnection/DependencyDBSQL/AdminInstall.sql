DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Password NVARCHAR(max) = '{1}';
DECLARE @V_DefaultDBName NVARCHAR(max) = '{2}';
DECLARE @V_InstallSubscriptionProcedure NVARCHAR(max) = '{3}';
DECLARE @V_ReceiveSubscriptionProcedure NVARCHAR(max) = '{4}';
DECLARE @V_UninstallSubscriptionProcedure NVARCHAR(max) = '{5}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_CompatibilityLvl int = 0
DECLARE @V_IsBrokerEnabled bit = 0
SELECT @V_CompatibilityLvl = compatibility_level,
	@V_IsBrokerEnabled = is_broker_enabled
FROM sys.databases
WHERE [name] = db_name();  

IF( @V_CompatibilityLvl < 130)
	BEGIN;
		THROW 99999, 'In order of using DependencyDB package compatibility level must be greater or equal to 130. Required by STRING_SPLIT function.', 1;
	END
IF( @V_IsBrokerEnabled = 0)
	BEGIN;
		THROW 99998, 'Please enable Broker in Your DB. You can do this by query: ''ALTER DATABASE [<dbname>] SET enable_broker WITH ROLLBACK IMMEDIATE;''', 1;
	END

-- Create or ReCreate DependencyDB login
DECLARE @V_LoginName SYSNAME = 'L_' + @V_MainName;
BEGIN TRANSACTION
	IF EXISTS (
		SELECT name 
		FROM master.sys.server_principals
		WHERE name = @V_LoginName)
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
			DEFAULT_DATABASE = ' + QUOTENAME(@V_DefaultDBName) + ';
		'
	EXEC ( @V_Cmd )
COMMIT TRANSACTION

-- Create shema
DECLARE @V_SchemaName SYSNAME = 'S_' + @V_MainName;
IF NOT EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_SchemaName)
	BEGIN
		-- The schema must be run in its own batch!
		SET @V_Cmd = '
			CREATE SCHEMA ' + QUOTENAME(@V_SchemaName) + ';
		'
		EXEC( @V_Cmd );
	END

-- Create user
DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
IF NOT EXISTS (
	SELECT name
	FROM sys.database_principals
	WHERE 
		name = @V_UserName 
		AND type = 'S')
	BEGIN
		SET @V_Cmd = '
			CREATE USER ' + QUOTENAME(@V_UserName) + '
				FOR LOGIN ' + QUOTENAME(@V_LoginName) + '
				WITH DEFAULT_SCHEMA = ' + QUOTENAME(@V_SchemaName) +';
		'
		EXEC( @V_Cmd);
	END
ELSE
	BEGIN
		SET @V_Cmd = '
			ALTER USER ' + QUOTENAME(@V_UserName) + '
				WITH DEFAULT_SCHEMA = ' + QUOTENAME(@V_SchemaName) +',
				LOGIN = ' + QUOTENAME(@V_LoginName) + ';
		'
		EXEC( @V_Cmd);
	END

-- Create Route
IF NOT EXISTS (
	SELECT name
	FROM sys.routes
	WHERE name = 'AutoCreatedLocal')
	BEGIN
		CREATE ROUTE [AutoCreatedLocal] WITH ADDRESS = N'LOCAL';
	END

-- Create TYPE_ParametersType
IF NOT EXISTS (
	SELECT SysTypes.name 
	FROM sys.types AS SysTypes
	INNER JOIN sys.schemas AS SysSchemas
		ON SysSchemas.schema_id = SysTypes.schema_id
		AND SysSchemas.name = 'dbo'
	WHERE 
		is_table_type = 1 
		AND SysTypes.name = 'TYPE_ParametersType')
	BEGIN
		CREATE TYPE [dbo].[TYPE_ParametersType] 
			AS TABLE(
			[PName] [nvarchar](100) NULL,
			[PType] [nvarchar](20) NULL,
			[PValue] [nvarchar](100) NULL);
	END

-- Grant Provilages
SET @V_Cmd = '
	ALTER AUTHORIZATION ON SCHEMA::' + QUOTENAME(@V_SchemaName)  + ' TO  ' + QUOTENAME(@V_UserName) + ';
	-- GRANT CREATE PROCEDURE TO ' + QUOTENAME(@V_UserName)  + '; 
	GRANT SUBSCRIBE QUERY NOTIFICATIONS TO ' + QUOTENAME(@V_UserName)  + ';
	GRANT CONTROL ON CONTRACT::[DEFAULT] TO ' + QUOTENAME(@V_UserName)  + ';
	GRANT CREATE TYPE TO ' + QUOTENAME(@V_UserName)  + ';
	GRANT EXECUTE ON TYPE::[dbo].[TYPE_ParametersType] TO ' + QUOTENAME(@V_UserName)  + ';
'
EXEC( @V_Cmd );

-- Create Queue
DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
IF NOT EXISTS (
	SELECT SysQueyes.name
		FROM sys.service_queues AS SysQueyes
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysQueyes.schema_id
			AND SysSchemas.name = @V_SchemaName
		WHERE SysQueyes.name = @V_QueueName)
	BEGIN
		SET @V_Cmd = '
			CREATE QUEUE ' + QUOTENAME(@V_SchemaName) + '.' + QUOTENAME(@V_QueueName) + ';
		'
		EXEC ( @V_Cmd );
	END

-- Create Service
DECLARE @V_ServiceName SYSNAME = 'Service' + @V_MainName;
IF NOT EXISTS(
	SELECT name
		FROM sys.services 
		WHERE name = @V_ServiceName)
	BEGIN
		SET @V_Cmd = '
		CREATE SERVICE ' + QUOTENAME(@V_ServiceName) + ' 
		ON QUEUE ' + QUOTENAME(@V_SchemaName) + '.' + QUOTENAME(@V_QueueName) + '
		([DEFAULT]);
		'
		EXEC ( @V_Cmd );
	END

-- Create Table
IF NOT EXISTS(
	SELECT SysTables.name
		FROM sys.tables AS SysTables
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysTables.schema_id
			AND SysSchemas.name = @V_SchemaName
		WHERE SysTables.name = 'TBL_SubscribersTable'
	)
	BEGIN
		SET @V_Cmd = '
			CREATE TABLE ' + QUOTENAME(@V_SchemaName) + '.[TBL_SubscribersTable] (
				[C_SubscribersTableId] INT IDENTITY(1,1) NOT NULL,
				[C_SubscriberString] NVARCHAR(200) NOT NULL,
				[C_SubscriptionHash] INT NOT NULL,
				[C_ProcedureSchemaName] SYSNAME NOT NULL,
				[C_ProcedureName] SYSNAME NOT NULL,
				[C_ProcedureParameters] NVARCHAR(max) NOT NULL,
				[C_TriggerNames] NVARCHAR(max) NOT NULL,
				[C_ValidTill] DateTime NOT NULL,
				CONSTRAINT [CS_TBL_SubscribersTable_C_SubscribersTableId] PRIMARY KEY CLUSTERED (
					[C_SubscribersTableId] ASC
				)
			) ;
			CREATE NONCLUSTERED INDEX [IND_' + @V_MainName + '_TBL_SubscribersTable_C_SubscriptionHash] ON ' + QUOTENAME(@V_SchemaName) + '.[TBL_SubscribersTable] (
				[C_SubscriptionHash] ASC
			) ;
			CREATE NONCLUSTERED INDEX [IND_' + @V_MainName + '_TBL_SubscribersTable_C_ValidTill] ON ' + QUOTENAME(@V_SchemaName) + '.[TBL_SubscribersTable] (
				[C_ValidTill] ASC
			) ;
		'
		EXEC ( @V_Cmd );
	END

-- Create Procedures
IF EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND QUOTENAME( SysSchemas.name ) = QUOTENAME(@V_SchemaName) 
		WHERE SysProcedures.name = 'P_InstallSubscription'
	)
	BEGIN
		SET @V_Cmd = 'ALTER -- ' + @V_InstallSubscriptionProcedure ;
	END
ELSE
	BEGIN
		SET @V_Cmd = 'CREATE -- ' + @V_InstallSubscriptionProcedure ;
	END
EXEC ( @V_Cmd );

IF EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND QUOTENAME( SysSchemas.name ) = QUOTENAME(@V_SchemaName) 
		WHERE SysProcedures.name = 'P_ReceiveSubscription'
	)
	BEGIN
		SET @V_Cmd = 'ALTER -- ' + @V_ReceiveSubscriptionProcedure ;
	END
ELSE
	BEGIN
		SET @V_Cmd = 'CREATE -- ' + @V_ReceiveSubscriptionProcedure ;
	END
EXEC ( @V_Cmd );

IF EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND QUOTENAME( SysSchemas.name ) = QUOTENAME(@V_SchemaName) 
		WHERE SysProcedures.name = 'P_UninstallSubscription'
	)
	BEGIN
		SET @V_Cmd = 'ALTER -- ' + @V_UninstallSubscriptionProcedure ;
	END
ELSE
	BEGIN
		SET @V_Cmd = 'CREATE -- ' + @V_UninstallSubscriptionProcedure ;
	END
EXEC ( @V_Cmd );
