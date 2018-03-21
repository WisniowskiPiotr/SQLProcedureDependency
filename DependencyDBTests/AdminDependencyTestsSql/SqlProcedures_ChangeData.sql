DECLARE @V_MainName SYSNAME = '{0}';
DECLARE @V_Cmd NVARCHAR(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON


DECLARE @V_ReferencedSchema SYSNAME = '{1}';
DECLARE @V_ReferencedTable SYSNAME = '{2}';

SET @V_Cmd = '
	UPDATE ' + QUOTENAME( @V_ReferencedSchema ) + '.' + QUOTENAME( @V_ReferencedTable ) + '
	SET column2 = column2 + 1
	WHERE column1 = 1 ;
	INSERT INTO ' + QUOTENAME( @V_ReferencedSchema ) + '.' + QUOTENAME( @V_ReferencedTable ) + ' ( column1, column2 )
	VALUES ( null, 1);

	'

EXECUTE ( @V_Cmd ) ;