USE [test_sgdb]
GO
/****** Object:  StoredProcedure [NotificationBroker].[ListenerReceiveNotification]    Script Date: 2017-12-06 13:11:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [NotificationBroker].[ListenerReceiveNotification]
	@AppName NVARCHAR(200),
	@Lifetime int
AS
BEGIN
	DECLARE @ListenerQueue NVARCHAR(200)
	SET @ListenerQueue = N'ListenerQueue_' + @AppName

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
        WAITFOR (
			RECEIVE TOP(1) 
					@ConvHandle=Conversation_Handle
					, @message=message_body 
				FROM [' + SCHEMA_NAME() + N'].[' + @ListenerQueue + N']
			)
			, TIMEOUT ' + convert(nvarchar(200), @Lifetime) + N';
	    BEGIN TRY 
			END CONVERSATION @ConvHandle; 
		END TRY 
		BEGIN CATCH 
		END CATCH
        SELECT CAST(@message AS NVARCHAR(MAX)) '
	EXEC sp_executesql @Listenercmd
END

