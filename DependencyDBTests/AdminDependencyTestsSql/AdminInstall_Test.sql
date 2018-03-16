DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

IF 
	EXISTS (
		SELECT name
		FROM sys.routes
		WHERE name = 'AutoCreatedLocal'
	)
	AND
	EXISTS (
		SELECT name
		FROM sys.database_principals
		WHERE 
			name = @V_MainName AND
			type = 'S'
	)
	AND 
	EXISTS (
		SELECT name  
		FROM sys.schemas
		WHERE name = @V_MainName
	)
	AND
	EXISTS (
		SELECT name 
		FROM master.sys.server_principals
		WHERE name = @V_MainName
	)
	AND 
	EXISTS(
		SELECT name
		FROM sys.services 
		WHERE name = 'Service' + @V_MainName
	)
	AND
	EXISTS (
		SELECT name
		FROM sys.service_queues 
		WHERE name = 'Queue' + @V_MainName
	)
	AND
	EXISTS (
		SELECT SysTypes.name 
		FROM sys.types AS SysTypes
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysTypes.schema_id
			AND SysSchemas.name = 'dbo'
		WHERE 
			is_table_type = 1 
			AND SysTypes.name = 'TYPE_ParametersType'
	)
	AND
	EXISTS(
		SELECT SysTables.name
		FROM sys.tables AS SysTables
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysTables.schema_id
			AND SysSchemas.name = @V_MainName
		WHERE SysTables.name = 'SubscribersTable'
	)
	AND
	EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND SysSchemas.name = @V_MainName
		WHERE SysProcedures.name = 'InstallSubscription'
	)
	AND
	EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND SysSchemas.name = @V_MainName
		WHERE SysProcedures.name = 'ReceiveSubscription'
	)
	AND
	EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND SysSchemas.name = @V_MainName
		WHERE SysProcedures.name = 'UninstallSubscription'
	)
	BEGIN
		SELECT 1
	END
ELSE
	BEGIN
		SELECT 0
	END