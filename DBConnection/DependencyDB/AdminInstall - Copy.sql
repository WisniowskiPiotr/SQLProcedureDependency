DECLARE @V_MainName sysname = 'DependencyDB'
DECLARE @V_Cmd nvarchar(2000)

-- Enable brooker
DECLARE @V_BrokerEnabled bit
SELECT @V_BrokerEnabled = is_broker_enabled
	FROM sys.databases
	WHERE name = DB_NAME()
IF (@V_BrokerEnabled != 1)
	BEGIN
		ALTER DATABASE DB_NAME 
			SET NEW_BROKER 
			WITH ROLLBACK IMMEDIATE;
	END
--GO

-- Create or ReCreate DependencyDB login
BEGIN TRANSACTION
	IF EXISTS (
		SELECT name 
		FROM master.sys.server_principals
		WHERE name = @V_MainName)
		BEGIN
			SET @V_Cmd = '
				DROP LOGIN ' + quotename(@V_MainName)
			EXEC( @V_Cmd );
		END
	--GO
	SET @V_Cmd = '
		CREATE LOGIN ' + quotename(@V_MainName) + '
			WITH PASSWORD = ''{0}'', 
			CHECK_EXPIRATION = OFF, 
			CHECK_POLICY = OFF'
	EXEC @V_Cmd
COMMIT TRANSACTION
--GO

-- Create shema
IF NOT EXISTS (
	SELECT name  
	FROM sys.schemas
	WHERE name = @V_MainName)
	BEGIN
		-- The schema must be run in its own batch!
		SET @V_Cmd = '
			CREATE SCHEMA ' + quotename(@V_MainName)
		EXEC( @V_Cmd );
	END
--GO

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
				WITH DEFAULT_SCHEMA = ' + quotename(@V_MainName) 
		EXEC( @V_Cmd);
	END
--GO

-- Grant Provilages
SET @V_Cmd = '
	ALTER AUTHORIZATION ON SCHEMA::' + quotename(@V_MainName)  + ' TO  ' + quotename(@V_MainName) + ';
	GRANT CREATE PROCEDURE TO ' + quotename(@V_MainName)  + '; 
	--GRANT CREATE SERVICE TO ' + quotename(@V_MainName)  + ';
	--GRANT CREATE QUEUE TO ' + quotename(@V_MainName)  + ';
	GRANT SUBSCRIBE QUERY NOTIFICATIONS TO ' + quotename(@V_MainName)  + ';
	GRANT CONTROL ON CONTRACT::[DEFAULT] TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd);
--GO

-- Create Route
IF NOT EXISTS (
	SELECT name
	FROM sys.routes
	WHERE name = 'AutoCreatedLocal')
	BEGIN
		CREATE ROUTE [AutoCreatedLocal] WITH ADDRESS = N'LOCAL';
	END
--GO

-- Create UserDefined type required by DependencyDb
SET @V_Cmd = '
	IF NOT EXISTS (
		SELECT name 
		FROM sys.types 
		WHERE 
			is_table_type = 1 AND 
			name = ''SpParametersType'')
	CREATE TYPE ' + quotename(@V_MainName)  + '.[SpParametersType] AS TABLE(
		[PName] [nvarchar](100) NULL,
		[Ptype] [nvarchar](20) NULL,
		[PValue] [nvarchar](100) NULL
	)
	--GO
	GRANT EXECUTE ON TYPE::SpParametersType TO ' + quotename(@V_MainName)  + ';
	--GO'
EXEC( @V_Cmd);
--GO



