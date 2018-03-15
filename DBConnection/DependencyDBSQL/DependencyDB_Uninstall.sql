CREATE PROCEDURE [DependencyDB].[Uninstall]
	@V_SubscriberString NVARCHAR(200) = null,
	@V_SubscriptionHash INT = null,
	@V_ProcedureSchemaName SYSNAME = null,
	@V_ProcedureName SYSNAME = null,
	@TBL_ProcedureParameters dbo.TYPE_ParametersType READONLY
AS
BEGIN

	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Cmd NVARCHAR(max);

	DECLARE @V_Queue SYSNAME ;
	SET @V_Queue =  'Queue_' + @V_MainName ;

	DECLARE @V_Service SYSNAME ;
	SET @V_Service = 'Service_' + @V_MainName ;

	DECLARE @V_ProcedureParametersXlm NVARCHAR(max) ;
	IF EXISTS (
		SELECT 
			PName as name
		FROM @TBL_ProcedureParameters)
		BEGIN
			SET @V_ProcedureParametersXlm = '<' + @V_ProcedureSchemaName + '>'+ '<' + @V_ProcedureName + '>' + ISNULL(
				(SELECT 
						PName as name,
						PType as type,
						PValue as value
					FROM @TBL_ProcedureParameters 
					FOR XML PATH('parameter'))
				,'') + '</' + @V_ProcedureName + '>' + '</' + @V_ProcedureSchemaName + '>' ;
		END
	ELSE
		BEGIN
			SET @V_ProcedureParametersXlm = null ;
		END
	












	SET @V_Cmd = N'
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
