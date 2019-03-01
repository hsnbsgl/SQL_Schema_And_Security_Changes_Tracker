---CREATE DATABASE [_Schema_Changes];

/*Schema altering users should be created in this database*/

USE [_Schema_Changes]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE OR ALTER PROCEDURE [dbo].[spCheck_DatabaseOnline]
	@argDatabaseName NVARCHAR(128), @argServerName NVARCHAR(128) = NULL, @argOutput_DatabaseOnline BIT = 0 OUTPUT, @argOutput_ErrorMessage VARCHAR(200) = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcLocalServer BIT = 1

	SELECT @argOutput_DatabaseOnline = 0, @argOutput_ErrorMessage = NULL

	IF ISNULL(@argServerName, '') <> '' AND @argServerName<>@@SERVERNAME BEGIN
		BEGIN TRY 
			SET @lcLocalServer = 0	
			EXEC sp_testlinkedserver @argServerName; 
		END TRY 
		BEGIN CATCH 
			SET @argOutput_ErrorMessage = 'Linked Server Not Available. ' + ERROR_MESSAGE()
			PRINT @argOutput_ErrorMessage;
			RETURN 0; --Server Not Available
		END CATCH
	END

	DECLARE @lcDatabaseState TINYINT, @lcDatabaseCollation NVARCHAR(128), @lcAlwaysOnDatabaseState TINYINT, @lcSQL NVARCHAR(1000)

	SET @lcSQL = '
				SELECT @lcDatabaseState = D.[state], 
						@lcDatabaseCollation = CAST(DATABASEPROPERTYEX (D.name, ''Collation'') AS  nvarchar(128)), 
						@lcAlwaysOnDatabaseState = RS.database_state
				FROM ' + IIF(@lcLocalServer=1, '', @argServerName + '.master.') + 'sys.databases D 
					LEFT JOIN ' + IIF(@lcLocalServer=1, '', @argServerName + '.master.') + 'sys.dm_hadr_database_replica_states RS ON RS.database_id = D.database_id 
				WHERE ISNULL(RS.is_local, 1)=1 AND D.name = @argDatabaseName
				'
	EXEC sp_executesql @lcSQL,			
						N'@argDatabaseName VARCHAR(128), @lcDatabaseState TINYINT OUTPUT, @lcDatabaseCollation NVARCHAR(128) OUTPUT, @lcAlwaysOnDatabaseState TINYINT OUTPUT',
						@argDatabaseName, @lcDatabaseState OUTPUT, @lcDatabaseCollation OUTPUT, @lcAlwaysOnDatabaseState OUTPUT

	IF (@lcDatabaseState <> 0) OR (@lcDatabaseCollation IS NULL) OR (@lcAlwaysOnDatabaseState IS NOT NULL AND @lcAlwaysOnDatabaseState <> 0) BEGIN
		SET @argOutput_ErrorMessage = 'Database State not online';
		PRINT @argOutput_ErrorMessage;
	END
	ELSE BEGIN
		SET @argOutput_DatabaseOnline = 1;
	END

	RETURN @argOutput_DatabaseOnline;
END
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Schema_Changes](
	[Row_ID] [int] IDENTITY(1,1) NOT NULL,
	[PostTime] [datetime] NOT NULL,
	[EventType] [varchar](128) NOT NULL,
	[LoginName] [varchar](128) NULL,
	[DatabaseName] [varchar](128) NULL,
	[SchemaName] [varchar](128) NULL,
	[ObjectName] [varchar](128) NULL,
	[ObjectType] [varchar](128) NULL,
	[CommandText] [varchar](max) NULL,
	[Uses_ANSI_NULLS] [tinyint] NULL,
	[Uses_QUOTED_IDENTIFIER] [tinyint] NULL,
	[Encrypted] [tinyint] NULL,
	[EventData] [xml] NOT NULL,
	[LOG_Date] [datetime] NOT NULL,
	[LOG_App] [varchar](200) NOT NULL,
	[LOG_Hostname] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Schema_Changes] PRIMARY KEY CLUSTERED 
