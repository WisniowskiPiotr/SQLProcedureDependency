CREATE 
PROCEDURE [{2}].[P_UninstallSubscription]
	@V_SubscriberString NVARCHAR(200) = null,
	@V_SubscriptionHash INT = null,
	@V_ProcedureSchemaName SYSNAME = null,
	@V_ProcedureName SYSNAME = null,
	@TBL_ProcedureParameters dbo.TYPE_ParametersType READONLY,
	@V_NotificationValidFor INT = 432000 -- 5 days to receive notification
AS
BEGIN

	SET NOCOUNT ON; 
	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Cmd NVARCHAR(max);

	DECLARE @V_LoginName SYSNAME = 'L_' + @V_MainName;
	DECLARE @V_SchemaName SYSNAME = '{2}';
	DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
	DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
	DECLARE @V_ServiceName SYSNAME = '{1}';

	DECLARE @V_ProcedureParametersXlm NVARCHAR(max) ;
	SET @V_ProcedureParametersXlm = '<schema name="' + @V_ProcedureSchemaName + '">'+ '<procedure name="' + @V_ProcedureName + '">' + ISNULL(
		(SELECT 
				PName as name,
				PType as type,
				PValue as value
			FROM @TBL_ProcedureParameters 
			FOR XML PATH('parameter'))
		,'') + '</procedure>' + '</schema>' ;
	IF EXISTS (
		SELECT 
			TBL_ProcedureParameters.PName
		FROM @TBL_ProcedureParameters AS TBL_ProcedureParameters
		WHERE TBL_ProcedureParameters.PName = '@V_RemoveAllParameters'
			AND TBL_ProcedureParameters.PValue != '0')
		BEGIN
			SET @V_ProcedureParametersXlm = null ;
		END

	DECLARE @TBL_SubscribersToBeRemoved TABLE (
		[C_SubscribersTableId] INT NOT NULL,
		[C_SubscriberString] NVARCHAR(200) NOT NULL,
		[C_SubscriptionHash] INT NOT NULL,
		[C_ProcedureSchemaName] SYSNAME NOT NULL,
		[C_ProcedureName] SYSNAME NOT NULL,
		[C_ProcedureParameters] NVARCHAR(max) NOT NULL,
		[C_TriggerNames] NVARCHAR(max) NOT NULL,
		[C_ValidTill] DATETIME NOT NULL,
		[C_DeleteTrigger] BIT NOT NULL
	) ;
	DELETE FROM [{2}].[TBL_SubscribersTable]
	OUTPUT 
		DELETED.[C_SubscribersTableId] ,
		DELETED.[C_SubscriberString] ,
		DELETED.[C_SubscriptionHash] ,
		DELETED.[C_ProcedureSchemaName] ,
		DELETED.[C_ProcedureName] ,
		DELETED.[C_ProcedureParameters] ,
		DELETED.[C_TriggerNames] ,
		DELETED.[C_ValidTill] ,
		0 
		INTO @TBL_SubscribersToBeRemoved
	WHERE ( TBL_SubscribersTable.C_SubscriberString = ISNULL( @V_SubscriberString, TBL_SubscribersTable.C_SubscriberString)
		AND  TBL_SubscribersTable.C_SubscriptionHash = ISNULL( @V_SubscriptionHash, TBL_SubscribersTable.C_SubscriptionHash)
		AND  TBL_SubscribersTable.C_ProcedureSchemaName = ISNULL( @V_ProcedureSchemaName, TBL_SubscribersTable.C_ProcedureSchemaName)
		AND  TBL_SubscribersTable.C_ProcedureName = ISNULL( @V_ProcedureName, TBL_SubscribersTable.C_ProcedureName)
		AND  TBL_SubscribersTable.C_ProcedureParameters = ISNULL( @V_ProcedureParametersXlm, TBL_SubscribersTable.C_ProcedureParameters)
		) OR  TBL_SubscribersTable.C_ValidTill < GETDATE() ;

	UPDATE TBL_SubscribersToBeRemoved 
	SET TBL_SubscribersToBeRemoved.C_DeleteTrigger = 1
	FROM @TBL_SubscribersToBeRemoved AS TBL_SubscribersToBeRemoved
	WHERE NOT EXISTS (
		SELECT C_SubscribersTableId
		FROM [{2}].[TBL_SubscribersTable]
		WHERE TBL_SubscribersTable.C_SubscriptionHash = TBL_SubscribersToBeRemoved.C_SubscriptionHash
		AND  TBL_SubscribersTable.C_ProcedureSchemaName = TBL_SubscribersToBeRemoved.C_ProcedureSchemaName
		AND  TBL_SubscribersTable.C_ProcedureName = TBL_SubscribersToBeRemoved.C_ProcedureName
		AND  TBL_SubscribersTable.C_ProcedureParameters = TBL_SubscribersToBeRemoved.C_ProcedureParameters
	) ;

	-- for each affected table
	DECLARE @V_RemovedSubscriberString NVARCHAR(max) ;
	DECLARE @V_ProcedureParameters NVARCHAR(max) ;
	DECLARE @V_TriggerNames NVARCHAR(max) ;
	DECLARE @V_Message NVARCHAR(MAX) ;
	DECLARE @V_RemoveTriggers BIT = 0 ;
	DECLARE @V_ReferencedTableType SYSNAME ;

	DECLARE CU_SubscribersToBeRemovedCursor CURSOR FOR
		SELECT TBL_SubscribersToBeRemoved.C_SubscriberString,
			TBL_SubscribersToBeRemoved.C_ProcedureParameters,
			TBL_SubscribersToBeRemoved.C_TriggerNames,
			TBL_SubscribersToBeRemoved.C_DeleteTrigger
		FROM @TBL_SubscribersToBeRemoved AS TBL_SubscribersToBeRemoved
		GROUP BY TBL_SubscribersToBeRemoved.C_SubscriberString,
			TBL_SubscribersToBeRemoved.C_ProcedureParameters,
			TBL_SubscribersToBeRemoved.C_TriggerNames,
			TBL_SubscribersToBeRemoved.C_DeleteTrigger;

	OPEN CU_SubscribersToBeRemovedCursor ;
	FETCH NEXT FROM CU_SubscribersToBeRemovedCursor 
		INTO @V_RemovedSubscriberString, 
			@V_ProcedureParameters, 
			@V_TriggerNames,
			@V_RemoveTriggers ;
	WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Notify subscriber
			SET @V_Message = '<unsubscribed subscriberstring="' + @V_RemovedSubscriberString + '">'
			SET @V_Message = @V_Message + @V_ProcedureParameters
			SET @V_Message = @V_Message + '</unsubscribed>'

			DECLARE @V_ConvHandle UNIQUEIDENTIFIER
			BEGIN DIALOG @V_ConvHandle 
				FROM SERVICE [{1}]
				TO SERVICE '[{1}]'
				ON CONTRACT [DEFAULT] 
				WITH ENCRYPTION = OFF, 
				LIFETIME = @V_NotificationValidFor ; 
			SEND ON CONVERSATION @V_ConvHandle 
				MESSAGE TYPE [DEFAULT] (@V_Message);
			END CONVERSATION @V_ConvHandle;

			-- Drop Triggers
			IF (@V_RemoveTriggers = 1)
				BEGIN
					DECLARE @V_TriggerName SYSNAME ;
					DECLARE @V_TableName SYSNAME ;
					DECLARE @V_TableSchemaName SYSNAME ;
					DECLARE CU_TriggersToBeRemovedCursor CURSOR FOR
						SELECT TBL_Triggers.name AS C_TriggerName,
							TBL_Objects.name AS C_TableName,
							TBL_Schemas.name AS C_TableSchemaName
						FROM STRING_SPLIT( @V_TriggerNames , ';') AS TBL_TriggerNames
						INNER JOIN sys.triggers AS TBL_Triggers
							ON QUOTENAME( TBL_Triggers.name ) = TBL_TriggerNames.value
						INNER JOIN sys.objects AS TBL_Objects
							ON TBL_Objects.object_id = TBL_Triggers.parent_id
							AND TBL_Objects.type_desc = 'USER_TABLE'
						INNER JOIN sys.schemas AS TBL_Schemas
							ON TBL_Schemas.schema_id = TBL_Objects.schema_id
						GROUP BY TBL_Triggers.name,
							TBL_Objects.name,
							TBL_Schemas.name ;

					OPEN CU_TriggersToBeRemovedCursor ;
					FETCH NEXT FROM CU_TriggersToBeRemovedCursor 
						INTO @V_TriggerName,
							@V_TableName,
							@V_TableSchemaName ;
					WHILE @@FETCH_STATUS = 0 
						BEGIN
							BEGIN TRANSACTION 
							-- lock table
							SET @V_Cmd = '
								DECLARE @V_Dummy int
								SELECT TOP 1 
									@V_Dummy = 1 
								FROM ' + QUOTENAME( @V_TableSchemaName ) + '.' + QUOTENAME( @V_TableName ) + '
								WITH (UPDLOCK, TABLOCKX, HOLDLOCK) ;
							' ;
							EXEC sp_executesql @V_Cmd

							SET @V_Cmd = '
								DROP TRIGGER ' + QUOTENAME( @V_TriggerName ) + ' ; '
							EXEC sp_executesql @V_Cmd

							COMMIT TRANSACTION;

							FETCH NEXT FROM CU_TriggersToBeRemovedCursor 
								INTO @V_TriggerName,
									@V_TableName,
									@V_TableSchemaName ;
						END
					CLOSE CU_TriggersToBeRemovedCursor ;
					DEALLOCATE CU_TriggersToBeRemovedCursor ;

					SET @V_ReferencedTableType = 'TYPE_' + @V_TableSchemaName + '_' + @V_TableName;
					IF EXISTS (
						SELECT SysTypes.name 
						FROM sys.types AS SysTypes
						INNER JOIN sys.schemas AS SysSchemas
							ON SysSchemas.schema_id = SysTypes.schema_id
							AND SysSchemas.name = @V_TableSchemaName
						WHERE 
							SysTypes.is_table_type = 1  
							AND SysTypes.name = @V_TableName
					)
						BEGIN
							SET @V_Cmd = '
								DROP TYPE ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + ' ; ' ;
							EXEC sp_executesql @V_Cmd ;
						END
			END

			FETCH NEXT FROM CU_SubscribersToBeRemovedCursor 
				INTO @V_RemovedSubscriberString, 
					@V_ProcedureParameters, 
					@V_TriggerNames ;
		END
	CLOSE CU_SubscribersToBeRemovedCursor ;
	DEALLOCATE CU_SubscribersToBeRemovedCursor ;

	RETURN 0 ;
END ;


