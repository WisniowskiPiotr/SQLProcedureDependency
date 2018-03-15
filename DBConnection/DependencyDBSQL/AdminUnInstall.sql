DECLARE @V_MainName sysname = '{0}';
DECLARE @V_Cmd nvarchar(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- Remove SpParametersType
IF EXISTS (
	SELECT name 
	FROM sys.types 
	WHERE 
		is_table_type = 1 AND 
		name = 'SpParametersType')
	BEGIN
		SET @V_Cmd = '
			DROP TYPE ' + quotename(@V_MainName)  + '.[SpParametersType];
		'
		EXEC( @V_Cmd );
	END

-- Remove shema
IF EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP SCHEMA ' + quotename(@V_MainName) + ';
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
			DROP USER ' + quotename(@V_MainName) + ';
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
			DROP LOGIN ' + quotename(@V_MainName) + ';
		'
		EXEC( @V_Cmd );
	END