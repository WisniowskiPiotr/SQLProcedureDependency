USE [test_sgdb]
GO

/****** Object:  UserDefinedTableType [dbo].[SpParametersType]    Script Date: 2017-11-28 13:37:13 ******/
CREATE TYPE [dbo].[SpParametersType] AS TABLE(
	[PName] [nvarchar](100) NULL,
	[Ptype] [nvarchar](20) NULL,
	[PValue] [nvarchar](100) NULL
)
GO


