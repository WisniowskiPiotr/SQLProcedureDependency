DECLARE @V_MainName sysname = '{0}';
DECLARE @V_Cmd nvarchar(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

SET @V_Cmd = '
	GRANT ALTER ON SCHEMA::{1} TO ' + quotename(@V_MainName)  + ';
	GRANT SELECT ON SCHEMA::{1} TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd );