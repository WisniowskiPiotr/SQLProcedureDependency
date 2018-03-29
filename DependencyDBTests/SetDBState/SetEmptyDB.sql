
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_DBName SYSNAME = '{0}';

-- drop DB
IF( DB_ID( @V_DBName ) IS NOT NULL )
	BEGIN
		SET @V_Cmd = '
			ALTER DATABASE ' + QUOTENAME( @V_DBName ) + '
			SET SINGLE_USER WITH ROLLBACK IMMEDIATE ;
		' ;
		EXEC ( @V_Cmd );
		SET @V_Cmd = '
			DROP DATABASE ' + QUOTENAME( @V_DBName ) + ' ; 
		' ;
		EXEC ( @V_Cmd );
	END

-- create DB
SET @V_Cmd = '
	CREATE DATABASE ' + QUOTENAME( @V_DBName ) + ' ; 
' ;
EXEC ( @V_Cmd );

-- switch to DB
USE [{0}];

-- create two tables
CREATE TABLE [dbo].[TBL_FirstTable] (
    [C_ID] INT IDENTITY (1, 1) NOT NULL,
    [C_Column] INT NULL
);
CREATE TABLE [dbo].[TBL_SecondTable] (
    [C_ID] INT IDENTITY (1, 1) NOT NULL,
    [C_Column] INT NULL
);

-- create error procedure
SET @V_Cmd = '
	CREATE PROCEDURE [dbo].[P_TestSetProcedure]
		@V_Param1 int = null,
		@V_Param2 int = null,
		@V_Insert1 bit = 0,
		@V_Insert2 bit = 0,
		@V_Delete1 bit = 0,
		@V_Delete2 bit = 0
	AS
	BEGIN

		SET ANSI_NULLS ON;
		SET QUOTED_IDENTIFIER ON;
		SET NOCOUNT ON; 

		IF( @V_Insert1 = 1 )
			BEGIN
				INSERT INTO [dbo].[TBL_FirstTable] ( [C_Column] )
				VALUES( @V_Param1 ) ;
			END
		IF( @V_Insert2 = 1 )
			BEGIN
				INSERT INTO [dbo].[TBL_SecondTable] ( [C_Column] )
				VALUES( @V_Param2 ) ;
			END

		IF( @V_Delete1 = 1 )
			BEGIN
				DELETE FROM [dbo].[TBL_FirstTable]
				WHERE [C_Column] = @V_Param1 ;
			END
		IF( @V_Delete2 = 1 )
			BEGIN
				DELETE FROM [dbo].[TBL_SecondTable] 
				WHERE [C_Column] = @V_Param2 ;
			END

		SELECT 
			[TBL_FirstTable].[C_Column], 
			[TBL_SecondTable].[C_Column]
		FROM [dbo].[TBL_FirstTable] AS TBL_FirstTable
		INNER JOIN dbo.TBL_SecondTable AS TBL_SecondTable
			ON TBL_FirstTable.C_Column = TBL_SecondTable.C_Column
		WHERE TBL_FirstTable.C_Column = ISNULL( @V_Param1, TBL_FirstTable.C_Column )
			AND TBL_SecondTable.C_Column = ISNULL( @V_Param2, TBL_SecondTable.C_Column );
		RETURN ;
	END

' ;
EXEC ( @V_Cmd );

-- create procedure
SET @V_Cmd = '
	CREATE PROCEDURE [dbo].[P_TestGetProcedure]
		@V_Param1 int = null,
		@V_Param2 int = null
	AS
	BEGIN

		SET ANSI_NULLS ON;
		SET QUOTED_IDENTIFIER ON;
		SET NOCOUNT ON; 

		SELECT 
			[TBL_FirstTable].[C_Column], 
			[TBL_SecondTable].[C_Column]
		FROM [dbo].[TBL_FirstTable] AS TBL_FirstTable
		INNER JOIN dbo.TBL_SecondTable AS TBL_SecondTable
			ON TBL_FirstTable.C_Column = TBL_SecondTable.C_Column
		WHERE TBL_FirstTable.C_Column = ISNULL( @V_Param1, TBL_FirstTable.C_Column )
			AND TBL_SecondTable.C_Column = ISNULL( @V_Param2, TBL_SecondTable.C_Column );
		RETURN ;
	END

' ;
EXEC ( @V_Cmd );

-- enable brooker
SET @V_Cmd = '
	ALTER DATABASE ' + QUOTENAME( @V_DBName ) + '
	SET enable_broker 
	WITH ROLLBACK IMMEDIATE;
' ;
EXEC ( @V_Cmd );
