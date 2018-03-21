CREATE 
PROCEDURE [{2}].[P_InstallSubscription]
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
--	@V_ProcedureName SYSNAME = 'P_TestProcedure',
--	@TBL_ProcedureParameters [dbo].[TYPE_ParametersType] ,
--	@V_NotificationValidFor INT = 30

--INSERT INTO @TBL_ProcedureParameters (PName, Ptype, PValue)
--VALUES ('@param1', 'int', -1) , ('@param2', 'int', -1)
BEGIN
	
	SET NOCOUNT ON; 
	DECLARE @V_MainName SYSNAME = '{0}' ;
	DECLARE @V_Cmd NVARCHAR(max);

	DECLARE @V_LoginName SYSNAME = 'L_' + @V_MainName;
	DECLARE @V_SchemaName SYSNAME = '{2}';
	DECLARE @V_UserName SYSNAME = 'U_' + @V_MainName;
	DECLARE @V_QueueName SYSNAME = 'Q_' + @V_MainName;
	DECLARE @V_ServiceName SYSNAME = '{1}' ;
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
		WHERE QUOTENAME( schemas.name ) = QUOTENAME( @V_ProcedureSchemaName )
			AND QUOTENAME( procedures.name ) = QUOTENAME( @V_ProcedureName ) ;
	IF @V_ProcedureText IS NULL
		BEGIN;
			SET @V_ExceptionMessage  = 'Procedure text was not found - ' + QUOTENAME( @V_ProcedureSchemaName ) + '.' + QUOTENAME( @V_ProcedureName );
			THROW 99997, @V_ExceptionMessage , 1;
		END
	SET @V_ProcedureText = REPLACE( @V_ProcedureText , 'RETURN ', '-- RETURN ');

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
		(SELECT ',' + QUOTENAME( ISNULL (TBL_ResultDefinition.name, 'NoNameColumn' + CAST( TBL_ResultDefinition.column_ordinal AS SYSNAME)) ) + ' ' + TBL_ResultDefinition.system_type_name --+   CHAR(10) 
		FROM [sys].[dm_exec_describe_first_result_set] ( @V_ProcedureText, null, 0) AS TBL_ResultDefinition
		FOR XML PATH('')) ;

	IF @V_ResultTableDefinition IS NULL OR @V_ResultTableDefinition = ''
		BEGIN;
			SET @V_ExceptionMessage = 'Procedure text is to complex. sys.dm_exec_describe_first_result_set cannot determine its return table schema.';
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
			SET @V_ReferencedTableType = 'TYPE_' + @V_ReferencedSchema + '_' + @V_ReferencedTable;
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

					IF( GETDATE() > ''' + CONVERT(varchar(24), DATEADD( s, @V_NotificationValidFor, GETDATE() ), 21) + ''')
						RETURN ;

					DECLARE @V_Message NVARCHAR(MAX) ;
					DECLARE @V_MessageInserted NVARCHAR(MAX) ;
					DECLARE @V_MessageParameters NVARCHAR(MAX) ; 
					DECLARE @V_MessageDeleted NVARCHAR(MAX) ;
					DECLARE @V_Retval NVARCHAR(MAX) ;
					DECLARE @V_Cmd NVARCHAR(MAX) ;

					DECLARE @V_Debug NVARCHAR(MAX) ;

					SET @V_Debug = ''''
					INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
					VALUES ( @V_Debug, ''Trigger started'' )


					' + @V_ResultTableDefinition + '
									
					-- inner procedure
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

							SET @V_Debug = (
								SELECT *
								FROM INSERTED
								FOR XML AUTO
							)
							INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
							VALUES ( @V_Debug, ''INSERTED Data'' )

							SET @V_Cmd = 
								''' + REPLACE( 
										REPLACE( 
											REPLACE( @V_ProcedureText, @V_ReferencedQuotedTable, '@TBL_INSERTED') 
										, @V_ReferencedNonQuotedTable , '@TBL_INSERTED') 
									, '''', '''''' ) + ''' ;


							INSERT INTO @TBL_ResultTable
							EXEC sp_executesql @V_Cmd, N'' @TBL_INSERTED ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + ' READONLY '', @TBL_INSERTED = @TBL_INSERTED ;

							SET @V_Debug = (
								SELECT *
								FROM @TBL_ResultTable
								FOR XML AUTO
							)
							INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
							VALUES ( @V_Debug, ''ResultTable inserted Data'' )

							SET @V_MessageInserted = 
								(SELECT *
									FROM @TBL_ResultTable
									FOR XML PATH(''row''), ROOT(''inserted'')) ;

							SET @V_Debug = @V_MessageInserted
							INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
							VALUES ( @V_Debug, ''MessageInserted Data'' )

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

							SET @V_Debug = (
								SELECT *
								FROM DELETED
								FOR XML AUTO
							)
							INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
							VALUES ( @V_Debug, ''DELETED Data'' )

							SET @V_Cmd = 
								''' + REPLACE( 
										REPLACE( 
											REPLACE( @V_ProcedureText, @V_ReferencedQuotedTable, '@TBL_DELETED'  ) 
										, @V_ReferencedNonQuotedTable , '@TBL_DELETED' ) 
									, '''', '''''' ) + ''' ;


							INSERT INTO @TBL_ResultTable
							EXEC sp_executesql @V_Cmd, N'' @TBL_DELETED ' + QUOTENAME( @V_SchemaName ) + '.' + QUOTENAME(@V_ReferencedTableType) + ' READONLY '', @TBL_DELETED = @TBL_DELETED ;

							SET @V_Debug = (
								SELECT *
								FROM @TBL_ResultTable
								FOR XML AUTO
							)
							INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
							VALUES ( @V_Debug, ''ResultTable Deleted Data'' )

							SET @V_MessageDeleted = 
								(SELECT *
									FROM @TBL_ResultTable
									FOR XML PATH(''row''), ROOT(''deleted'')) ;

							SET @V_Debug = @V_MessageDeleted
							INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
							VALUES ( @V_Debug, ''MessageDeleted Data'' )

							DELETE FROM @TBL_ResultTable ;
						END

					IF @V_MessageInserted IS NOT NULL 
						OR @V_MessageDeleted IS NOT NULL
						BEGIN
							DECLARE @V_SubscriberString NVARCHAR(200) ;
							DECLARE CU_SubscribersCursor CURSOR FOR
								SELECT TBL_SubscribersTable.C_SubscriberString
								FROM ' + QUOTENAME( @V_SchemaName ) + '.[TBL_SubscribersTable] 
								WHERE TBL_SubscribersTable.C_SubscriptionHash = ' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + '
									AND TBL_SubscribersTable.C_ProcedureSchemaName = ''' + QUOTENAME( @V_ProcedureSchemaName ) + '''
									AND TBL_SubscribersTable.C_ProcedureName = ''' + QUOTENAME( @V_ProcedureName ) + '''
									AND TBL_SubscribersTable.C_ProcedureParameters = ''' + @V_ProcedureParametersXlm + '''
									AND TBL_SubscribersTable.C_ValidTill > GETDATE() ;

							OPEN CU_SubscribersCursor ;
							FETCH NEXT FROM CU_SubscribersCursor 
								INTO @V_SubscriberString ;
							WHILE @@FETCH_STATUS = 0 
								BEGIN
									-- create final message
									SET @V_Message = ''<notification subscriberstring="'' + @V_SubscriberString + ''">''
									SET @V_Message = @V_Message + ''' + @V_ProcedureParametersXlm + '''
									IF @V_MessageInserted IS NOT NULL 
										SET @V_Message = @V_Message + @V_MessageInserted
									IF @V_MessageDeleted IS NOT NULL 
										SET @V_Message = @V_Message + @V_MessageDeleted
									SET @V_Message = @V_Message + ''</notification>''

									SET @V_Debug = @V_Message
									INSERT INTO dbo.TBL_DebugTable ( xmltext, msg )
									VALUES ( @V_Debug, ''Message Data'' )

									--Beginning of dialog...
                					DECLARE @V_ConvHandle UNIQUEIDENTIFIER
                					--Determine the Initiator Service, Target Service and the Contract 
                					BEGIN DIALOG @V_ConvHandle 
										FROM SERVICE ' + QUOTENAME( @V_ServiceName ) + ' 
										TO SERVICE ''' + @V_ServiceName + ''' 
										ON CONTRACT [DEFAULT] 
										WITH ENCRYPTION = OFF, 
										LIFETIME = ' + CAST( @V_NotificationValidFor AS NVARCHAR(200)) + '; 
									--Send the Message
									SEND ON CONVERSATION @V_ConvHandle 
										MESSAGE TYPE [DEFAULT] (@V_Message);
									--End conversation
									END CONVERSATION @V_ConvHandle;
									FETCH NEXT FROM CU_SubscribersCursor 
										INTO @V_SubscriberString ;
								END
							CLOSE CU_SubscribersCursor ;
							DEALLOCATE CU_SubscribersCursor ;
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
				
			COMMIT TRANSACTION;
			FETCH NEXT FROM CU_ReferencedTablesCursor 
				INTO @V_ReferencedSchema, @V_ReferencedTable ;
		END
	CLOSE CU_ReferencedTablesCursor ;
	DEALLOCATE CU_ReferencedTablesCursor ;

	SET @V_Cmd = '
		
		IF EXISTS (
			SELECT [C_SubscriptionHash]
			FROM ' + QUOTENAME( @V_SchemaName ) + '.[TBL_SubscribersTable] AS TBL_SubscribersTable
			WHERE [C_SubscriberString] = ''' + QUOTENAME( @V_SubscriberString ) + '''
				AND [C_SubscriptionHash] = ' + CAST( @V_SubscriptionHash AS NVARCHAR(200)) + '
				AND [C_ProcedureSchemaName] = ''' + QUOTENAME( @V_ProcedureSchemaName ) + '''
				AND [C_ProcedureName] = ''' + QUOTENAME( @V_ProcedureName ) + '''
				AND [C_ProcedureParameters] = ''' + @V_ProcedureParametersXlm + '''
				AND [C_TriggerNames] = ''' + @V_TriggerNames + '''
				AND [C_ValidTill] > GETDATE()
		)
			BEGIN
				UPDATE ' + QUOTENAME( @V_SchemaName ) + '.[TBL_SubscribersTable]
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
				INSERT INTO ' + QUOTENAME( @V_SchemaName ) + '.[TBL_SubscribersTable] (
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
	RETURN 
END ;


