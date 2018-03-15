DECLARE @V_MainName sysname = '{0}';
DECLARE @V_Cmd nvarchar(max);
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

-- Create SpParametersType
IF NOT EXISTS (
	SELECT name 
	FROM sys.types 
	WHERE 
		is_table_type = 1 AND 
		name = 'SpParametersType')
	BEGIN
		SET @V_Cmd = '
			CREATE TYPE ' + quotename(@V_MainName)  + '.[SpParametersType] 
				AS TABLE(
				[PName] [nvarchar](100) NULL,
				[Ptype] [nvarchar](20) NULL,
				[PValue] [nvarchar](100) NULL);
		'
		EXEC( @V_Cmd );
	END

-- Grant Provilages
SET @V_Cmd = '
	ALTER AUTHORIZATION ON SCHEMA::' + quotename(@V_MainName)  + ' TO  ' + quotename(@V_MainName) + ';
	GRANT CREATE PROCEDURE TO ' + quotename(@V_MainName)  + '; 
	--GRANT CREATE SERVICE TO ' + quotename(@V_MainName)  + ';
	--GRANT CREATE QUEUE TO ' + quotename(@V_MainName)  + ';
	GRANT SUBSCRIBE QUERY NOTIFICATIONS TO ' + quotename(@V_MainName)  + ';
	GRANT CONTROL ON CONTRACT::[DEFAULT] TO ' + quotename(@V_MainName)  + ';
	--GRANT EXECUTE ON TYPE::SpParametersType TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd );
