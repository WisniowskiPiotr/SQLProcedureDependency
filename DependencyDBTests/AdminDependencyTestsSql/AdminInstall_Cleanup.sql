DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- Uninstall all triggers
DECLARE @V_TriggerName SYSNAME ;
DECLARE CU_TriggersCursor CURSOR FOR
	SELECT TBL_Triggers.name
	FROM sys.triggers AS TBL_Triggers
	WHERE TBL_Triggers.name LIKE @V_MainName + '%' ;

OPEN CU_TriggersCursor ;
FETCH NEXT FROM CU_TriggersCursor 
	INTO @V_TriggerName ;
WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @V_Cmd = '
			DROP TRIGGER ' + QUOTENAME( @V_TriggerName ) + '
		'
		EXEC ( @V_Cmd );
		FETCH NEXT FROM CU_TriggersCursor 
			INTO @V_TriggerName ;
	END
CLOSE CU_TriggersCursor ;
DEALLOCATE CU_TriggersCursor ;

-- Uninstall all procedures
SET @V_Cmd = '
	IF EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND QUOTENAME( SysSchemas.name ) = ''' + QUOTENAME(@V_MainName) + '''
		WHERE SysProcedures.name = ''InstallSubscription''
	)
		BEGIN
			DROP PROCEDURE ' + QUOTENAME(@V_MainName) + '.[InstallSubscription] ;
		END
	IF EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND QUOTENAME( SysSchemas.name ) = ''' + QUOTENAME(@V_MainName) + '''
		WHERE SysProcedures.name = ''ReceiveSubscription''
	)
		BEGIN
			DROP PROCEDURE ' + QUOTENAME(@V_MainName) + '.[ReceiveSubscription] ;
		END
	IF EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND QUOTENAME( SysSchemas.name ) = ''' + QUOTENAME(@V_MainName) + '''
		WHERE SysProcedures.name = ''UninstallSubscription''
	)
		BEGIN
			DROP PROCEDURE ' + QUOTENAME(@V_MainName) + '.[UninstallSubscription] ;
		END
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
			DROP TABLE ' + quotename(@V_MainName) + '.[SubscribersTable] ;
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
			DROP SERVICE ' + quotename(@V_ServiceName) + '; 
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
			DROP QUEUE ' + quotename(@V_MainName) + '.' + quotename(@V_QueueName) + ';
		'
		EXEC ( @V_Cmd );
	END

-- Drop Type
IF EXISTS (
	SELECT name 
	FROM sys.types 
	WHERE 
		is_table_type = 1 AND 
		name = 'TYPE_ParametersType')
	BEGIN
		DROP TYPE [dbo].[TYPE_ParametersType];
	END

-- Drop Route
IF EXISTS (
	SELECT name
	FROM sys.routes
	WHERE name = 'AutoCreatedLocal')
	BEGIN
		DROP ROUTE [AutoCreatedLocal];
	END

-- Drop shema
IF EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP SCHEMA ' + quotename(@V_MainName)+ ';'
		EXEC( @V_Cmd );
	END

-- Drop user
IF EXISTS (
	SELECT name
	FROM sys.database_principals
	WHERE 
		name = @V_MainName AND
		type = 'S')
	BEGIN
		SET @V_Cmd = '
			DROP USER ' + quotename(@V_MainName) + ';'
		EXEC( @V_Cmd);
	END

-- Drop login
IF EXISTS (
	SELECT name 
	FROM master.sys.server_principals
	WHERE name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP LOGIN ' + quotename(@V_MainName) + ';'
		EXEC( @V_Cmd );
	END
