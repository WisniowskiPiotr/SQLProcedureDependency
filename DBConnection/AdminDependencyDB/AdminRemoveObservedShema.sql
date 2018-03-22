
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @V_DBName SYSNAME = '{0}' ;
DECLARE @V_MainName SYSNAME = '{1}' ;
DECLARE @V_ObservedSchemaName SYSNAME = '{2}' ;

-- switch to DB
USE [{0}];

DECLARE @V_UserName SYSNAME = @V_MainName;

-- switch to DB
SET @V_Cmd = '
	USE ' + QUOTENAME( @V_DBName ) + ' ; 
' ;
EXEC ( @V_Cmd );

-- revoke
SET @V_Cmd = '
	REVOKE ALTER ON SCHEMA::' + QUOTENAME( @V_ObservedSchemaName ) + ' TO ' + QUOTENAME(@V_UserName)  + ';
	REVOKE SELECT ON SCHEMA::' + QUOTENAME( @V_ObservedSchemaName ) + ' TO ' + QUOTENAME(@V_UserName)  + ';
'
EXEC( @V_Cmd );