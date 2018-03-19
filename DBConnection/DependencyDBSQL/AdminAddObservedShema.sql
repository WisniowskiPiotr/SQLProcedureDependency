DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_SchemaName SYSNAME = '{1}';
DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

SET @V_Cmd = '
	GRANT ALTER ON SCHEMA::' + QUOTENAME( @V_SchemaName ) + ' TO ' + QUOTENAME(@V_UserName)  + ';
	GRANT SELECT ON SCHEMA::' + QUOTENAME( @V_SchemaName ) + ' TO ' + QUOTENAME(@V_UserName)  + ';
'
EXEC( @V_Cmd );