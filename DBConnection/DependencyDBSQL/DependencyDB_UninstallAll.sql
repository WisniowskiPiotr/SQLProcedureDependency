
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [DependencyDB].[UninstallAll]
	@AppName NVARCHAR(110) -- max object name length is 128 ex. 'MemSourceAPI'
AS
BEGIN

	-- this is run only on start of application
	DECLARE @ListenerQueue NVARCHAR(128)
	SET @ListenerQueue = N'ListenerQueue_' + @ListenerAppName
	DECLARE @ListenerService NVARCHAR(128)
	SET @ListenerService = N'ListenerService_' + @ListenerAppName
	
	DECLARE @cmd NVARCHAR(MAX)
	-- drop triggers
	DECLARE @Trigger NVARCHAR(128)
	DECLARE TriggerCursor CURSOR FOR
		SELECT [name]
			FROM sys.triggers
			WHERE [name] like @ListenerAppName + N'_%' 
	OPEN TriggerCursor
	FETCH NEXT FROM TriggerCursor
		INTO @Trigger
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @cmd = N'
				DROP TRIGGER [' + @Trigger + N'] '
			EXEC sp_executesql @cmd

			FETCH NEXT FROM TriggerCursor INTO @Trigger
		END
	CLOSE TriggerCursor;
	DEALLOCATE TriggerCursor;

	-- drop service
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

END
