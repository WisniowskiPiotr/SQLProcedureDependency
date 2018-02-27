USE [sgdb]
GO
/****** Object:  StoredProcedure [NotificationBroker].[ListenerInstall]    Script Date: 2018-01-02 13:23:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [NotificationBroker].[ListenerInstall]
	@ListenerAppName NVARCHAR(110), -- max object name length is 128 ex. 'MemSourceAPI'
	@ListenerProcedureName NVARCHAR(100), -- ex. 'A_JobPart_Select'
	@ListenerSParameters dbo.SpParametersType READONLY,
	@ListenerLifetime int,
	@ListenerProcedureSchema NVARCHAR(100) = null, -- ex. 'dbo'
	@ListenerNotyfyMode NVARCHAR(110) = N'INSERT, UPDATE, DELETE'

AS
BEGIN
	-- Important! Run before creating procedure
	--CREATE TYPE dbo.SpParametersType AS TABLE   
	--( PName NVARCHAR(100),
	--  Ptype  NVARCHAR(20),
	--  PValue NVARCHAR(100));  
	--GO  
	--GRANT EXECUTE ON TYPE::dbo.SpParametersType TO NotificationBroker
	--GO

	IF @ListenerProcedureSchema is null
		SET @ListenerProcedureSchema = SCHEMA_NAME()
	DECLARE @ListenerQueue NVARCHAR(128)
	SET @ListenerQueue = N'ListenerQueue_' + @ListenerAppName
	DECLARE @ListenerService NVARCHAR(128)
	SET @ListenerService = N'ListenerService_' + @ListenerAppName

	DECLARE @ListenerProcedureParametersString NVARCHAR(110)
	SET @ListenerProcedureParametersString = ISNULL(
			(SELECT '_' + PValue
			FROM @ListenerSParameters 
			FOR XML PATH(''))
		,'')

	DECLARE @ListenerProcedureParametersDeclaration NVARCHAR(max)
	SET @ListenerProcedureParametersDeclaration = ISNULL(
			(SELECT 'DECLARE ' + CASE 
				WHEN SUBSTRING(PName,1,1) !='@'
				THEN '@'
				ELSE ''
				END + PName + ' ' + PType + ' = ' + CASE 
				WHEN CHARINDEX('CHAR', PType) != 0
				THEN CHAR(39)
				ELSE ''
				END + PValue + CASE 
				WHEN CHARINDEX('CHAR', PType) != 0
				THEN CHAR(39)
				ELSE ''
				END + ' ' -- + CHAR(13)
			FROM @ListenerSParameters 
			FOR XML PATH(''))
		,'')

	DECLARE @ListenerProcedureParametersXlm NVARCHAR(max) 
	SET @ListenerProcedureParametersXlm = N'<' + @ListenerProcedureName + N'>' + ISNULL(
		(SELECT 
				PName as name,
				PType as type,
				PValue as value
			FROM @ListenerSParameters 
			FOR XML PATH(N'parameter'))
		,'') + N'</' + @ListenerProcedureName + N'>'

	-- start transaction
	--BEGIN TRANSACTION 
	
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
			CREATE QUEUE [' + @ListenerProcedureSchema + N'].[' + @ListenerQueue + N'] 
			'
			EXEC sp_executesql @Listenercmd
		END

    -- Create a service on which tracked information will be sent 
    IF NOT EXISTS(
		SELECT name
			FROM sys.services 
			WHERE name = @ListenerService
	)
		BEGIN
			SET @Listenercmd = null
			SET @Listenercmd = N'
			CREATE SERVICE [' + @ListenerService + N'] 
			ON QUEUE [' + @ListenerProcedureSchema + N'].[' + @ListenerQueue + N'] 
			([DEFAULT]) 
			'
			EXEC sp_executesql @Listenercmd
		END

	-- get procedure
	DECLARE @ListenerProcedureText NVARCHAR(max)
	SELECT @ListenerProcedureText=ROUTINE_DEFINITION
		FROM INFORMATION_SCHEMA.ROUTINES 
		WHERE ROUTINE_NAME = @ListenerProcedureName
		AND ROUTINE_SCHEMA = @ListenerProcedureSchema
		AND ROUTINE_TYPE=N'PROCEDURE'

	-- get rid of BEGINING and END from procedure
	SET @ListenerProcedureText = SUBSTRING(@ListenerProcedureText, CHARINDEX(N'BEGIN', @ListenerProcedureText) + 5, ((LEN(@ListenerProcedureText) - (CHARINDEX(N'DNE',REVERSE(@ListenerProcedureText)) + 2)) - (CHARINDEX(N'BEGIN', @ListenerProcedureText) + 4)))

	-- get tables used in procedure
	DECLARE @ListenerTables TABLE ([name] NVARCHAR(128))
	INSERT INTO @ListenerTables
		SELECT 
				referenced_schema_name + '.' +  referenced_entity_name
			FROM sys.dm_sql_referenced_entities (@ListenerProcedureSchema + '.' + @ListenerProcedureName,'OBJECT')
			WHERE referenced_minor_id = 0

	-- for each affected table
	DECLARE @Listenertable NVARCHAR(128)
	DECLARE ListenertableCursor CURSOR FOR
		SELECT [name]
			FROM @ListenerTables
	OPEN ListenertableCursor
	FETCH NEXT FROM ListenertableCursor INTO @Listenertable
	WHILE @@FETCH_STATUS = 0
		BEGIN
		
			DECLARE @ListenerTriger NVARCHAR(128)
			SET @ListenerTriger = @ListenerAppName + N'_' + REPLACE(@Listenertable, N'.', N'_') + N'_' + @ListenerProcedureName + N'_' +  @ListenerProcedureParametersString 
			
			BEGIN TRANSACTION 
			-- lock table
			SET @Listenercmd = N'
				SELECT TOP 1 
						1 
					FROM ' + @Listenertable + N'
					WITH (UPDLOCK, TABLOCKX, HOLDLOCK) 
				'
			EXEC sp_executesql @Listenercmd

			-- Notification Trigger check statement.
			DECLARE @ListenerTrigerBody NVARCHAR(max)
			SET @ListenerTrigerBody = N'
				ON ' + @Listenertable + N' 
				WITH EXECUTE AS ''' + USER_NAME() + N'''
				AFTER ' + @ListenerNotyfyMode + N' 
				AS 
				BEGIN
					SET NOCOUNT ON; 

					IF ( EXISTS (
							SELECT name
								FROM sys.services 
								WHERE name = ''' + @ListenerService + N''' 
							) 
						)
						BEGIN
							DECLARE @message NVARCHAR(MAX)
							DECLARE @messageInserted NVARCHAR(MAX)
							DECLARE @messageParameters NVARCHAR(MAX)
							DECLARE @messageDeleted NVARCHAR(MAX)
							DECLARE @retvalOUT NVARCHAR(MAX)
							' + @ListenerProcedureParametersDeclaration + N'
									
							-- inner procedure
							-- inserted rows
							IF EXISTS (
								SELECT * 
									FROM INSERTED
							)
								SET @retvalOUT = (
								-- start inner procedure
								'+ REPLACE(@ListenerProcedureText, @Listenertable, N'INSERTED') + N'
								-- end inner procedure
								)
							IF (@retvalOUT IS NOT NULL)
								SET @messageInserted = N''<inserted>'' + @retvalOUT + N''</inserted>''

							-- deleted rows
							IF EXISTS (
								SELECT * 
									FROM DELETED
							)
								SET @retvalOUT = (
								-- start inner procedure
								'+ REPLACE(@ListenerProcedureText, @Listenertable, N'DELETED') + N'
								-- end inner procedure
								)
							IF (@retvalOUT IS NOT NULL)
								SET @messageDeleted = N''<deleted>'' + @retvalOUT + N''</deleted>''

							-- IF no changes return
							IF @messageInserted IS NOT NULL 
								OR @messageDeleted IS NOT NULL
								BEGIN
									-- create final message
									SET @message = N''<Notification>''
									SET @message = @message + ''' + @ListenerProcedureParametersXlm + N'''
									IF @messageInserted is not null
										SET @message = @message + @messageInserted
									IF @messageDeleted is not null
										SET @message = @message + @messageDeleted
									SET @message = @message + N''</Notification>''

									--Beginning of dialog...
                					DECLARE @ConvHandle UNIQUEIDENTIFIER
                					--Determine the Initiator Service, Target Service and the Contract 
                					BEGIN DIALOG @ConvHandle 
										FROM SERVICE ' + @ListenerService + N' 
										TO SERVICE ''' + @ListenerService + N''' 
										ON CONTRACT [DEFAULT] 
										WITH ENCRYPTION = OFF, 
										LIFETIME = ' + CAST(@ListenerLifetime as nvarchar(200)) + N'; 
									--Send the Message
									SEND ON CONVERSATION @ConvHandle 
										MESSAGE TYPE [DEFAULT] (@message);
									--End conversation
									END CONVERSATION @ConvHandle;
								END

							IF (GETDATE()> ''' + CAST(DATEADD(S , @ListenerLifetime , GETDATE()) as nvarchar(200)) + N''')
								BEGIN
									DECLARE @messageOutdated NVARCHAR(MAX)
									SET @messageOutdated = N''<OutdatedNotification>''
									SET @messageOutdated = @messageOutdated + ''' + @ListenerProcedureParametersXlm + '''
									SET @messageOutdated = @messageOutdated + N''</OutdatedNotification>''
									DECLARE @ConvHandleOutdated UNIQUEIDENTIFIER
									--Determine the Initiator Service, Target Service and the Contract 
									BEGIN DIALOG @ConvHandleOutdated 
										FROM SERVICE ' + @ListenerService + N' 
										TO SERVICE ''' + @ListenerService + N''' 
										ON CONTRACT [DEFAULT] 
										WITH ENCRYPTION = OFF;
									--Send the Message
									SEND ON CONVERSATION @ConvHandleOutdated 
										MESSAGE TYPE [DEFAULT] (@messageOutdated);
									--End conversation
									END CONVERSATION @ConvHandleOutdated;
								END
						END
					ELSE
						BEGIN
							DECLARE @SParameters dbo.SpParametersType

							DECLARE @str NVARCHAR(MAX)
							SET @str = ''' + @ListenerProcedureParametersXlm + N'''
							DECLARE @xml xml
							SELECT @xml = CAST(CAST(@str AS VARBINARY(MAX)) AS XML) 

							INSERT INTO @SParameters (PName, Ptype, PValue)
								SELECT 
										x.Rec.query(''./name'').value(''.'', ''NVARCHAR(100)'') AS ''PName'',
										x.Rec.query(''./type'').value(''.'', ''NVARCHAR(20)'') AS ''Ptype'',
										x.Rec.query(''./value'').value(''.'', ''NVARCHAR(100)'') AS ''PValue''
									FROM @xml.nodes(''/' + @ListenerProcedureName + N'/parameter'') as x(Rec)

							EXEC [NotificationBroker].[ListenerUninstall] 
								@ListenerAppName = ''' + @ListenerAppName + N''', 
								@ListenerProcedureName = ''' + @ListenerProcedureName + N''', 
								@ListenerSParameters = @SParameters
						END
				END 
			'
			IF NOT EXISTS (
				SELECT [name]
					FROM sys.triggers
					WHERE [name] = @ListenerTriger
			)
				BEGIN
					SET @Listenercmd = null
					SET @Listenercmd = N'
						CREATE TRIGGER [' + @ListenerTriger + N'] 
						' + @ListenerTrigerBody
					EXEC sp_executesql @Listenercmd
				END
			ELSE
				BEGIN
					SET @Listenercmd = null
					SET @Listenercmd = N'
						ALTER TRIGGER [' + @ListenerTriger + N'] 
						' + @ListenerTrigerBody
					EXEC sp_executesql @Listenercmd
				END
			COMMIT TRANSACTION;
			FETCH NEXT FROM ListenertableCursor INTO @Listenertable
		END
	CLOSE ListenertableCursor;
	DEALLOCATE ListenertableCursor;

	--COMMIT TRANSACTION;
END



