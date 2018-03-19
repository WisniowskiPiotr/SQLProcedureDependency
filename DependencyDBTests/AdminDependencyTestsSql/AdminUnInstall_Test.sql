DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_LoginName SYSNAME = 'L_' + @V_MainName;
DECLARE @V_SchemaName SYSNAME = 'S_' + @V_MainName;
DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
DECLARE @V_ServiceName SYSNAME = 'Service' + @V_MainName;

-- Drop Type
IF NOT EXISTS(
		SELECT SysTables.name
		FROM sys.tables AS SysTables
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysTables.schema_id
			AND SysSchemas.name = @V_SchemaName
		WHERE SysTables.name = 'TBL_SubscribersTable'
	)
	AND
	NOT EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND SysSchemas.name = @V_SchemaName
		WHERE SysProcedures.name = 'P_InstallSubscription'
	)
	AND
	NOT EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND SysSchemas.name = @V_SchemaName
		WHERE SysProcedures.name = 'P_ReceiveSubscription'
	)
	AND
	NOT EXISTS (
		SELECT SysProcedures.name
		FROM sys.procedures AS SysProcedures
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysProcedures.schema_id
			AND SysSchemas.name = @V_SchemaName
		WHERE SysProcedures.name = 'P_UninstallSubscription'
	)
	AND
	NOT EXISTS (
		SELECT SysTypes.name 
		FROM sys.types AS SysTypes
		INNER JOIN sys.schemas AS SysSchemas
			ON SysSchemas.schema_id = SysTypes.schema_id
			AND SysSchemas.name = 'dbo'
		WHERE 
			is_table_type = 1 
			AND SysTypes.name = 'TYPE_ParametersType')
	AND
	NOT EXISTS (
		SELECT name
		FROM sys.database_principals
		WHERE 
			name = @V_UserName AND
			type = 'S')
	AND 
	NOT EXISTS (
		SELECT name  
		FROM sys.schemas
		WHERE name = @V_SchemaName)
	AND
	NOT EXISTS (
		SELECT name 
		FROM master.sys.server_principals
		WHERE name = @V_LoginName)
	AND
	NOT EXISTS(
	SELECT name
		FROM sys.services 
		WHERE name = @V_ServiceName)
	AND
	NOT EXISTS (
	SELECT name
		FROM sys.service_queues 
		WHERE name = @V_QueueName)
	BEGIN
		SELECT 1
	END
ELSE
	BEGIN
		SELECT 0
	END
