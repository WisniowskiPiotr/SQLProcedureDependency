DECLARE @V_MainName sysname = '{0}';
DECLARE @V_Cmd nvarchar(max);
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- Drop Type
IF EXISTS (
		SELECT column1 
		FROM dbo.testTable)
	BEGIN
		SELECT 1
	END
ELSE
	BEGIN
		SELECT 0
	END
