CREATE PROCEDURE [{0}].[UninstallSubscription]
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

	DECLARE @V_Queue SYSNAME ;
	SET @V_Queue =  'Queue_' + @V_MainName ;

	DECLARE @V_Service SYSNAME ;
	SET @V_Service = 'Service_' + @V_MainName ;

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
		[C_SubscribersTableId] INT IDENTITY(1,1) NOT NULL,
		[C_SubscriberString] NVARCHAR(200) NOT NULL,
		[C_SubscriptionHash] INT NOT NULL,
		[C_ProcedureSchemaName] SYSNAME NOT NULL,
		[C_ProcedureName] SYSNAME NOT NULL,
		[C_ProcedureParameters] NVARCHAR(max) NOT NULL,
		[C_TriggerNames] NVARCHAR(max) NOT NULL,
		[C_ValidTill] DATETIME NOT NULL,
		[C_DeleteTrigger] BIT NOT NULL
	) ;
	DELETE FROM [{0}].[SubscribersTable]
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
	WHERE ( SubscribersTable.C_SubscriberString = ISNULL( @V_SubscriberString, SubscribersTable.C_SubscriberString)
		AND  SubscribersTable.C_SubscriptionHash = ISNULL( @V_SubscriptionHash, SubscribersTable.C_SubscriptionHash)
		AND  SubscribersTable.C_ProcedureSchemaName = ISNULL( @V_ProcedureSchemaName, SubscribersTable.C_ProcedureSchemaName)
		AND  SubscribersTable.C_ProcedureName = ISNULL( @V_ProcedureName, SubscribersTable.C_ProcedureName)
		AND  SubscribersTable.C_ProcedureParameters = ISNULL( @V_ProcedureParametersXlm, SubscribersTable.C_ProcedureParameters)
		) OR  SubscribersTable.C_ValidTill < GETDATE() ;

	UPDATE TBL_SubscribersToBeRemoved 
	SET TBL_SubscribersToBeRemoved.C_DeleteTrigger = 1
	FROM @TBL_SubscribersToBeRemoved AS TBL_SubscribersToBeRemoved
	WHERE NOT EXISTS (
		SELECT C_SubscribersTableId
		FROM [{0}].[SubscribersTable]
		WHERE SubscribersTable.C_SubscriptionHash = TBL_SubscribersToBeRemoved.C_SubscriptionHash
		AND  SubscribersTable.C_ProcedureSchemaName = TBL_SubscribersToBeRemoved.C_ProcedureSchemaName
		AND  SubscribersTable.C_ProcedureName = TBL_SubscribersToBeRemoved.C_ProcedureName
		AND  SubscribersTable.C_ProcedureParameters = TBL_SubscribersToBeRemoved.C_ProcedureParameters
	) ;

	-- for each affected table
	DECLARE @V_SubscriberString NVARCHAR(max) ;
	DECLARE @V_ProcedureParameters NVARCHAR(max) ;
	DECLARE @V_TriggerNames NVARCHAR(max) ;
	DECLARE @V_Message NVARCHAR(MAX) ;

	DECLARE C_SubscribersToBeRemovedCursor CURSOR FOR
		SELECT TBL_SubscribersToBeRemoved.C_SubscriberString,
			TBL_SubscribersToBeRemoved.C_ProcedureParameters,
			TBL_SubscribersToBeRemoved.TriggerNames
		FROM @TBL_SubscribersToBeRemoved AS TBL_SubscribersToBeRemoved
		GROUP BY TBL_SubscribersToBeRemoved.C_SubscriberString,
			TBL_SubscribersToBeRemoved.C_ProcedureParameters,
			TBL_SubscribersToBeRemoved.TriggerNames;

	OPEN C_SubscribersToBeRemovedCursor ;
	FETCH NEXT FROM C_SubscribersToBeRemovedCursor 
		INTO @V_SubscriberString, 
			@V_ProcedureParameters, 
			@V_TriggerNames ;
	WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Notify subscriber
			SET @V_Message = '<unsubscribed subscriberstring="' + @V_SubscriberString + '">'
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
			DECLARE @V_TriggerName SYSNAME ;
			DECLARE @V_TableName SYSNAME ;
			DECLARE C_TriggersToBeRemovedCursor CURSOR FOR
				SELECT TBL_TriggerNames.value 
				FROM STRING_SPLIT( @V_TriggerNames , ';') AS TBL_TriggerNames
				GROUP BY TTBL_TriggerNames.value ;

			OPEN C_TriggersToBeRemovedCursor ;
			FETCH NEXT FROM C_TriggersToBeRemovedCursor 
				INTO @V_TriggerName ;
			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF EXISTS (
						SELECT [name]
						FROM sys.triggers
						WHERE [name] = @V_TriggerName
					)
						BEGIN
							BEGIN TRANSACTION 
							-- lock table
							SET @cmd = N'
								SELECT TOP 1 
										1 
									FROM ' + @table + N'
									WITH (UPDLOCK, TABLOCKX, HOLDLOCK) 
								'
							EXEC sp_executesql @cmd

							SET @cmd = N'
								DROP TRIGGER [' + @Trigger + N'] '
							EXEC sp_executesql @cmd

							COMMIT TRANSACTION;
						END
				END
			CLOSE C_TriggersToBeRemovedCursor ;
			DEALLOCATE C_TriggersToBeRemovedCursor ;

			FETCH NEXT FROM C_SubscribersToBeRemovedCursor 
				INTO @V_SubscriberString, 
					@V_ProcedureParameters, 
					@V_TriggerNames ;
		END
	CLOSE C_SubscribersToBeRemovedCursor ;
	DEALLOCATE C_SubscribersToBeRemovedCursor ;







	'
	
	DECLARE @V_ConvHandle UNIQUEIDENTIFIER
    --Determine the Initiator Service, Target Service and the Contract 
    BEGIN DIALOG @V_ConvHandle 
		FROM SERVICE ' + @V_Service + ' 
		TO SERVICE ''' + @V_Service + ''' 
		ON CONTRACT [DEFAULT] 
		WITH ENCRYPTION = OFF, 
		LIFETIME = ' + CAST( @V_NotificationValidFor AS NVARCHAR(200)) + '; 
	--Send the Message
	SEND ON CONVERSATION @V_ConvHandle 
		MESSAGE TYPE [DEFAULT] (@V_Message);
	--End conversation
	END CONVERSATION @V_ConvHandle;
	'




	<notification subscriberstring="">

	SET @V_Cmd = N'
		DECLARE @message NVARCHAR(MAX)
		SET @message = N''<unsubscribed subscriberstring="">''
		SET @message = @message + ''' + @ListenerProcedureParametersXlm + '''
		SET @message = @message + N''</unsubscribed>''
        DECLARE @ConvHandle UNIQUEIDENTIFIER
        --Determine the Initiator Service, Target Service and the Contract 
        BEGIN DIALOG @ConvHandle 
			FROM SERVICE ' + @ListenerService + N' 
			TO SERVICE ''' + @ListenerService + N''' 
			ON CONTRACT [DEFAULT] 
			WITH ENCRYPTION = OFF;
		--Send the Message
		SEND ON CONVERSATION @ConvHandle 
			MESSAGE TYPE [DEFAULT] (@message);
		--End conversation
		END CONVERSATION @ConvHandle;
		'
	EXEC sp_executesql @cmd

	-- drop triggers
	DECLARE @Trigger NVARCHAR(128)
	DECLARE TriggerCursor CURSOR FOR
		SELECT [name]
			FROM sys.triggers
			WHERE [name] like @ListenerAppName + N'_%_' + @ListenerProcedureName + N'_' +  @ProcedureParametersString 
	OPEN TriggerCursor
	FETCH NEXT FROM TriggerCursor
		INTO @Trigger
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @cmd = N'
				IF EXISTS (
					SELECT [name]
						FROM sys.triggers
						WHERE [name] = ''' + @Trigger + N'''
				)
				DROP TRIGGER [' + @Trigger + N'] '
			EXEC sp_executesql @cmd

			FETCH NEXT FROM TriggerCursor INTO @Trigger
		END
	CLOSE TriggerCursor;
	DEALLOCATE TriggerCursor;

	-- if no other triggers exist drop rest
	--IF NOT EXISTS (
	--	SELECT [name]
	--		FROM sys.triggers
	--		WHERE [name] like @ListenerAppName + N'_%'
	--)
	--	BEGIN
	--		DECLARE @serviceId INT
	--		SELECT @serviceId = service_id FROM sys.services 
	--			WHERE sys.services.name = @ListenerService
	--		IF @serviceId is not null
	--		BEGIN 
	--			--DECLARE @ConvHandle uniqueidentifier
	--			--DECLARE Conv CURSOR FOR
	--			--	SELECT CEP.conversation_handle 
	--			--		FROM sys.conversation_endpoints CEP
	--			--		WHERE CEP.service_id = @serviceId AND ([state] != 'CD' AND [lifetime] > GETDATE())
	--			--OPEN Conv;
	--			--FETCH NEXT FROM Conv INTO @ConvHandle;
	--			--	WHILE (@@FETCH_STATUS = 0) 
	--			--	BEGIN
 --   --					END CONVERSATION @ConvHandle;
	--			--		FETCH NEXT FROM Conv INTO @ConvHandle;
	--			--	END
	--			--CLOSE Conv;
	--			--DEALLOCATE Conv;

	--			-- Droping service.
	--			SET @cmd = N'
	--				DROP SERVICE [' + @ListenerService  + N'] '
	--			EXEC sp_executesql @cmd
	--		END

	--		-- drop queue
	--		--IF EXISTS(
	--		--		SELECT name
	--		--			FROM sys.service_queues
	--		--			WHERE name = @ListenerQueue
	--		--	)
	--		--	BEGIN
	--		--		SET @cmd = N'
	--		--			IF NOT EXISTS (
	--		--				SELECT [conversation_handle]
	--		--					FROM [' + SCHEMA_NAME() + N'].[' + @ListenerQueue + N'] 
	--		--					WHERE [message_body] is not null
	--		--			)
	--		--				DROP QUEUE [' + SCHEMA_NAME() + N'].[' + @ListenerQueue + N'] '
	--		--		EXEC sp_executesql @cmd
	--		--	END
	--	END
END
