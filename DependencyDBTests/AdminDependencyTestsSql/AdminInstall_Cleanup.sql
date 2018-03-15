DECLARE @V_MainName sysname = '{0}'
DECLARE @V_Cmd nvarchar(max)

-- Drop Type
IF EXISTS (
	SELECT name 
	FROM sys.types 
	WHERE 
		is_table_type = 1 AND 
		name = 'SpParametersType')
	BEGIN
		SET @V_Cmd = '
			DROP TYPE ' + quotename(@V_MainName) + '.[SpParametersType];'
		EXEC( @V_Cmd);
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
