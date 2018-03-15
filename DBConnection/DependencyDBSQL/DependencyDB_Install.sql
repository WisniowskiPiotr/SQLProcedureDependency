CREATE PROCEDURE [DependencyDB].[Install]
	@V_SubscriberString NVARCHAR(200),
	@V_SubscriptionHash INT,
	@V_ProcedureSchemaName SYSNAME,
	@V_ProcedureName SYSNAME,
	@TBL_ProcedureParameters dbo.TYPE_ParametersType READONLY,
	@V_ValidFor INT
AS
BEGIN

	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Cmd NVARCHAR(max);

	DECLARE @V_Service SYSNAME ;
	SET @V_Service = 'Service_' + @V_MainName ;
	
	DECLARE @V_ProcedureParametersDeclaration NVARCHAR(max) ;
	SET @V_ProcedureParametersDeclaration = ISNULL(
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
				END + ' '  + CHAR(13) + CHAR(10)
			FROM @TBL_ProcedureParameters 
			FOR XML PATH(''))
		,'') ;

	DECLARE @V_ProcedureParametersXlm NVARCHAR(max)  ;
	SET @V_ProcedureParametersXlm = '<' + @V_ProcedureSchemaName + '>'+ '<' + @V_ProcedureName + '>' + ISNULL(
		(SELECT 
				PName as name,
				PType as type,
				PValue as value
			FROM @TBL_ProcedureParameters 
			FOR XML PATH('parameter'))
		,'') + '</' + @V_ProcedureName + '>' + '</' + @V_ProcedureSchemaName + '>' ;
	

	-- get procedure text
	DECLARE @V_ProcedureText NVARCHAR(max) ;
	SELECT @V_ProcedureText = ROUTINE_DEFINITION
		FROM INFORMATION_SCHEMA.ROUTINES 
		WHERE ROUTINE_NAME = @V_ProcedureName
		AND ROUTINE_SCHEMA = @V_ProcedureSchemaName
		AND ROUTINE_TYPE = 'PROCEDURE' ;

	-- get rid of BEGIN and END from procedure
	-- TODO: is this neccesary?
	SET @V_ProcedureText = SUBSTRING( @V_ProcedureText , CHARINDEX( 'BEGIN' , @V_ProcedureText) + 5, ( ( LEN( @V_ProcedureText ) - ( CHARINDEX( 'DNE' , REVERSE( @V_ProcedureText ) ) + 2) ) - ( CHARINDEX( 'BEGIN', @V_ProcedureText ) + 4) ) ) ;

	-- get tables used in procedure
	DECLARE @TBL_ReferencedTables TABLE (
		[name] SYSNAME
	) ;
	INSERT INTO @TBL_ReferencedTables
		SELECT 
				quotename( referenced_schema_name ) + '.' + quotename( referenced_entity_name )
			FROM sys.dm_sql_referenced_entities ( @V_ProcedureSchemaName + '.' + @V_ProcedureName , 'OBJECT' )
			WHERE referenced_minor_id = 0 ;

	-- for each affected table
	DECLARE @V_ReferencedTable SYSNAME ;
	DECLARE ReferencedTablesCursor CURSOR FOR
		SELECT [name]
			FROM @TBL_ReferencedTables ;
	OPEN ReferencedTablesCursor ;
	FETCH NEXT FROM ReferencedTablesCursor INTO @V_ReferencedTable ;
	WHILE @@FETCH_STATUS = 0
		BEGIN
		
			DECLARE @V_TrigerName NVARCHAR(128) ;
			SET @V_TrigerName = @V_MainName + '_' + REPLACE(@V_ReferencedTable, '.', '_') + '_' + @V_SubscriptionHash ;
			
			-- Trigger statement.
			DECLARE @V_TrigerBody NVARCHAR(max)
			SET @V_TrigerBody = '
				ON ' + quotename( @V_ReferencedTable ) + ' 
				WITH EXECUTE AS ''' + USER_NAME() + '''
				AFTER INSERT, UPDATE, DELETE
				AS 
				BEGIN
					SET NOCOUNT ON; 

					DECLARE @V_Message NVARCHAR(MAX)
					DECLARE @V_MessageInserted NVARCHAR(MAX)
					DECLARE @V_MessageParameters NVARCHAR(MAX)
					DECLARE @V_MessageDeleted NVARCHAR(MAX)
					DECLARE @V_retvalOUT NVARCHAR(MAX)
					' + @V_ProcedureParametersDeclaration + '
									
					-- inner procedure
					-- inserted rows
					IF EXISTS (
						SELECT * 
							FROM INSERTED
					)
						SET @V_retvalOUT = (
						-- start inner procedure
						' + REPLACE( @V_ProcedureText, @V_ReferencedTable, 'INSERTED') + '
						-- end inner procedure
						)
					IF (@V_retvalOUT IS NOT NULL)
						SET @V_MessageInserted = ''<inserted>'' + @V_retvalOUT + ''</inserted>''

					-- deleted rows
					IF EXISTS (
						SELECT * 
							FROM DELETED
					)
						SET @V_retvalOUT = (
						-- start inner procedure
						' + REPLACE( @V_ProcedureText, @V_ReferencedTable, 'DELETED') + '
						-- end inner procedure
						)
					IF (@V_retvalOUT IS NOT NULL)
						SET @V_MessageDeleted = ''<deleted>'' + @V_retvalOUT + ''</deleted>''

					-- IF no changes return
					IF @V_MessageInserted IS NOT NULL 
						OR @V_MessageDeleted IS NOT NULL
						BEGIN
							-- create final message
							SET @V_Message = ''<notification>''
							SET @V_Message = @V_Message + ''' + @V_ProcedureParametersXlm + N'''
							IF @V_MessageInserted IS NOT NULL 
								SET @V_Message = @V_Message + @V_MessageInserted
							IF @V_MessageDeleted IS NOT NULL 
								SET @V_Message = @V_Message + @V_MessageDeleted
							SET @V_Message = @V_Message + ''</notification>''

							--Beginning of dialog...
                			DECLARE @V_ConvHandle UNIQUEIDENTIFIER
                			--Determine the Initiator Service, Target Service and the Contract 
                			BEGIN DIALOG @V_ConvHandle 
								FROM SERVICE ' + @V_Service + ' 
								TO SERVICE ''' + @V_Service + ''' 
								ON CONTRACT [DEFAULT] 
								WITH ENCRYPTION = OFF, 
								LIFETIME = ' + CAST( @V_ValidFor AS NVARCHAR(200)) + '; 
							--Send the Message
							SEND ON CONVERSATION @V_ConvHandle 
								MESSAGE TYPE [DEFAULT] (@V_Message);
							--End conversation
							END CONVERSATION @V_ConvHandle;
						END
				END 
			' ;
			BEGIN TRANSACTION 
				-- lock whole table
				SET @V_Cmd = '
					SELECT TOP 1 
							1 
						FROM ' + quotename( @V_ReferencedTable ) + '
						WITH (UPDLOCK, TABLOCKX, HOLDLOCK) 
					' ;
				EXEC sp_executesql @V_Cmd ;

				IF NOT EXISTS (
					SELECT [name]
						FROM sys.triggers
						WHERE [name] = @V_TrigerName
				)
					BEGIN
						SET @V_Cmd = '
							CREATE TRIGGER [' + @V_TrigerName + N'] 
							' + @V_TrigerBody ;
						EXEC sp_executesql @V_Cmd ;
					END
				ELSE
					BEGIN
						SET @V_Cmd = N'
							ALTER TRIGGER [' + @V_TrigerName + N'] 
							' + @V_TrigerBody ;
						EXEC sp_executesql @V_Cmd ;
					END
			COMMIT TRANSACTION;
			FETCH NEXT FROM ReferencedTablesCursor INTO @V_ReferencedTable ;
		END
	CLOSE ReferencedTablesCursor ;
	DEALLOCATE ReferencedTablesCursor ;
END



