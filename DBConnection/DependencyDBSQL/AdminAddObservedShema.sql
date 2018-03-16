DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
DECLARE @V_SchemaName SYSNAME = '{1}';

SET @V_Cmd = '
	GRANT ALTER ON SCHEMA::' + QUOTENAME( @V_SchemaName ) + ' TO ' + QUOTENAME(@V_MainName)  + ';
	GRANT SELECT ON SCHEMA::' + QUOTENAME( @V_SchemaName ) + ' TO ' + QUOTENAME(@V_MainName)  + ';
'
EXEC( @V_Cmd );