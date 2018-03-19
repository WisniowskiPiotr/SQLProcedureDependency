CREATE SERVICE [ServiceDependencyDB]
    AUTHORIZATION [dbo]
    ON QUEUE [S_DependencyDB].[Q_DependencyDB]
    ([DEFAULT]);

