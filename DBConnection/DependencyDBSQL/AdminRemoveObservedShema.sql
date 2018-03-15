DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

SET @V_Cmd = '
	REVOKE ALTER ON SCHEMA::{1} TO ' + quotename(@V_MainName)  + ';
	REVOKE SELECT ON SCHEMA::{1} TO ' + quotename(@V_MainName)  + ';
'
EXEC( @V_Cmd );