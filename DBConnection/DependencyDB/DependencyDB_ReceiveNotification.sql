
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [DependencyDB].[ReceiveNotification]
	@AppName NVARCHAR(200),
	@ReceiveTimeout int
AS
BEGIN
	DECLARE @ListenerQueue NVARCHAR(200)
	SET @ListenerQueue = N'Queue_' + @AppName

	DECLARE @Listenercmd NVARCHAR(MAX)
    -- Create a queue which will hold the tracked information 
    IF NOT EXISTS (
		SELECT name
			FROM sys.service_queues 
			WHERE name = @ListenerQueue
	)
		BEGIN
			SET @Listenercmd = null
			SET @Listenercmd = N'
			CREATE QUEUE [' + @ListenerQueue + N'] 
			'
			EXEC sp_executesql @Listenercmd
		END

	-- Start Listening
	SET @Listenercmd = N'
		DECLARE @ConvHandle UNIQUEIDENTIFIER
        DECLARE @message VARBINARY(MAX) 
		DECLARE @messageTypeId int = 2 -- end conversation msg
		DECLARE @ConnectionState varchar(2)
		DECLARE @IsFound bit
		WHILE @messageTypeId = 2
			BEGIN
				BEGIN TRY
					BEGIN
						BEGIN TRANSACTION
							WAITFOR (
								RECEIVE TOP(1) 
										@ConvHandle = Conversation_Handle
										, @message  = message_body 
										, @messageTypeId = message_type_id
									FROM [' + SCHEMA_NAME() + N'].[' + @ListenerQueue + N']
								)
								, TIMEOUT ' + convert(nvarchar(200), @Lifetime) + N';

							SET @IsFound = 0
							SELECT 
									@ConnectionState = convert(varchar(2), state)
									,  @IsFound = 1
								FROM sys.conversation_endpoints
								WHERE conversation_handle = @ConvHandle
							IF (@IsFound = 1 AND (@ConnectionState = ''CO'' OR @ConnectionState = ''DI''))
								END CONVERSATION @ConvHandle; 
						COMMIT TRANSACTION
					END
				END TRY
				BEGIN CATCH
					BEGIN
						COMMIT TRANSACTION
					END
				END CATCH;
			END
        SELECT CAST(@message AS NVARCHAR(MAX)) 
		'
	EXEC sp_executesql @Listenercmd
END
