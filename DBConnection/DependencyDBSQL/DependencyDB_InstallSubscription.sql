CREATE PROCEDURE [{0}].[InstallSubscription]
	@V_SubscriberString NVARCHAR(200),
	@V_SubscriptionHash INT,
	@V_ProcedureSchemaName SYSNAME,
	@V_ProcedureName SYSNAME,
	@TBL_ProcedureParameters dbo.TYPE_ParametersType READONLY,
	@V_NotificationValidFor INT = 432000 -- 5 days to receive notification
AS 
--DECLARE
--	@V_SubscriberString NVARCHAR(200) = 'TestSubscriberString',
--	@V_SubscriptionHash INT = '1234564',
--	@V_ProcedureSchemaName SYSNAME = 'dbo',
--	@V_ProcedureName SYSNAME = 'TestProcedure',
--	@TBL_ProcedureParameters dbo.TYPE_ParametersType,
--	@V_NotificationValidFor INT = 30

--INSERT INTO @TBL_ProcedureParameters (PName, Ptype, PValue)
--VALUES ('@param1', 'int', -1) , ('@param2', 'int', -1)
BEGIN
	
	SET NOCOUNT ON; 
	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Service SYSNAME = '{1}'  ;
	DECLARE @V_Cmd NVARCHAR(max);

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
	SET @V_ProcedureText = @V_ProcedureParametersDeclaration + '
		' + SUBSTRING(@V_ProcedureText , @V_startPoz ,LEN( @V_ProcedureText ) - @V_startPoz + 1) ;
	
	-- get result table definition
	DECLARE @V_ResultTableDefinition NVARCHAR(max)
	SET @V_ResultTableDefinition =
		(SELECT ',' + QUOTENAME( TBL_ResultDefinition.name ) + ' ' + TBL_ResultDefinition.system_type_name --+   CHAR(10) 
		FROM [sys].[dm_exec_describe_first_result_set] ( @V_ProcedureText, null, 0) AS TBL_ResultDefinition
		FOR XML PATH('')) ;
	SET @V_ResultTableDefinition = '
		DECLARE @TBL_ResultTable TABLE (
			' +
			SUBSTRING( @V_ResultTableDefinition , 2 , LEN(@V_ResultTableDefinition))
		+ '
		) ;
	' ;
	
	-- get tables used in procedure must be written with schema in procedure
	DECLARE @TBL_ReferencedTables TABLE (
		[SchemaName] SYSNAME,
		[TableName] SYSNAME
	) ;
	INSERT INTO @TBL_ReferencedTables
		SELECT 
				ReferencedEntities.referenced_schema_name AS [SchemaName],
				ReferencedEntities.referenced_entity_name AS [TableName]
			FROM sys.dm_sql_referenced_entities ( QUOTENAME( @V_ProcedureSchemaName ) + '.' + QUOTENAME( @V_ProcedureName ) , 'OBJECT' ) AS ReferencedEntities
			WHERE ReferencedEntities.referenced_minor_id = 0
				AND ReferencedEntities.referenced_entity_name IS NOT NULL
				AND ReferencedEntities.referenced_schema_name IS NOT NULL
			GROUP BY ReferencedEntities.referenced_schema_name, 
				ReferencedEntities.referenced_entity_name ;

	-- for each affected table
	DECLARE @V_TriggerNames NVARCHAR(max) = '' ;
	DECLARE @V_TriggerName SYSNAME ;
	DECLARE @V_TriggerBody NVARCHAR(max) ;
	DECLARE @V_ReferencedQuotedTable NVARCHAR(256) ;
	DECLARE @V_ReferencedNonQuotedTable NVARCHAR(256) ;
	DECLARE @V_ReferencedSchema SYSNAME ;
	DECLARE @V_ReferencedTable SYSNAME ;
	DECLARE CU_ReferencedTablesCursor CURSOR FOR
		SELECT [SchemaName], 
			[TableName]
		FROM @TBL_ReferencedTables ;
	OPEN CU_ReferencedTablesCursor ;
	FETCH NEXT FROM CU_ReferencedTablesCursor 
		INTO @V_ReferencedSchema, @V_ReferencedTable ;
	WHILE @@FETCH_STATUS = 0
		BEGIN
		
			SET @V_TriggerName =  @V_MainName + '_' + @V_ReferencedSchema + '_' + @V_ReferencedTable + '_' + CAST( @V_SubscriptionHash AS NVARCHAR(200))  ;
			SET @V_TriggerNames = @V_TriggerNames + QUOTENAME( @V_TriggerName ) + ';'
			SET @V_ReferencedQuotedTable = QUOTENAME( @V_ReferencedSchema ) + '.' + QUOTENAME( @V_ReferencedTable )
			SET @V_ReferencedNonQuotedTable = @V_ReferencedSchema + '.' + @V_ReferencedTable
			
			-- Trigger statement
			SET @V_TriggerBody = '
				ON ' + @V_ReferencedQuotedTable + ' 
				WITH EXECUTE AS ''' + USER_NAME() + '''
				AFTER INSERT, UPDATE, DELETE
				AS 
				BEGIN
					SET NOCOUNT ON; 

					IF( GETDATE() > ''' + CONVERT(varchar(24), DATEADD( s, @V_NotificationValidFor, GETDATE() ), 21) + ''')
						RETURN 0 ;

					DECLARE @V_Message NVARCHAR(MAX) ;
					DECLARE @V_MessageInserted NVARCHAR(MAX) ;
					DECLARE @V_MessageParameters NVARCHAR(MAX) ; 
					DECLARE @V_MessageDeleted NVARCHAR(MAX) ;
					DECLARE @V_Retval NVARCHAR(MAX) ;
					DECLARE @V_Cmd NVARCHAR(MAX) ;

					' + @V_ResultTableDefinition + '
									
					-- inner procedure
					-- inserted rows
					IF EXISTS (
						SELECT * 
							FROM INSERTED
					)
						BEGIN
							SET @V_Cmd = 
								''' + REPLACE( 
										REPLACE( 
											REPLACE( @V_ProcedureText, @V_ReferencedQuotedTable, 'INSERTED') 
										, @V_ReferencedNonQuotedTable , 'INSERTED') 
									, '''', '''''' ) + ''' ;


							INSERT INTO @TBL_ResultTable
							EXEC sp_executesql @V_Cmd ;

							SET @V_MessageInserted = 
								(SELECT *
									FROM @TBL_ResultTable
									FOR XML PATH(''row''), ROOT(''inserted'')) ;

							DELETE FROM @TBL_ResultTable ;
						END

					-- deleted rows
					IF EXISTS (
						SELECT * 
							FROM DELETED
					)
						BEGIN
							SET @V_Cmd = 
								''' + REPLACE( 
										REPLACE( 
											REPLACE( @V_ProcedureText, @V_ReferencedQuotedTable, 'DELETED') 
										, @V_ReferencedNonQuotedTable , 'DELETED') 
									, '''', '''''' ) + ''' ;


							INSERT INTO @TBL_ResultTable
							EXEC sp_executesql @V_Cmd ;

							SET @V_MessageDeleted = 
								(SELECT *
									FROM @TBL_ResultTable
									FOR XML PATH(''row''), ROOT(''deleted'')) ;

							DELETE FROM @TBL_ResultTable ;
						END

					IF @V_MessageInserted IS NOT NULL 
						OR @V_MessageDeleted IS NOT NULL
						BEGIN
							-- create final message
							SET @V_Message = ''<notification subscriberstring="">''
							SET @V_Message = @V_Message + ''' + @V_ProcedureParametersXlm + '''
							IF @V_MessageInserted IS NOT NULL 
								SET @V_Message = @V_Message + @V_MessageInserted
							IF @V_MessageDeleted IS NOT NULL 
								SET @V_Message = @V_Message + @V_MessageDeleted
							SET @V_Message = @V_Message + ''</notification>''

							--Beginning of dialog...
                			DECLARE @V_ConvHandle UNIQUEIDENTIFIER
                			--Determine the Initiator Service, Target Service and the Contract 
                			BEGIN DIALOG @V_ConvHandle 
								FROM SERVICE ' + QUOTENAME( @V_Service ) + ' 
								TO SERVICE ''' + QUOTENAME( @V_Service ) + ''' 
								ON CONTRACT [DEFAULT] 
								WITH ENCRYPTION = OFF, 
								LIFETIME = ' + CAST( @V_NotificationValidFor AS NVARCHAR(200)) + '; 
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
					DECLARE @V_Dummy int
					SELECT TOP 1 
							@V_Dummy = 1 
						FROM ' + @V_ReferencedQuotedTable + '
						WITH (UPDLOCK, TABLOCKX, HOLDLOCK) 
					' ;
				EXEC sp_executesql @V_Cmd ;

				IF NOT EXISTS (
					SELECT [name]
						FROM sys.triggers
						WHERE [name] = @V_TriggerName
				)
					BEGIN
						SET @V_Cmd = '
							CREATE TRIGGER ' + QUOTENAME( @V_TriggerName ) + ' 
							' + @V_TriggerBody ;
						EXEC sp_executesql @V_Cmd ;
					END
				ELSE
					BEGIN
						SET @V_Cmd = N'
							ALTER TRIGGER ' + QUOTENAME( @V_TriggerName ) + ' 
							' + @V_TriggerBody ;
						EXEC sp_executesql @V_Cmd ;
					END
				
			COMMIT TRANSACTION;
			FETCH NEXT FROM CU_ReferencedTablesCursor 
				INTO @V_ReferencedSchema, @V_ReferencedTable ;
		END
	CLOSE CU_ReferencedTablesCursor ;
	DEALLOCATE CU_ReferencedTablesCursor ;

	SET @V_Cmd = '
		INSERT INTO ' + QUOTENAME( @V_MainName ) + '.[SubscribersTable] (
			[C_SubscriberString],
			[C_SubscriptionHash],
			[C_ProcedureSchemaName],
			[C_ProcedureName],
			[C_ProcedureParameters],
			[C_TriggerNames],
			[C_ValidTill]
		)
		VALUES (
			' + QUOTENAME( @V_SubscriberString ) + ',
			' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + ',
			' + QUOTENAME( @V_ProcedureSchemaName ) + ',
			' + QUOTENAME( @V_ProcedureName ) + ',
			' + @V_ProcedureParametersXlm + ',
			' + @V_TriggerNames + ',
			''' + CONVERT(varchar(24), DATEADD( s, @V_NotificationValidFor, GETDATE() ), 21) + ''',
		) ;
	'
	EXEC sp_executesql @V_Cmd ;
	RETURN 0 ;
END ;


