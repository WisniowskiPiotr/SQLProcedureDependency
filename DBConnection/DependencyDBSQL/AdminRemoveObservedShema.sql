DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_SchemaName SYSNAME = '{1}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

SET @V_Cmd = '
	REVOKE ALTER ON SCHEMA::' + QUOTENAME( @V_SchemaName ) + ' TO ' + QUOTENAME(@V_MainName)  + ';
	REVOKE SELECT ON SCHEMA::' + QUOTENAME( @V_SchemaName ) + ' TO ' + QUOTENAME(@V_MainName)  + ';
'
EXEC( @V_Cmd );