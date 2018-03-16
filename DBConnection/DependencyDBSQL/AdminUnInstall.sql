DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- Uninstall all triggers
SET @V_Cmd = '
	DECLARE @TBL_ProcedureParameters dbo.TYPE_ParametersType ;
	INSERT INTO @TBL_ProcedureParameters (
		PName,
		PType,
		PValue
	)
	VALUES (
		''@V_RemoveAllParameters'',
		''INT'',
		''1''
	)
	EXEC ' + QUOTENAME(@V_MainName) + '.[UninstallSubscription] 
		@V_SubscriberString = null, 
		@V_SubscriptionHash = null, 
		@V_ProcedureSchemaName = null, 
		@V_ProcedureName = null, 
		@TBL_ProcedureParameters = @TBL_ProcedureParameters ;
'
EXEC ( @V_Cmd );

-- Uninstall all procedures
SET @V_Cmd = '
	DROP PROCEDURE ' + QUOTENAME(@V_MainName) + '.[InstallSubscription] ;
	DROP PROCEDURE ' + QUOTENAME(@V_MainName) + '.[ReceiveSubscription] ;
	DROP PROCEDURE ' + QUOTENAME(@V_MainName) + '.[UninstallSubscription] ;
'
EXEC ( @V_Cmd );

-- Remove Table
IF EXISTS(
	SELECT SysTables.name
		FROM sys.tables AS SysTables
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysTables.schema_id
		WHERE SysTables.name = 'SubscribersTable'
			AND SysSchemas.name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP TABLE ' + QUOTENAME(@V_MainName) + '.[SubscribersTable] ;
		'
		EXEC ( @V_Cmd );
	END

-- Remove Service
DECLARE @V_ServiceName SYSNAME
SET @V_ServiceName = 'Service' + @V_MainName
IF EXISTS(
	SELECT name
		FROM sys.services 
		WHERE name = @V_ServiceName)
	BEGIN
		SET @V_Cmd = '
			DROP SERVICE ' + QUOTENAME(@V_ServiceName) + '; 
		'
		EXEC ( @V_Cmd );
	END

-- Remove Queue
DECLARE @V_QueueName SYSNAME
SET @V_QueueName = 'Queue' + @V_MainName
IF EXISTS (
	SELECT name
		FROM sys.service_queues 
		WHERE name = @V_QueueName)
	BEGIN
		SET @V_Cmd = '
			DROP QUEUE ' + QUOTENAME(@V_MainName) + '.' + QUOTENAME(@V_QueueName) + ';
		'
		EXEC ( @V_Cmd );
	END

-- Remove TYPE_ParametersType
IF EXISTS (
	SELECT name 
	FROM sys.types 
	WHERE 
		is_table_type = 1 AND 
		name = 'TYPE_ParametersType')
	BEGIN
		DROP TYPE [dbo].[TYPE_ParametersType];
	END

-- Remove shema
IF EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP SCHEMA ' + QUOTENAME(@V_MainName) + ';
		'
		EXEC( @V_Cmd );
	END

-- Remove user
IF EXISTS (
	SELECT name
	FROM sys.database_principals
	WHERE 
		name = @V_MainName AND
		type = 'S')
	BEGIN
		SET @V_Cmd = '
			DROP USER ' + QUOTENAME(@V_MainName) + ';
		'
		EXEC( @V_Cmd );
	END

-- Remove login
IF EXISTS (
	SELECT name 
	FROM master.sys.server_principals
	WHERE name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP LOGIN ' + QUOTENAME(@V_MainName) + ';
		'
		EXEC( @V_Cmd );
	END