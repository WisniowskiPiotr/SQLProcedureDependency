CREATE 
PROCEDURE [{2}].[P_ReceiveSubscription]
	@V_ReceiveTimeout int = 150000 -- After 5 min retry getting message from queue.
AS 
--DECLARE
--	@V_ReceiveTimeout INT = '150000'
BEGIN

	SET NOCOUNT ON; 
	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Cmd NVARCHAR(max);

	DECLARE @V_LoginName SYSNAME = 'L_' + @V_MainName;
	DECLARE @V_SchemaName SYSNAME = '{2}';
	DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
	DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
	DECLARE @V_ServiceName SYSNAME = '{1}';
	
	-- Start Listening
	SET @V_Cmd = '
		DECLARE @V_ConvHandle UNIQUEIDENTIFIER
        DECLARE @V_Message VARBINARY(MAX) 
		DECLARE @V_MessageTypeId int = 2 -- end conversation msg
		DECLARE @V_ConnectionState varchar(2)
		DECLARE @V_IsFound bit
		WHILE @V_MessageTypeId = 2
			BEGIN
				SET @V_ConvHandle = null ;
				WAITFOR (
					RECEIVE TOP(1) 
							@V_ConvHandle = Conversation_Handle , 
							@V_Message  = message_body , 
							@V_MessageTypeId = message_type_id
						FROM ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_QueueName ) + '
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
        SELECT CAST( @V_Message AS NVARCHAR(MAX) ) ;
		'
	EXEC sp_executesql @V_Cmd ;
	RETURN 0 ;
END ;
