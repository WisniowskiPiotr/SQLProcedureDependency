CREATE TYPE [dbo].[TYPE_ParametersType] AS TABLE (
    [PName]  NVARCHAR (100) NULL,
    [PType]  NVARCHAR (20)  NULL,
    [PValue] NVARCHAR (100) NULL);


GO
GRANT EXECUTE
    ON TYPE::[dbo].[TYPE_ParametersType] TO [U_DependencyDB];

