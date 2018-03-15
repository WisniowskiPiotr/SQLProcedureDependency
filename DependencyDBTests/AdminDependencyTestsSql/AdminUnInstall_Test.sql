DECLARE @V_MainName sysname = '{0}';
DECLARE @V_Cmd nvarchar(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- Drop Type
IF NOT EXISTS (
		SELECT name 
		FROM sys.types 
		WHERE 
			is_table_type = 1 AND 
			name = 'SpParametersType')
	AND
	NOT EXISTS (
		SELECT name
		FROM sys.database_principals
		WHERE 
			name = @V_MainName AND
			type = 'S')
	AND 
	NOT EXISTS (
		SELECT name  
		FROM sys.schemas
		WHERE name = @V_MainName)
	AND
	NOT EXISTS (
		SELECT name 
		FROM master.sys.server_principals
		WHERE name = @V_MainName)
	BEGIN
		SELECT 1
	END
ELSE
	BEGIN
		SELECT 0
	END
