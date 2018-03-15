DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- Create or ReCreate DependencyDB login
BEGIN TRANSACTION
	IF EXISTS (
		SELECT name 
		FROM master.sys.server_principals
		WHERE name = @V_MainName)
		BEGIN
			SET @V_Cmd = '
				DROP LOGIN ' + quotename(@V_MainName) + ';
			'
			EXEC ( @V_Cmd );
		END
	SET @V_Cmd = '
		CREATE LOGIN ' + quotename(@V_MainName) + '
			WITH PASSWORD = ''{1}'', 
			CHECK_EXPIRATION = OFF, 
			CHECK_POLICY = OFF;
		'
	EXEC ( @V_Cmd )
COMMIT TRANSACTION

-- Create shema
IF NOT EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_MainName)
	BEGIN
		-- The schema must be run in its own batch!
		SET @V_Cmd = '
			CREATE SCHEMA ' + quotename(@V_MainName) + ';
		'
		EXEC( @V_Cmd );
	END

-- Create user
IF NOT EXISTS (
	SELECT name
	FROM sys.database_principals
	WHERE 
		name = @V_MainName AND
		type = 'S')
	BEGIN
		SET @V_Cmd = '
			CREATE USER ' + quotename(@V_MainName) + '
				FOR LOGIN ' + quotename(@V_MainName) + '
				WITH DEFAULT_SCHEMA = ' + quotename(@V_MainName) +';
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
	SELECT name 
	FROM sys.types 
	WHERE 
		is_table_type = 1 AND 
		name = 'TYPE_ParametersType')
	BEGIN
		CREATE TYPE [dbo].[TYPE_ParametersType] 
			AS TABLE(
			[PName] [nvarchar](100) NULL,
			[Ptype] [nvarchar](20) NULL,
			[PValue] [nvarchar](100) NULL);
	END

-- Grant Provilages
SET @V_Cmd = '
	ALTER AUTHORIZATION ON SCHEMA::' + quotename(@V_MainName)  + ' TO  ' + quotename(@V_MainName) + ';
	GRANT CREATE PROCEDURE TO ' + quotename(@V_MainName)  + '; 
	GRANT SUBSCRIBE QUERY NOTIFICATIONS TO ' + quotename(@V_MainName)  + ';
	GRANT CONTROL ON CONTRACT::[DEFAULT] TO ' + quotename(@V_MainName)  + ';
	GRANT EXECUTE ON TYPE::[dbo].[TYPE_ParametersType] TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd );

-- Create Queue
DECLARE @V_QueueName SYSNAME
SET @V_QueueName = 'Queue' + @V_MainName
IF NOT EXISTS (
	SELECT name
		FROM sys.service_queues 
		WHERE name = @V_QueueName)
	BEGIN
		SET @V_Cmd = '
			CREATE QUEUE ' + quotename(@V_MainName) + '.' + quotename(@V_QueueName) + ';
		'
		EXEC ( @V_Cmd );
	END

-- Create Service
DECLARE @V_ServiceName SYSNAME
SET @V_ServiceName = 'Service' + @V_MainName
IF NOT EXISTS(
	SELECT name
		FROM sys.services 
		WHERE name = @V_ServiceName)
	BEGIN
		SET @V_Cmd = '
		CREATE SERVICE ' + quotename(@V_ServiceName) + ' 
		ON QUEUE ' + quotename(@V_MainName) + '.' + quotename(@V_QueueName) + '
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
		WHERE SysTables.name = 'SubscribersTable'
			AND SysSchemas.name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			CREATE TABLE ' + quotename(@V_MainName) + '.[SubscribersTable] (
				[C_SubscribersTableId] INT IDENTITY(1,1) NOT NULL,
				[C_SubscriberString] NVARCHAR(200) NOT NULL,
				[C_SubscriptionHash] INT NOT NULL,
				[C_ProcedureSchemaName] SYSNAME NOT NULL,
				[C_ProcedureName] SYSNAME NOT NULL,
				[C_ProcedureParameters] NVARCHAR(max) NOT NULL,
				[C_ProcedureParameters] NVARCHAR(max) NOT NULL,
				[C_ValidTill] DateTime NOT NULL,
				CONSTRAINT [CS_TBL_SubscribersTable_C_SubscribersTableId] PRIMARY KEY CLUSTERED (
					[C_SubscribersTableId] ASC
				)
			) ;
			CREATE NONCLUSTERED INDEX [IND_' + @V_MainName + '_TBL_SubscribersTable_C_SubscriptionHash] ON ' + quotename(@V_MainName) + '.[SubscribersTable] (
				[C_SubscriptionHash] ASC
			) ;
		'
		EXEC ( @V_Cmd );
	END