(
	[Row_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Security_Changes](
	[Row_ID] [int] IDENTITY(1,1) NOT NULL,
	[PostTime] [datetime] NOT NULL,
	[EventType] [varchar](128) NOT NULL,
	[LoginName] [varchar](128) NULL,
	[DatabaseName] [varchar](128) NULL,
	[SchemaName] [varchar](128) NULL,
	[ObjectName] [varchar](128) NULL,
	[ObjectType] [varchar](128) NULL,
	[CommandText] [varchar](max) NULL,
	[Grantees] [varchar](8000) NULL,
	[Permissions] [varchar](8000) NULL,
	[EventData] [xml] NOT NULL,
	[LOG_Date] [datetime] NOT NULL,
	[LOG_App] [varchar](200) NOT NULL,
	[LOG_Hostname] [varchar](50) NOT NULL,
	[RoleName] [varchar](128) NULL,
 CONSTRAINT [PK_Security_Changes] PRIMARY KEY CLUSTERED 
(
	[Row_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO

CREATE NONCLUSTERED INDEX [IX_Schema_Changes_DatabaseName_ObjectName] ON [dbo].[Schema_Changes]
(
	[DatabaseName] ASC,
	[ObjectName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO

CREATE NONCLUSTERED INDEX [IX_Schema_Changes_ObjectName] ON [dbo].[Schema_Changes]
(
	[ObjectName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Schema_Changes] ADD  CONSTRAINT [DF_Schema_Changes_LOG_Date]  DEFAULT (getdate()) FOR [LOG_Date]
GO
ALTER TABLE [dbo].[Schema_Changes] ADD  CONSTRAINT [DF_Schema_Changes_LOG_App]  DEFAULT (app_name()) FOR [LOG_App]
GO
ALTER TABLE [dbo].[Schema_Changes] ADD  CONSTRAINT [DF_Schema_Changes_LOG_Hostname]  DEFAULT (host_name()) FOR [LOG_Hostname]
GO
ALTER TABLE [dbo].[Security_Changes] ADD  CONSTRAINT [DF_Security_Changes_LOG_Date]  DEFAULT (getdate()) FOR [LOG_Date]
GO
ALTER TABLE [dbo].[Security_Changes] ADD  CONSTRAINT [DF_Security_Changes_LOG_App]  DEFAULT (app_name()) FOR [LOG_App]
GO
ALTER TABLE [dbo].[Security_Changes] ADD  CONSTRAINT [DF_Security_Changes_LOG_Hostname]  DEFAULT (host_name()) FOR [LOG_Hostname]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE OR ALTER PROCEDURE [dbo].[spCreate_Initial_Schema_Changes_Records] 
@argDB_Name VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcSQL VARCHAR(MAX)

	IF @argDB_Name IS NULL BEGIN
		RAISERROR('@argDB_Name Parameter should not be empty', 16, 1) WITH SETERROR
		RETURN
	END

	DECLARE @lcDatabaseOnline BIT,@lcSynchronization_state TINYINT=2

	EXEC dbo.spCheck_DatabaseOnline '_Schema_Changes', NULL, @lcDatabaseOnline OUTPUT;

	SELECT @lcSynchronization_state=ISNULL(RS.synchronization_state,2) FROM sys.databases D
	INNER JOIN sys.availability_databases_cluster C ON C.group_database_id=D.group_database_id
	INNER JOIN sys.availability_groups G ON C.group_id=G.group_id
	INNER JOIN sys.dm_hadr_database_replica_states RS ON RS.database_id = D.database_id 
	WHERE D.name='_Schema_Changes' AND is_local=1
		
	IF NOT ( ISNULL(@lcSynchronization_state,2)=2 AND @lcDatabaseOnline = 1)  
		RETURN;

	CREATE TABLE #Definitions (SchemaName sysname NULL, ObjectName sysname, ObjectType CHAR(2), ObjectTypeDesc VARCHAR(60), 
								ObjectDefinition NVARCHAR(MAX), uses_ansi_nulls BIT, uses_quoted_identifier BIT, Encrypted BIT, 
								is_ms_shipped BIT, major_id INT)

	SELECT @lcSQL = 'USE ' + @argDB_Name + ';' +
					'SELECT S.name AS SchemaName, ISNULL(O.name, T.name) AS ObjectName, 
							CASE WHEN O.type IS NOT NULL THEN O.Type
									WHEN T.name IS NOT NULL THEN ''TR''
									ELSE NULL END, 
							O.type_desc, 
							ISNULL(sm.definition, ''--ENCRYPTED--''), sm.uses_ansi_nulls, sm.uses_quoted_identifier, 
							CASE WHEN sm.definition IS NULL THEN 1 ELSE 0 END, ISNULL(O.is_ms_shipped, T.is_ms_shipped), 
							(SELECT major_id FROM sys.extended_properties WITH (NOLOCK) WHERE major_id = ISNULL(O.object_id, T.object_id) AND 
									minor_id = 0 AND class = 1 AND name = N''microsoft_database_tools_support'') 
					FROM sys.sql_modules AS SM WITH (NOLOCK)
						LEFT JOIN sys.objects AS O WITH (NOLOCK) ON SM.object_id = O.object_id
						LEFT JOIN sys.triggers AS T WITH (NOLOCK) ON SM.object_id = T.object_id
						LEFT JOIN sys.schemas AS S WITH (NOLOCK) ON O.schema_id = S.schema_id
					WHERE ISNULL(O.is_ms_shipped, T.is_ms_shipped) = 0 AND (O.name NOT LIKE ''dt_%'')  '

	INSERT INTO #Definitions (SchemaName, ObjectName, ObjectType, ObjectTypeDesc, ObjectDefinition, uses_ansi_nulls, uses_quoted_identifier, Encrypted,
								is_ms_shipped, major_id) 
	EXEC (@lcSQL)

	INSERT INTO dbo.Schema_Changes (PostTime, EventType, LoginName, DatabaseName, SchemaName, ObjectName, ObjectType, CommandText,
					Uses_ANSI_NULLS, Uses_QUOTED_IDENTIFIER, Encrypted, [EventData])
	SELECT GETDATE(), 'RESTORE DB' AS EventType, ORIGINAL_LOGIN() AS LoginName, @argDB_Name AS DatabaseName, D.SchemaName, D.ObjectName, 
			CASE WHEN D.ObjectType = 'P' THEN 'PROCEDURE'
						WHEN D.ObjectType = 'V' THEN 'VIEW'
						WHEN D.ObjectType IN ('FN', 'TF', 'IF') THEN 'FUNCTION' 
						WHEN D.ObjectType = 'TR' THEN 'TRIGGER'
						ELSE D.ObjectTypeDesc END AS ObjectType, 
			D.ObjectDefinition AS CommandText, D.uses_ansi_nulls, D.uses_quoted_identifier, D.Encrypted, '' AS [EventData]
	FROM #Definitions D WITH (NOLOCK)
	WHERE (D.is_ms_shipped = 0) AND (D.major_id IS NULL) --Microsoft tarafından ship edilen system objectleri hariç (bazısını major_id den anlıyoruz.)
	ORDER BY D.ObjectName

	DROP TABLE #Definitions

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE PROCEDURE [dbo].[spGet_Object_Definition] 
	@argDatabaseName VARCHAR(128), @argSchemaName VARCHAR(128), @argObjectName VARCHAR(128), @argObjectType VARCHAR(2)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcSQL NVARCHAR(2000), @lcCRLF CHAR(2)

	IF (IS_SRVROLEMEMBER ('sysadmin') = 0) AND 
		 (ISNULL(HAS_PERMS_BY_NAME(@argDatabaseName + '.' + @argSchemaName + '.' + @argObjectName, 'OBJECT', 'VIEW DEFINITION'), 0) = 0) BEGIN
		 SELECT '--Request For View Definition Permission.' AS [Object_Definition]
		 RETURN
	END 

	IF @argObjectType='U' BEGIN --User Table
		EXEC spGet_Table_Definition @argDatabaseName, @argSchemaName, @argObjectName
	END
	ELSE BEGIN
		SELECT @lcCRLF = CHAR(13) + CHAR(10)
		SELECT @lcSQL = 'USE [' + @argDatabaseName + '];' + 
						'SELECT ''USE ['' + DB_NAME() + ''];'' + @lcCRLF + ''GO'' + @lcCRLF + 
								CASE WHEN M.uses_ansi_nulls=1 THEN ''SET ANSI_NULLS ON'' ELSE ''SET ANSI_NULLS OFF'' END + @lcCRLF + ''GO'' + @lcCRLF + 
								CASE WHEN M.uses_quoted_identifier=1 THEN ''SET QUOTED_IDENTIFIER ON'' ELSE ''SET QUOTED_IDENTIFIER OFF'' END + @lcCRLF + ''GO'' + @lcCRLF + 
								M.definition AS Object_Definition--COLLATE SQL_Latin1_General_CP1254_CI_AS 
						FROM sys.objects O
							JOIN sys.sql_modules M ON O.object_id = M.object_id
						WHERE O.name = @argObjectName AND O.schema_id = SCHEMA_ID(@argSchemaName)'

		EXEC sp_executesql @lcSQL, N'@argObjectName VARCHAR(128), @argSchemaName VARCHAR(128), @lcCRLF CHAR(2)', @argObjectName, @argSchemaName, @lcCRLF
	END
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


 
CREATE PROCEDURE [dbo].[spGet_Table_Definition] 
	@argDatabaseName VARCHAR(128), @argSchemaName VARCHAR(128), @argTableName VARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcScript VARCHAR(MAX)='', @lcSQL NVARCHAR(2000)

	SELECT @lcSQL = 'USE [' + @argDatabaseName + '];' + 
					'SELECT @lcScript = @lcScript + CHAR(9) + /*  COLLATE SQL_Latin1_General_CP1254_CI_AS  */
							''['' + C.name + ''] '' + 
							T.name + CASE WHEN T.name IN (''varchar'', ''nvarchar'', ''varbinary'') AND C.max_length=-1 THEN '' (max)'' 
												WHEN T.name IN (''varchar'', ''char'', ''varbinary'') AND C.max_length<>-1 THEN '' ('' + CAST(C.max_length AS VARCHAR) + '')'' 
												WHEN T.name IN (''nvarchar'', ''nchar'') AND C.max_length<>-1 THEN '' ('' + CAST(C.max_length/2 AS VARCHAR) + '')'' 
												WHEN T.name IN (''decimal'', ''numeric'') THEN '' ('' + CAST(C.precision AS VARCHAR) + '','' + CAST(C.scale AS VARCHAR) + '')'' 
											ELSE '''' END +
							CASE WHEN C.is_identity=1 THEN '' IDENTITY('' + CAST(IC.seed_value AS VARCHAR) + '','' + CAST(IC.increment_value AS VARCHAR) + '')'' ELSE '''' END + '' '' + 
							CASE WHEN C.is_nullable=1 THEN ''NULL'' ELSE ''NOT NULL'' END + 
							CASE WHEN D.DEFINITION IS NOT NULL THEN 
								CASE WHEN D.is_system_named=1 THEN '''' ELSE '' CONSTRAINT '' + D.NAME END + '' DEFAULT '' + D.[definition] 
							ELSE '''' END + 
							'', '' + CHAR(13)
					FROM sys.objects O
						JOIN sys.columns C ON O.object_id = C.object_id
						JOIN sys.types T ON C.user_type_id = T.user_type_id
						LEFT JOIN sys.identity_columns AS IC ON IC.object_id = C.object_id AND IC.column_id = C.column_id
						LEFT JOIN sys.default_constraints D ON C.object_id = D.parent_object_id AND C.column_id = D.parent_column_id
					WHERE O.name = @argTableName  AND O.schema_id = SCHEMA_ID(@argSchemaName)'
	--PRINT @lcSQL
	EXEC sp_executesql @lcSQL, N'@lcScript VARCHAR(MAX) OUTPUT, @argTableName VARCHAR(128), @argSchemaName VARCHAR(128)', 
								@lcScript OUTPUT, @argTableName, @argSchemaName

	---------------------------------------------------------------------------------------------------------------------------------------
	--Primary Key / Unique Constraints
	SELECT @lcSQL = 'USE [' + @argDatabaseName + '];' + 
					'SELECT @lcScript = @lcScript /* COLLATE SQL_Latin1_General_CP1254_CI_AS */ +  
						'' CONSTRAINT ['' +  I.name + ''] '' + CASE WHEN I.is_primary_key=1 THEN ''PRIMARY KEY '' ELSE ''UNIQUE '' END + 
						CASE WHEN I.index_id=1 THEN ''CLUSTERED ('' ELSE ''NONCLUSTERED ('' END +  
						STUFF((SELECT '', ['' + C.name + '']'' + CASE WHEN IC.is_descending_key=1 THEN '' DESC'' ELSE '' ASC'' END
								FROM sys.index_columns IC
									JOIN sys.columns C ON C.OBJECT_ID = IC.OBJECT_ID AND C.column_id = IC.column_id
								WHERE IC.OBJECT_ID = I.OBJECT_ID AND IC.index_id = I.index_id
								ORDER BY IC.key_ordinal
								FOR XML PATH('''')), 1, 2, '''') + ''), '' + CHAR(13)
					FROM sys.indexes I
						JOIN sys.objects O ON O.object_id = I.object_id
					WHERE (I.is_primary_key=1 OR I.is_unique_constraint=1) AND 
							O.name = @argTableName  AND O.schema_id = SCHEMA_ID(@argSchemaName)'
	--PRINT @lcSQL
	EXEC sp_executesql @lcSQL, N'@lcScript VARCHAR(MAX) OUTPUT, @argTableName VARCHAR(128), @argSchemaName VARCHAR(128)', 
								@lcScript OUTPUT, @argTableName, @argSchemaName

	---------------------------------------------------------------------------------------------------------------------------------------
	--Check Constraints
	SELECT @lcSQL = 'USE [' + @argDatabaseName + '];' + 
					'SELECT @lcScript = @lcScript /* COLLATE SQL_Latin1_General_CP1254_CI_AS */ +  
						CASE WHEN C.is_system_named=1 THEN '''' ELSE '' CONSTRAINT ['' + C.name END + ''] CHECK '' + C.[definition] + '', '' + CHAR(13)
					FROM sys.objects O
						JOIN sys.check_constraints C ON O.object_id = C.parent_object_id
					WHERE O.name = @argTableName  AND O.schema_id = SCHEMA_ID(@argSchemaName)'
	--PRINT @lcSQL
	EXEC sp_executesql @lcSQL, N'@lcScript VARCHAR(MAX) OUTPUT, @argTableName VARCHAR(128), @argSchemaName VARCHAR(128)', 
								@lcScript OUTPUT, @argTableName, @argSchemaName

	---------------------------------------------------------------------------------------------------------------------------------------
	--Foreign Keys
	SELECT @lcSQL = 'USE [' + @argDatabaseName + '];' + 
					'SELECT @lcScript = @lcScript /* COLLATE SQL_Latin1_General_CP1254_CI_AS */ +  
							'' CONSTRAINT ['' + F.name + ''] FOREIGN KEY ('' + 
							STUFF((SELECT '', ['' + C.name + '']'' 
									FROM sys.foreign_key_columns FC 
										JOIN sys.columns C ON C.object_id = FC.parent_object_id AND C.column_id = FC.parent_column_id
									WHERE FC.constraint_object_id = F.object_id
									ORDER BY FC.constraint_column_id
									FOR XML PATH('''')
							), 1, 2, '''') + 
							'') REFERENCES ['' + RO.name + '']('' + 
							STUFF((SELECT '', ['' + RC.name + '']'' 
									FROM sys.foreign_key_columns FC 
										JOIN sys.columns RC ON RC.object_id = FC.referenced_object_id AND RC.column_id = FC.referenced_column_id
									WHERE FC.constraint_object_id = F.object_id
									ORDER BY FC.constraint_column_id
									FOR XML PATH('''')
							), 1, 2, '''') + ''), '' + CHAR(13)
					FROM sys.objects O
						JOIN sys.foreign_keys F ON O.object_id = F.parent_object_id
						JOIN sys.objects RO ON F.referenced_object_id = RO.object_id
					WHERE O.name = @argTableName  AND O.schema_id = SCHEMA_ID(@argSchemaName)'

	--PRINT @lcSQL
	EXEC sp_executesql @lcSQL, N'@lcScript VARCHAR(MAX) OUTPUT, @argTableName VARCHAR(128), @argSchemaName VARCHAR(128)', 
								@lcScript OUTPUT, @argTableName, @argSchemaName

	IF ISNULL(@lcScript,'')<>''
	BEGIN
	SELECT @lcScript = 'USE [' + @argDatabaseName + '];' + CHAR(13) + 
						'GO' + CHAR(13) + 
						'CREATE TABLE [' + @argSchemaName + '].[' + @argTableName + '] (' + CHAR(13) + 
						SUBSTRING(@lcScript, 1, LEN(@lcScript)-3) + CHAR(13) + ')' 
	END

	SELECT @lcScript AS [Object_Definition]
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[spGet_CommandText] 
@argRow_ID INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CommandText
	FROM dbo.Schema_Changes SC WITH (NOLOCK)
	WHERE Row_ID = @argRow_ID AND
		((IS_SRVROLEMEMBER ('sysadmin') = 1) OR  
		 (ISNULL(HAS_PERMS_BY_NAME(SC.DatabaseName + '.' + sc.SchemaName + '.' + sc.ObjectName, 'OBJECT', 'VIEW DEFINITION'), 0) = 1)) 
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[spGet_Schema_History] 
@argTarih1 SMALLDATETIME, @argTarih2 SMALLDATETIME, @argDB_Name VARCHAR(100), @argObject_Name VARCHAR(200), @argLogin_Name VARCHAR(100), @argCommand_Text VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcTarih1 SMALLDATETIME, @lcTarih2 SMALLDATETIME
	
	SELECT @lcTarih1 = CONVERT(VARCHAR(10), @argTarih1, 121) + ' 00:00:00', 
			@lcTarih2 = CONVERT(VARCHAR(10), @argTarih2, 121) + ' 23:59:59.999'

	--CommandText, except EventData columns
	SELECT Row_ID, CONVERT(VARCHAR(100), PostTime, 121) AS PostTime, EventType, LoginName, DatabaseName, SchemaName, ObjectName, ObjectType, Uses_ANSI_NULLS, Uses_QUOTED_IDENTIFIER, 
			Encrypted, CONVERT(VARCHAR(100), LOG_Date, 121) AS LOG_Date, LOG_App, LOG_Hostname
	FROM dbo.Schema_Changes SC WITH (NOLOCK)
	WHERE (LOG_Date >= @lcTarih1 OR @lcTarih1 IS NULL) AND 
			(LOG_Date<=@lcTarih2 OR @lcTarih2 IS NULL) AND
			DatabaseName = ISNULL(@argDB_Name, DatabaseName) AND 
			(ObjectName LIKE @argObject_Name OR @argObject_Name IS NULL) AND 
			(LoginName LIKE  @argLogin_Name OR  @argLogin_Name IS NULL) AND 
			(CommandText LIKE '%' + @argCommand_Text + '%' OR @argCommand_Text IS NULL) AND
			((IS_SRVROLEMEMBER ('sysadmin') = 1) OR 
			 (ISNULL(HAS_PERMS_BY_NAME(SC.DatabaseName + '.' + sc.SchemaName + '.' + sc.ObjectName, 'OBJECT', 'VIEW DEFINITION'), 0) = 1)) 
	ORDER BY LOG_Date DESC
	--ORDER BY DatabaseName, ObjectName, LOG_Date DESC

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE OR ALTER PROCEDURE [dbo].[spLog_Schema_Change] 
@argPostTime DATETIME, @argEventType VARCHAR(128), @argLoginName VARCHAR(128), @argDatabaseName VARCHAR(128), @argSchemaName VARCHAR(128), @argObjectName VARCHAR(128), @argObjectType VARCHAR(128), 
@argCommandText VARCHAR(max), @argOption_ANSI_NULLS TINYINT, @argOption_QUOTED_IDENTIFIER TINYINT, @argEncrypted TINYINT, @argEventData XML, 
@argCheck_Key VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;
	
    INSERT INTO Schema_Changes(PostTime, EventType, LoginName, DatabaseName, SchemaName, ObjectName, ObjectType, CommandText, Uses_ANSI_NULLS, Uses_QUOTED_IDENTIFIER, Encrypted, [EventData])
    VALUES(@argPostTime, @argEventType, @argLoginName, @argDatabaseName, @argSchemaName, @argObjectName, @argObjectType, @argCommandText, 
			@argOption_ANSI_NULLS, @argOption_QUOTED_IDENTIFIER, @argEncrypted, @argEventData)

END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER  PROCEDURE [dbo].[spLog_Security_Change] 
@argPostTime DATETIME, @argEventType VARCHAR(128), @argLoginName VARCHAR(128), @argDatabaseName VARCHAR(128), @argSchemaName VARCHAR(128), @argObjectName VARCHAR(128), @argObjectType VARCHAR(128), 
@argCommandText VARCHAR(max),  @argGrantees VARCHAR(8000), @argPermissions VARCHAR(8000), @argEventData XML,  @argCheck_Key VARCHAR(100), @argRoleName VARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcMsg VARCHAR(100), @lcAppName NVARCHAR(256)
	 
		
	INSERT INTO Security_Changes(PostTime, EventType, LoginName, DatabaseName, SchemaName, ObjectName, ObjectType, CommandText, Grantees, Permissions, [EventData],  RoleName)
    VALUES(@argPostTime, @argEventType, @argLoginName, @argDatabaseName, @argSchemaName, @argObjectName, @argObjectType, @argCommandText, @argGrantees, @argPermissions, @argEventData, @argRoleName)
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE OR ALTER PROCEDURE [dbo].[spReport_List_of_DDL_Triggers] 
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @lcDB_Name VARCHAR(200), @lcSQL VARCHAR(500)

	CREATE TABLE #DDL_Triggers(DB_NAME VARCHAR(128), Trigger_Name VARCHAR(128), Trigger_Disabled TINYINT)

	DECLARE curDatabases CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT name FROM sys.databases WITH (NOLOCK)
	ORDER BY name ASC

	OPEN curDatabases
	FETCH NEXT FROM curDatabases INTO @lcDB_Name
	WHILE @@FETCH_STATUS=0
	BEGIN
		SELECT @lcSQL = 'USE ' + @lcDB_Name + ';' + 
						'SELECT ''' + @lcDB_Name + ''', name, is_disabled FROM sys.triggers WITH (NOLOCK) WHERE parent_class = 0'
		
		INSERT INTO #DDL_Triggers
		EXEC (@lcSQL)

		FETCH NEXT FROM curDatabases INTO @lcDB_Name
	END
	CLOSE curDatabases
	DEALLOCATE curDatabases

	SELECT * FROM #DDL_Triggers WITH (NOLOCK)
	
	DROP TABLE #DDL_Triggers
END
GO
 
