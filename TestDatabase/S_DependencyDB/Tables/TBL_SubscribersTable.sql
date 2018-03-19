CREATE TABLE [S_DependencyDB].[TBL_SubscribersTable] (
    [C_SubscribersTableId]  INT            IDENTITY (1, 1) NOT NULL,
    [C_SubscriberString]    NVARCHAR (200) NOT NULL,
    [C_SubscriptionHash]    INT            NOT NULL,
    [C_ProcedureSchemaName] [sysname]      NOT NULL,
    [C_ProcedureName]       [sysname]      NOT NULL,
    [C_ProcedureParameters] NVARCHAR (MAX) NOT NULL,
    [C_TriggerNames]        NVARCHAR (MAX) NOT NULL,
    [C_ValidTill]           DATETIME       NOT NULL,
    CONSTRAINT [CS_TBL_SubscribersTable_C_SubscribersTableId] PRIMARY KEY CLUSTERED ([C_SubscribersTableId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IND_DependencyDB_TBL_SubscribersTable_C_SubscriptionHash]
    ON [S_DependencyDB].[TBL_SubscribersTable]([C_SubscriptionHash] ASC);


GO
CREATE NONCLUSTERED INDEX [IND_DependencyDB_TBL_SubscribersTable_C_ValidTill]
    ON [S_DependencyDB].[TBL_SubscribersTable]([C_ValidTill] ASC);

