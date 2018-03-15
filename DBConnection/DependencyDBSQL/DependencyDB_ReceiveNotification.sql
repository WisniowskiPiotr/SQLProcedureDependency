CREATE PROCEDURE [DependencyDB].[ReceiveNotification]
	@V_ReceiveTimeout int
AS
BEGIN

	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Cmd NVARCHAR(max);

	DECLARE @V_Queue SYSNAME ;
	SET @V_Queue =  'Queue_' + @V_MainName ;

	-- Start Listening
	SET @V_Cmd = '
		DECLARE @V_ConvHandle UNIQUEIDENTIFIER
        DECLARE @V_Message VARBINARY(MAX) 
		DECLARE @V_MessageTypeId int = 2 -- end conversation msg
		DECLARE @V_ConnectionState varchar(2)
		DECLARE @V_IsFound bit
		WHILE @messageTypeId = 2
			BEGIN
				WAITFOR (
					RECEIVE TOP(1) 
							@V_ConvHandle = Conversation_Handle , 
							@V_Message  = message_body , 
							@V_MessageTypeId = message_type_id
						FROM ' + quotename( @V_MainName ) + '.' + quotename( @V_Queue ) + '
					)
					, TIMEOUT ' + CAST( @V_ReceiveTimeout AS NVARCHAR(200)) + ';

				SET @V_IsFound = 0
				SELECT 
						@V_ConnectionState = CAST( state AS varchar(2)) ,  
						@V_IsFound = 1
					FROM sys.conversation_endpoints
					WHERE conversation_handle = @V_ConvHandle
				IF ( @V_IsFound = 1 AND ( @V_ConnectionState = ''CO'' OR @V_ConnectionState = ''DI'') )
					END CONVERSATION @V_ConvHandle; 
			END
        SELECT CAST( @V_Message AS NVARCHAR(MAX) ) 
		'
	EXEC sp_executesql @Listenercmd
END
