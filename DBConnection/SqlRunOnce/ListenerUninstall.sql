USE [test_sgdb]
GO
/****** Object:  StoredProcedure [NotificationBroker].[ListenerUninstall]    Script Date: 2017-12-22 09:42:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [NotificationBroker].[ListenerUninstall]
	
	@ListenerAppName NVARCHAR(110), -- max object name length is 128 ex. 'MemSourceAPI'
	@ListenerProcedureName NVARCHAR(100), -- ex. 'A_JobPart_Select'
	@ListenerSParameters dbo.SpParametersType READONLY 
	
AS
BEGIN

	DECLARE @ListenerQueue NVARCHAR(128)
	SET @ListenerQueue = N'ListenerQueue_' + @ListenerAppName
	DECLARE @ListenerService NVARCHAR(128)
	SET @ListenerService = N'ListenerService_' + @ListenerAppName

	DECLARE @ProcedureParametersString NVARCHAR(110)
	SET @ProcedureParametersString = 
		(select '_' + PValue
		from @ListenerSParameters 
		FOR XML PATH(''))

	DECLARE @ListenerProcedureParametersXlm NVARCHAR(max) 
	SET @ListenerProcedureParametersXlm = N'<' + @ListenerProcedureName + N'>' +(
		SELECT 
				PName as name,
				PType as type,
				PValue as value
			FROM @ListenerSParameters 
			FOR XML PATH(N'parameter')
	) + N'</' + @ListenerProcedureName + N'>'

	DECLARE @cmd NVARCHAR(MAX)
	-- notyfy app that substribtion was removed
	--Beginning of dialog...
	SET @cmd = N'
		DECLARE @message NVARCHAR(MAX)
		SET @message = N''<RemoveNotification>''
		SET @message = @message + ''' + @ListenerProcedureParametersXlm + '''
		SET @message = @message + N''</RemoveNotification>''
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
	DECLARE @triger NVARCHAR(128)
	DECLARE @table NVARCHAR(128)
	DECLARE trigerCursor CURSOR FOR
		SELECT [name]
			FROM sys.triggers
			WHERE [name] like @ListenerAppName + N'_%_' + @ListenerProcedureName + N'_' +  @ProcedureParametersString 
	OPEN trigerCursor
	FETCH NEXT FROM trigerCursor
		INTO @triger
	WHILE @@FETCH_STATUS = 0
		BEGIN
			
			SELECT 
					@table = schemas.name + '.' + tables.name
				FROM sys.triggers AS triggers
				INNER JOIN sys.tables AS tables 
					ON tables.object_id = triggers.parent_id
				INNER JOIN sys.schemas AS schemas
					ON schemas.schema_id = tables.schema_id
				WHERE 
					triggers.name = @triger

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
				DROP TRIGGER [' + @triger + N'] '
			EXEC sp_executesql @cmd

			COMMIT TRANSACTION;

			FETCH NEXT FROM trigerCursor INTO @triger
		END
	CLOSE trigerCursor;
	DEALLOCATE trigerCursor;

	-- if no other triggers exist drop rest
	IF NOT EXISTS (
		SELECT [name]
			FROM sys.triggers
			WHERE [name] like @ListenerAppName + N'_%'
	)
		BEGIN
			DECLARE @serviceId INT
			SELECT @serviceId = service_id FROM sys.services 
				WHERE sys.services.name = @ListenerService
			IF @serviceId is not null
			BEGIN 
				DECLARE @ConvHandle uniqueidentifier
				DECLARE Conv CURSOR FOR
					SELECT CEP.conversation_handle 
						FROM sys.conversation_endpoints CEP
						WHERE CEP.service_id = @serviceId AND ([state] != 'CD' AND [lifetime] > GETDATE())
				OPEN Conv;
				FETCH NEXT FROM Conv INTO @ConvHandle;
					WHILE (@@FETCH_STATUS = 0) 
					BEGIN
    					END CONVERSATION @ConvHandle;
						FETCH NEXT FROM Conv INTO @ConvHandle;
					END
				CLOSE Conv;
				DEALLOCATE Conv;

				-- Droping service.
				SET @cmd = N'
					DROP SERVICE [' + @ListenerService  + N'] '
				EXEC sp_executesql @cmd
			END

			-- drop queue
			--IF EXISTS(
			--		SELECT name
			--			FROM sys.service_queues
			--			WHERE name = @ListenerQueue
			--	)
			--	BEGIN
			--		SET @cmd = N'
			--			IF NOT EXISTS (
			--				SELECT [conversation_handle]
			--					FROM [' + SCHEMA_NAME() + N'].[' + @ListenerQueue + N'] 
			--					WHERE [message_body] is not null
			--			)
			--				DROP QUEUE [' + SCHEMA_NAME() + N'].[' + @ListenerQueue + N'] '
			--		EXEC sp_executesql @cmd
			--	END
		END
END
