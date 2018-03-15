
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [DependencyDB].[Uninstall]
	@AppName NVARCHAR(110), -- max object name length is 128 ex. 'MemSourceAPI'
	@SubscriberString NVARCHAR(128), -- ex. 'A_JobPart_Select'
	@ProcedureSchemaName NVARCHAR(128),
	@ProcedureName NVARCHAR(128),
	@ProcedureParameters dbo.SpParametersType READONLY
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
	DECLARE trigerCursor CURSOR FOR
		SELECT [name]
			FROM sys.triggers
			WHERE [name] like @ListenerAppName + N'_%_' + @ListenerProcedureName + N'_' +  @ProcedureParametersString 
	OPEN trigerCursor
	FETCH NEXT FROM trigerCursor
		INTO @triger
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @cmd = N'
				IF EXISTS (
					SELECT [name]
						FROM sys.triggers
						WHERE [name] = ''' + @triger + N'''
				)
				DROP TRIGGER [' + @triger + N'] '
			EXEC sp_executesql @cmd

			FETCH NEXT FROM trigerCursor INTO @triger
		END
	CLOSE trigerCursor;
	DEALLOCATE trigerCursor;

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
