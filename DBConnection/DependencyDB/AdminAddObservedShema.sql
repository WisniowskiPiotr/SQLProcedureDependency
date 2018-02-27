DECLARE @V_MainName sysname = 'DependencyDB'

SET @V_Cmd = '
	GRANT ALTER ON SCHEMA::{0} TO ' + quotename(@V_MainName)  + ';
	GRANT SELECT ON SCHEMA::{0} TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd);
GO