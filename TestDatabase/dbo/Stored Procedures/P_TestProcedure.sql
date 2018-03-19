
CREATE PROCEDURE [dbo].[P_TestProcedure]
	@param1 int = 0,
	@param2 int
AS
	SELECT @param1, @param2, TBL_TestTable.column1, TBL_TestTable.column2
	FROM dbo.TBL_TestTable AS TBL_TestTable
	WHERE TBL_TestTable.column1 is not null
RETURN 0
