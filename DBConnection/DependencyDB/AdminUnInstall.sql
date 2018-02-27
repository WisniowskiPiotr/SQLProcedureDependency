DECLARE @V_MainName sysname = 'DependencyDB'
DECLARE @V_Cmd nvarchar(2000)

-- Do not disable brooker as other things in db may require it
-- do not drop Route as it may be required by other things
-- TODO remove active subscriptions

-- Remove UserDefined type required by DependencyDb
SET @V_Cmd = '
	IF EXISTS (
		SELECT name 
		FROM sys.types 
		WHERE 
			is_table_type = 1 AND 
			name = ''SpParametersType'')
	DROP TYPE ' + quotename(@V_MainName)  + '.[SpParametersType]
	GO'
EXEC( @V_Cmd);
GO

-- Remove user
IF EXISTS (
	SELECT name
	FROM sys.database_principals
	WHERE 
		name = @V_MainName AND
		type = 'S')
	BEGIN
		SET @V_Cmd = '
			DROP USER ' + quotename(@V_MainName)
		EXEC( @V_Cmd);
	END
GO


-- Remove shema
IF EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_MainName)
	BEGIN
		-- The schema must be run in its own batch!
		SET @V_Cmd = '
			DROP SCHEMA ' + quotename(@V_MainName)
		EXEC( @V_Cmd );
	END
GO

-- Remove DependencyDB login
IF EXISTS (
	SELECT name 
	FROM master.sys.server_principals
	WHERE name = @V_MainName)
	BEGIN
		SET @V_Cmd = '
			DROP LOGIN ' + quotename(@V_MainName)
		EXEC( @V_Cmd );
	END
GO