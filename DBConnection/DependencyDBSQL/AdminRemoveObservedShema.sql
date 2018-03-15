DECLARE @V_MainName sysname = 'DependencyDB'

SET @V_Cmd = '
	REVOKE ALTER ON SCHEMA::{0} TO ' + quotename(@V_MainName)  + ';
	REVOKE SELECT ON SCHEMA::{0} TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd);
GO