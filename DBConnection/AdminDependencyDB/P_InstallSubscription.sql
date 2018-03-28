CREATE PROCEDURE [<3>].[P_InstallSubscription]
	@V_SubscriberString NVARCHAR(200),
	@V_SubscriptionHash INT,
	@V_ProcedureSchemaName SYSNAME,
	@V_ProcedureName SYSNAME,
	@TBL_ProcedureParameters dbo.TYPE_ParametersType READONLY,
	@V_NotificationValidFor INT = 432000 -- 5 days to receive notification
AS 
BEGIN
	
	DECLARE @V_Cmd NVARCHAR(max);
	SET ANSI_NULLS ON;
	SET QUOTED_IDENTIFIER ON;
	SET NOCOUNT ON; 

	DECLARE @V_DBName SYSNAME = '<0>' ;
	DECLARE @V_MainName SYSNAME = '<1>' ;
	DECLARE @V_LoginName SYSNAME = '<2>' ;
	DECLARE @V_SchemaName SYSNAME = '<3>' ;
	DECLARE @V_UserName SYSNAME = '<4>' ;
	DECLARE @V_QueueName SYSNAME = '<5>' ;
	DECLARE @V_ServiceName SYSNAME = '<6>' ;
	DECLARE @V_SubscribersTableName SYSNAME = '<7>' ;

	DECLARE @V_ExceptionMessage NVARCHAR(max);
	
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
	
	IF EXISTS(
		SELECT name
		FROM sys.parameters AS SysParameters
		WHERE SysParameters.name not in (
				SELECT 
					CASE WHEN SUBSTRING(PName,1,1) !='@'
					THEN '@'
					ELSE ''
					END + PName AS name
				FROM @TBL_ProcedureParameters AS ProcedureParameters
			)
			AND SysParameters.object_id = object_id( @V_ProcedureSchemaName + '.' +@V_ProcedureName )
	)
		BEGIN;
			SET @V_ExceptionMessage  = 'All procedure parameters must be declared in @TBL_ProcedureParameters. This includes default value parameters. ';
			THROW 99994, @V_ExceptionMessage , 1;
		END

	DECLARE @V_ProcedureParametersDeclaration NVARCHAR(max) ;
	SET @V_ProcedureParametersDeclaration = ISNULL(
			(SELECT CASE 
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
				END + ' , '  
			FROM @TBL_ProcedureParameters 
			FOR XML PATH(''))
		,'') ;
	IF ( @V_ProcedureParametersDeclaration IS NOT NULL
		AND LEN(@V_ProcedureParametersDeclaration) > 2 )
		SET @V_ProcedureParametersDeclaration = SUBSTRING (@V_ProcedureParametersDeclaration , 0, LEN(@V_ProcedureParametersDeclaration) -1 );


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
		WHERE QUOTENAME( schemas.name ) = QUOTENAME( @V_ProcedureSchemaName )
			AND QUOTENAME( procedures.name ) = QUOTENAME( @V_ProcedureName ) ;
	IF @V_ProcedureText IS NULL
		BEGIN;
			SET @V_ExceptionMessage  = 'Procedure text was not found - ' + QUOTENAME( @V_ProcedureSchemaName ) + '.' + QUOTENAME( @V_ProcedureName );
			THROW 99997, @V_ExceptionMessage , 1;
		END
	SET @V_ProcedureText = REPLACE( @V_ProcedureText , 'RETURN ', '-- RETURN ');

	-- get rid of begining of procedure
	DECLARE @V_startPoz INT = ( CHARINDEX( 'BEGIN', @V_ProcedureText )) ;
	DECLARE @V_startPozTest CHAR = SUBSTRING( @V_ProcedureText, @V_startPoz - 1, 1) ;
	DECLARE @V_iter INT = 0 ;
	WHILE NOT ( (ascii(@V_startPozTest)>=65 and ascii(@V_startPozTest)<=90) 
			OR (ascii(@V_startPozTest)>=97 and ascii(@V_startPozTest)<=122) )
		AND ( @V_startPoz - @V_iter ) > 1
		BEGIN
			SET @V_iter = @V_iter + 1 ;
			SET @V_startPozTest = SUBSTRING( @V_ProcedureText, @V_startPoz - @V_iter, 1) ;
		END
	IF( @V_startPoz - @V_iter <= 1)
		OR NOT ( @V_startPozTest = 'S' AND SUBSTRING( @V_ProcedureText, @V_startPoz - @V_iter-1, 1)  = 'A')
		BEGIN
			print @V_startPozTest
			SET @V_ExceptionMessage  = 'Procedure text must start with ''AS BEGIN'' and end with ''END'' - ' + QUOTENAME( @V_ProcedureSchemaName ) + '.' + QUOTENAME( @V_ProcedureName );
			THROW 99996, @V_ExceptionMessage , 1;
		END
	
	SET @V_ProcedureText = SUBSTRING(@V_ProcedureText , @V_startPoz ,LEN( @V_ProcedureText ) - @V_startPoz + 1) ;
	
	-- get result table definition
	DECLARE @V_ResultTableDefinition NVARCHAR(max)
	SET @V_ResultTableDefinition =
		(SELECT ',' + QUOTENAME( ISNULL (TBL_ResultDefinition.name, 'NoNameColumn' ) + '_' + CAST( TBL_ResultDefinition.column_ordinal AS SYSNAME) ) + ' ' + TBL_ResultDefinition.system_type_name --+   CHAR(10) 
		FROM [sys].[dm_exec_describe_first_result_set] ( @V_ProcedureText, @V_ProcedureParametersDeclaration, 0) AS TBL_ResultDefinition
		FOR XML PATH('')) ;

	IF (@V_ResultTableDefinition IS NULL 
		OR @V_ResultTableDefinition = ''
	)
		BEGIN
			SET @V_ExceptionMessage = 'Procedure text is too complex. Sys.dm_exec_describe_first_result_set cannot determine its return table schema. Modify Your procedure in a way it will return consistent first result set types. - ' + QUOTENAME( @V_ProcedureSchemaName ) + '.' + QUOTENAME( @V_ProcedureName );
			THROW 99996, @V_ExceptionMessage , 1;
		END
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
	DECLARE @V_ReferencedTableType SYSNAME ;
	DECLARE @V_ReferencedTableTypeDefinition NVARCHAR(max) ;
	BEGIN TRANSACTION 
		DECLARE CU_ReferencedTablesCursor CURSOR FOR
			SELECT [SchemaName], 
				[TableName]
			FROM @TBL_ReferencedTables ;
		OPEN CU_ReferencedTablesCursor ;
		FETCH NEXT FROM CU_ReferencedTablesCursor 
			INTO @V_ReferencedSchema, @V_ReferencedTable ;
		WHILE @@FETCH_STATUS = 0
			BEGIN
			
				-- need to create type to pass data to dynamic sql
				IF( LEN( 'TYPE_' + @V_MainName + '_' + @V_ReferencedSchema + '_' + @V_ReferencedTable + '_' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) ) > 127)
					BEGIN
						ROLLBACK TRANSACTION
						SET @V_ExceptionMessage = 'Name ''TYPE_' + @V_MainName + '_' + @V_ReferencedSchema + '_' + @V_ReferencedTable + '_' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + ''' exeeds 127 chars. Consider renaming ''' + @V_MainName + ''', '''+ @V_ReferencedSchema + ''', '''+ @V_ReferencedTable + ''' to shorter names. ';
						THROW 99994, @V_ExceptionMessage , 1;
					END
				SET @V_ReferencedTableType = 'TYPE_' + @V_MainName + '_' + @V_ReferencedSchema + '_' + @V_ReferencedTable + '_' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) ;
			
				IF NOT EXISTS (
					SELECT SysTypes.name 
					FROM sys.types AS SysTypes
					INNER JOIN sys.schemas AS SysSchemas
						ON SysSchemas.schema_id = SysTypes.schema_id
						AND SysSchemas.name = @V_SchemaName
					WHERE 
						SysTypes.is_table_type = 1  
						AND SysTypes.name = @V_ReferencedTableType
				)
				BEGIN
					SET @V_ReferencedTableTypeDefinition = (
						SELECT ', ' + QUOTENAME( COLUMN_NAME ) + ' ' + QUOTENAME( DATA_TYPE ) + ' ' + ISNULL( '(' + CAST( CHARACTER_MAXIMUM_LENGTH AS SYSNAME) + ') NULL' , ' NULL' ) 
						FROM INFORMATION_SCHEMA.COLUMNS
						WHERE TABLE_NAME = @V_ReferencedTable
							AND TABLE_SCHEMA = @V_ReferencedSchema
						FOR XML PATH('')) ;
					SET @V_ReferencedTableTypeDefinition = SUBSTRING( @V_ReferencedTableTypeDefinition , 2 , LEN(@V_ReferencedTableTypeDefinition))
				
					SET @V_Cmd = '
						CREATE TYPE ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + ' AS TABLE (
						' + @V_ReferencedTableTypeDefinition + '
						); ' ;
					EXEC sp_executesql @V_Cmd ;
				END

				SET @V_TriggerName = 'T_' + @V_MainName + '_' + @V_ReferencedSchema + '_' + @V_ReferencedTable + '_' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) ;
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
						SET XACT_ABORT OFF;

						IF( GETDATE() > ''' + CONVERT(varchar(24), DATEADD( s, @V_NotificationValidFor, GETDATE() ), 21) + ''')
							RETURN ;

						DECLARE @V_Message NVARCHAR(MAX) ;
						DECLARE @V_MessageParameters NVARCHAR(MAX) ; 
						DECLARE @V_MessageInserted NVARCHAR(MAX) ;
						DECLARE @V_MessageDeleted NVARCHAR(MAX) ;
						DECLARE @V_MessageError NVARCHAR(MAX) ;
						DECLARE @V_Retval NVARCHAR(MAX) ;
						DECLARE @V_Cmd NVARCHAR(MAX) ;
						
						DECLARE @V_TransactionName NVARCHAR(30) = ''TranSave_' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + ''' ;

						BEGIN TRY
							SAVE TRANSACTION @V_TransactionName ;  
					
							' + @V_ResultTableDefinition + '
									
							-- inserted rows
							IF EXISTS (
								SELECT * 
									FROM INSERTED
							)
								BEGIN
							
									DECLARE @TBL_INSERTED ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + '
									INSERT INTO @TBL_INSERTED
									SELECT * 
									FROM INSERTED
							
									SET @V_Cmd = 
										''' + REPLACE( 'DECLARE ' + @V_ProcedureParametersDeclaration , '''', '''''' ) + ''' +
										''' + REPLACE( 
												REPLACE( 
													REPLACE( @V_ProcedureText, @V_ReferencedQuotedTable, '@TBL_INSERTED') 
												, @V_ReferencedNonQuotedTable , '@TBL_INSERTED') 
											, '''', '''''' ) + ''' ;


									INSERT INTO @TBL_ResultTable
									EXEC sp_executesql @V_Cmd, N'' @TBL_INSERTED ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + ' READONLY '', @TBL_INSERTED ;
							
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

									DECLARE @TBL_DELETED ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + '
									INSERT INTO @TBL_DELETED
									SELECT * 
									FROM DELETED
							
									SET @V_Cmd = 
										''' + REPLACE( 'DECLARE ' + @V_ProcedureParametersDeclaration , '''', '''''' ) + ''' +
										''' + REPLACE( 
												REPLACE( 
													REPLACE( @V_ProcedureText, @V_ReferencedQuotedTable, '@TBL_DELETED'  ) 
												, @V_ReferencedNonQuotedTable , '@TBL_DELETED' ) 
											, '''', '''''' ) + ''' ;


									INSERT INTO @TBL_ResultTable
									EXEC sp_executesql @V_Cmd, N'' @TBL_DELETED ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + ' READONLY '', @TBL_DELETED ;
							
									SET @V_MessageDeleted = 
										(SELECT *
											FROM @TBL_ResultTable
											FOR XML PATH(''row''), ROOT(''deleted'')) ;

									DELETE FROM @TBL_ResultTable ;
								END

						END TRY
						BEGIN CATCH
						
							ROLLBACK TRANSACTION @V_TransactionName ; 

							SET @V_MessageError = 
								(SELECT 
										ISNULL(ERROR_NUMBER(),'''') AS [number]  
										,ISNULL(ERROR_SEVERITY(),'''') AS [severity]  
										,ISNULL(ERROR_STATE(),'''')  AS [state]  
										,ISNULL(ERROR_PROCEDURE(),'''') AS [procedure]  
										,ISNULL(ERROR_LINE(),'''')  AS [linenb]  
										,ISNULL(ERROR_MESSAGE(),'''')  AS [message]  
									FOR XML PATH(''error'')
								) ;

						END CATCH

						-- send message
						IF @V_MessageInserted IS NOT NULL 
							OR @V_MessageDeleted IS NOT NULL
							OR @V_MessageError IS NOT NULL
							BEGIN
								DECLARE @V_SubscriberString NVARCHAR(200) ;
								DECLARE @V_SubscriberValidTill DATETIME ;
								DECLARE CU_SubscribersCursor CURSOR FOR
									SELECT TBL_SubscribersTable.C_SubscriberString,
										TBL_SubscribersTable.C_ValidTill
									FROM ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' AS TBL_SubscribersTable
									WHERE TBL_SubscribersTable.C_SubscriptionHash = ' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + '
										AND TBL_SubscribersTable.C_ProcedureSchemaName = ''' + QUOTENAME( @V_ProcedureSchemaName ) + '''
										AND TBL_SubscribersTable.C_ProcedureName = ''' + QUOTENAME( @V_ProcedureName ) + '''
										AND TBL_SubscribersTable.C_ProcedureParameters = ''' + @V_ProcedureParametersXlm + '''
										AND TBL_SubscribersTable.C_ValidTill > GETDATE() ;

								OPEN CU_SubscribersCursor ;
								FETCH NEXT FROM CU_SubscribersCursor 
									INTO @V_SubscriberString,
										@V_SubscriberValidTill;
								WHILE @@FETCH_STATUS = 0 
									BEGIN
										SET @V_Message = ''<notification type="data" servicename="' + @V_MainName + '" subscriberstring="'' + @V_SubscriberString + ''" validtill="'' + CONVERT( varchar(24), @V_SubscriberValidTill, 21) + ''">''
										SET @V_Message = @V_Message + ''' + @V_ProcedureParametersXlm + '''		
										IF @V_MessageInserted IS NOT NULL 
											SET @V_Message = @V_Message + @V_MessageInserted ;
										IF @V_MessageDeleted IS NOT NULL 
											SET @V_Message = @V_Message + @V_MessageDeleted ;
										IF @V_MessageError IS NOT NULL  
											SET @V_Message = @V_Message + @V_MessageError ;
										SET @V_Message = @V_Message + ''</notification>''
									
                						DECLARE @V_ConvHandle UNIQUEIDENTIFIER
                						BEGIN DIALOG @V_ConvHandle 
											FROM SERVICE ' + QUOTENAME( @V_ServiceName ) + ' 
											TO SERVICE ''' + @V_ServiceName + ''' 
											ON CONTRACT [DEFAULT] 
											WITH ENCRYPTION = OFF, 
											LIFETIME = ' + CAST( @V_NotificationValidFor AS NVARCHAR(200)) + '; 
										SEND ON CONVERSATION @V_ConvHandle 
											MESSAGE TYPE [DEFAULT] (@V_Message);
										END CONVERSATION @V_ConvHandle;
										FETCH NEXT FROM CU_SubscribersCursor 
											INTO @V_SubscriberString,
												@V_SubscriberValidTill ;
									END
								CLOSE CU_SubscribersCursor ;
								DEALLOCATE CU_SubscribersCursor ;
							END
					END 
				' ;
					-- lock whole table
					SET @V_Cmd = '
						DECLARE @V_Dummy int
						SELECT TOP 1 
								@V_Dummy = 1 
							FROM ' + @V_ReferencedQuotedTable + '
							WITH (UPDLOCK, TABLOCKX, HOLDLOCK) ;
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
				
				FETCH NEXT FROM CU_ReferencedTablesCursor 
					INTO @V_ReferencedSchema, @V_ReferencedTable ;
			END
		CLOSE CU_ReferencedTablesCursor ;
		DEALLOCATE CU_ReferencedTablesCursor ;

		SET @V_Cmd = '
		
			IF EXISTS (
				SELECT [C_SubscriptionHash]
				FROM ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' AS TBL_SubscribersTable
				WHERE [C_SubscriberString] = ''' + QUOTENAME( @V_SubscriberString ) + '''
					AND [C_SubscriptionHash] = ' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + '
					AND [C_ProcedureSchemaName] = ''' + QUOTENAME( @V_ProcedureSchemaName ) + '''
					AND [C_ProcedureName] = ''' + QUOTENAME( @V_ProcedureName ) + '''
					AND [C_ProcedureParameters] = ''' + @V_ProcedureParametersXlm + '''
					AND [C_TriggerNames] = ''' + @V_TriggerNames + '''
					AND [C_ValidTill] > GETDATE()
			)
				BEGIN
					UPDATE ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_SubscribersTableName ) + '
					SET [C_ValidTill] = ''' + CONVERT(varchar(24), DATEADD( s, @V_NotificationValidFor, GETDATE() ), 21) + '''
					WHERE [C_SubscriberString] = ''' +  @V_SubscriberString  + '''
						AND [C_SubscriptionHash] = ' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + '
						AND [C_ProcedureSchemaName] = ''' + QUOTENAME( @V_ProcedureSchemaName ) + '''
						AND [C_ProcedureName] = ''' + QUOTENAME( @V_ProcedureName ) + '''
						AND [C_ProcedureParameters] = ''' + @V_ProcedureParametersXlm + '''
						AND [C_TriggerNames] = ''' + @V_TriggerNames + '''
						AND [C_ValidTill] > GETDATE()
				END
			ELSE
				BEGIN
					INSERT INTO ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME( @V_SubscribersTableName ) + ' (
						[C_SubscriberString],
						[C_SubscriptionHash],
						[C_ProcedureSchemaName],
						[C_ProcedureName],
						[C_ProcedureParameters],
						[C_TriggerNames],
						[C_ValidTill]
					)
					VALUES (
						''' + @V_SubscriberString  + ''',
						' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + ',
						''' + QUOTENAME( @V_ProcedureSchemaName ) + ''',
						''' + QUOTENAME( @V_ProcedureName ) + ''',
						''' + @V_ProcedureParametersXlm + ''',
						''' + @V_TriggerNames + ''',
						''' + CONVERT(varchar(24), DATEADD( s, @V_NotificationValidFor, GETDATE() ), 21) + '''
					) ;
				END
		'
		EXEC sp_executesql @V_Cmd ;
	COMMIT TRANSACTION;
	RETURN 
END ;


