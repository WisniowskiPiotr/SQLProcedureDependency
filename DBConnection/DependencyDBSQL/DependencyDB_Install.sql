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

	DECLARE @V_ProcedureParametersList NVARCHAR(max) ;
	SET @V_ProcedureParametersList = ISNULL(
			(SELECT ', ' + 
				CASE 
					WHEN SUBSTRING(PName,1,1) !='@'
					THEN '@'
					ELSE ''
				END + PName + ' ' + PType + ' ' 
			FROM @TBL_ProcedureParameters 
			FOR XML PATH(''))
		,'') ;
	SET @V_ProcedureParametersList = SUBSTRING( @V_ProcedureParametersList , 2 , LEN( @V_ProcedureParametersList ))
	
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
				END + ' ; '  
			FROM @TBL_ProcedureParameters 
			FOR XML PATH(''))
		,'') ;

	DECLARE @V_ProcedureParametersXlm NVARCHAR(max) ;
	SET @V_ProcedureParametersXlm = '<schema name="' + @V_ProcedureSchemaName + '">'+ '<procedure name="' + @V_ProcedureName + '">' + ISNULL(
		(SELECT 
				PName as name,
				PType as type,
				PValue as value
			FROM @TBL_ProcedureParameters 
			FOR XML PATH('parameter'))
		,'') + '</procedure>' + '</schema>' ;

	-- get procedure text
	DECLARE @V_ProcedureText NVARCHAR(max) ;
	SELECT @V_ProcedureText = sql_modules.definition
		FROM sys.sql_modules AS sql_modules
		INNER JOIN sys.procedures AS procedures
			ON procedures.object_id = sql_modules.object_id
		INNER JOIN sys.schemas AS schemas
			ON schemas.schema_id = procedures.schema_id
		WHERE schemas.name = @V_ProcedureSchemaName
			AND procedures.name = @V_ProcedureName ;

	-- get rid of begining of procedure
	DECLARE @TBL_StartPoz Table (
		[C_StartPoz] bigint
	) ;
	INSERT INTO @TBL_StartPoz
	VALUES (CHARINDEX( ' AS ', @V_ProcedureText) + 4),
		(CHARINDEX( ' AS' + CHAR(10), @V_ProcedureText) + 4),
		(CHARINDEX( ' AS' + CHAR(13), @V_ProcedureText) + 4),
		(CHARINDEX( CHAR(10) + 'AS ', @V_ProcedureText) + 4),
		(CHARINDEX( CHAR(10) + 'AS' + CHAR(10), @V_ProcedureText) + 4),
		(CHARINDEX( CHAR(10) + 'AS' + CHAR(13), @V_ProcedureText) + 4),
		(CHARINDEX( CHAR(13) + 'AS ', @V_ProcedureText) + 4),
		(CHARINDEX( CHAR(13) + 'AS' + CHAR(10), @V_ProcedureText) + 4),
		(CHARINDEX( CHAR(13) + 'AS' + CHAR(13), @V_ProcedureText) + 4),
		(CHARINDEX('ASBEGIN',@V_ProcedureText)  + 7) ;
	DECLARE @V_startPoz bigint ;
	SELECT @V_startPoz = MIN ( TBL_StartPoz.C_StartPoz )
		FROM @TBL_StartPoz AS TBL_StartPoz
		WHERE TBL_StartPoz.C_StartPoz > 7;
	SET @V_ProcedureText = SUBSTRING(@V_ProcedureText , @V_startPoz ,LEN( @V_ProcedureText ) - @V_startPoz + 1) ;
	
	-- get result table definition
	DECLARE @V_ResultTableDefinition NVARCHAR(max)
	SET @V_ResultTableDefinition =
		(SELECT ',' + TBL_ResultDefinition.name + ' ' + TBL_ResultDefinition.system_type_name --+   CHAR(10) 
		FROM [sys].[dm_exec_describe_first_result_set] ( @V_ProcedureText, @V_ProcedureParametersList, 0) AS TBL_ResultDefinition
		FOR XML PATH('')) ;
	SET @V_ResultTableDefinition = '
		DECLARE @TBL_ResultTable TABLE (
			' +
			SUBSTRING( @V_ResultTableDefinition , 2 , LEN(@V_ResultTableDefinition))
		+ '
		) ;
	' ;

	-- get tables used in procedure
	DECLARE @TBL_ReferencedTables TABLE (
		[name] SYSNAME
	) ;
	INSERT INTO @TBL_ReferencedTables
		SELECT 
				quotename( ReferencedEntities.referenced_schema_name ) + '.'  + quotename( ReferencedEntities.referenced_entity_name ) ,*
			FROM sys.dm_sql_referenced_entities ( quotename( @V_ProcedureSchemaName ) + '.' + quotename( @V_ProcedureName ) , 'OBJECT' ) AS ReferencedEntities
			WHERE ReferencedEntities.referenced_minor_id = 0
				AND ReferencedEntities.referenced_entity_name IS NOT NULL
				AND ReferencedEntities.referenced_schema_name IS NOT NULL

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

					' + @V_ResultTableDefinition + '
									
					-- inner procedure
					-- inserted rows
					IF EXISTS (
						SELECT * 
							FROM INSERTED
					)
						BEGIN
							

							INSERT INTO @TBL_ResultTable
							EXEC sp_executesql 
						END
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



