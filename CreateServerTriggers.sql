USE [master]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER TRIGGER [trgTrack_Schema_Changes]
ON ALL SERVER 
FOR DDL_TABLE_EVENTS, DDL_VIEW_EVENTS, DDL_INDEX_EVENTS, DDL_FUNCTION_EVENTS, DDL_PROCEDURE_EVENTS, DDL_TRIGGER_EVENTS, 
	DDL_ASSEMBLY_EVENTS, DDL_TYPE_EVENTS, 
	DDL_SYNONYM_EVENTS, DDL_FULLTEXT_CATALOG_EVENTS, DDL_DEFAULT_EVENTS, DDL_EXTENDED_PROPERTY_EVENTS, DDL_RULE_EVENTS , RENAME

AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_PADDING ON;

	DECLARE @lcPostTime DATETIME, @lcEventType VARCHAR(128), @lcLoginName VARCHAR(128), 
			@lcDatabaseName VARCHAR(128), @lcSchemaName VARCHAR(128), @lcObjectName VARCHAR(128), @lcObjectType VARCHAR(128),
			@lcCommandText varchar(MAX), @lcTempCommandText varchar(MAX), 
			@lcOption_ANSI_NULLS VARCHAR(3), @lcOption_ANSI_NULL_DEFAULT VARCHAR(3), @lcOption_ANSI_PADDING VARCHAR(3), @lcOption_QUOTED_IDENTIFIER VARCHAR(3), @lcOption_ENCRYPTED VARCHAR(5), 
			@lcOption_ANSI_NULLS_Value TINYINT, @lcOption_QUOTED_IDENTIFIER_Value TINYINT, @lcOption_ENCRYPTED_Value TINYINT,
			@lcCheck_Key VARCHAR(100)

    DECLARE @lcEventData XML;

	SET @lcEventData = EVENTDATA();
	SET @lcEventType = @lcEventData.value('(/EVENT_INSTANCE/EventType)[1]', 'sysname');

	IF EXISTS (SELECT database_id FROM sys.databases WITH (NOLOCK) WHERE NAME='_Schema_Changes') BEGIN  
		SET @lcPostTime = @lcEventData.value('(/EVENT_INSTANCE/PostTime)[1]', 'sysname');
		SET @lcLoginName = @lcEventData.value('(/EVENT_INSTANCE/LoginName)[1]', 'sysname');
		SET @lcDatabaseName = @lcEventData.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'sysname');
		SET @lcSchemaName = @lcEventData.value('(/EVENT_INSTANCE/SchemaName)[1]', 'sysname');
		SET @lcObjectName = @lcEventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'sysname'); 
		SET @lcObjectType = @lcEventData.value('(/EVENT_INSTANCE/ObjectType)[1]', 'sysname');
		SET @lcCommandText = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'varchar(max)');
		
		SET @lcOption_ANSI_NULLS = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/SetOptions/@ANSI_NULLS)[1]', 'varchar(3)');
		SET @lcOption_ANSI_NULL_DEFAULT = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/SetOptions/@ANSI_NULL_DEFAULT)[1]', 'varchar(3)');
		SET @lcOption_ANSI_PADDING = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/SetOptions/@ANSI_PADDING)[1]', 'varchar(3)');
		SET @lcOption_QUOTED_IDENTIFIER = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/SetOptions/@QUOTED_IDENTIFIER)[1]', 'varchar(3)');
		SET @lcOption_ENCRYPTED = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/SetOptions/@ENCRYPTED)[1]', 'varchar(5)');

		SELECT @lcOption_ANSI_NULLS_Value = CASE WHEN UPPER(@lcOption_ANSI_NULLS) = 'ON' THEN 1 
												WHEN UPPER(@lcOption_ANSI_NULLS) = 'OFF' THEN 0
											ELSE NULL END,
			   @lcOption_QUOTED_IDENTIFIER_Value = CASE WHEN UPPER(@lcOption_QUOTED_IDENTIFIER) = 'ON' THEN 1 
														WHEN UPPER(@lcOption_QUOTED_IDENTIFIER) = 'OFF' THEN 0
													ELSE NULL END,	
			   @lcOption_ENCRYPTED_Value = CASE WHEN UPPER(@lcOption_ENCRYPTED) = 'TRUE' THEN 1
												WHEN UPPER(@lcOption_ENCRYPTED) = 'FALSE' THEN 0
											ELSE NULL END

		-----------------------------------------------------------------------------------------------------------------------------------------------			   
		--Exceptions

		IF @lcDatabaseName IN ('master', 'model', 'msdb', 'tempdb') RETURN  

		IF   (APP_NAME() LIKE 'SQLAgent - TSQL JobStep%') AND (HOST_NAME() = @@SERVERNAME) RETURN --Maintenance Plan etc.
		 
		IF @lcObjectName IN ('sysdiagrams', 'sp_upgraddiagrams', 'sp_helpdiagrams', 'sp_helpdiagramdefinition', 'sp_creatediagram', 
								'sp_renamediagram', 'sp_alterdiagram', 'sp_dropdiagram', 'fn_diagramobjects') RETURN --Diagram objects
	 
	
		-----------------------------------------------------------------------------------------------------------------------------------------------			   
		EXEC [_Schema_Changes].dbo.spLog_Schema_Change @lcPostTime, @lcEventType, @lcLoginName, @lcDatabaseName, @lcSchemaName, @lcObjectName, @lcObjectType, @lcCommandText, 
				@lcOption_ANSI_NULLS_Value, @lcOption_QUOTED_IDENTIFIER_Value, @lcOption_ENCRYPTED_Value, @lcEventData, @lcCheck_Key
	END
END;


GO

ENABLE TRIGGER [trgTrack_Schema_Changes] ON ALL SERVER
GO


USE [master]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE  TRIGGER [trgTrack_Security_Changes]
ON ALL SERVER 
FOR DDL_USER_EVENTS,DDL_ROLE_EVENTS,GRANT_SERVER,GRANT_DATABASE,REVOKE_SERVER,REVOKE_DATABASE,ADD_SERVER_ROLE_MEMBER,DROP_SERVER_ROLE_MEMBER
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_PADDING ON;

	DECLARE @lcPostTime DATETIME, @lcEventType VARCHAR(128), @lcLoginName VARCHAR(128),	@lcDatabaseName VARCHAR(128), @lcSchemaName VARCHAR(128), 
			@lcObjectName VARCHAR(128), @lcObjectType VARCHAR(128),	@lcCommandText varchar(MAX), @lcTempCommandText varchar(MAX), 
			@lcGrantees varchar(8000), @lcPermissions varchar(8000), @lcCheck_Key VARCHAR(100), @lcRoleName varchar(128)

    DECLARE @lcEventData XML;

	SET @lcEventData = EVENTDATA();
	SET @lcEventType = @lcEventData.value('(/EVENT_INSTANCE/EventType)[1]', 'sysname');
	SET @lcRoleName = LTRIM(RTRIM(@lcEventData.value('(/EVENT_INSTANCE/RoleName)[1]', 'sysname')));

	IF ((EXISTS (SELECT NAME FROM sys.database_principals WITH (NOLOCK) WHERE (is_fixed_role  = 1  AND NAME = @lcRoleName)) OR 
				@lcEventType = 'CREATE_ROLE' OR 
				@lcEventType = 'ALTER_ROLE' OR 
				@lcEventType = 'DROP_ROLE') 
		AND IS_SRVROLEMEMBER ('sysadmin') = 0 ) 
	BEGIN
		RAISERROR ('Only DBA can alter server roles ',  16, 1) WITH SETERROR;	
		ROLLBACK; 
		RETURN
	END	
	IF EXISTS (SELECT database_id FROM sys.databases WITH (NOLOCK) WHERE NAME='_Schema_Changes') BEGIN --Bu Server da [_Schema_Changes] veritabanı varsa.
		SET @lcPostTime = @lcEventData.value('(/EVENT_INSTANCE/PostTime)[1]', 'sysname');
		SET @lcLoginName = @lcEventData.value('(/EVENT_INSTANCE/LoginName)[1]', 'sysname');
		SET @lcDatabaseName = @lcEventData.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'sysname');
		SET @lcSchemaName = @lcEventData.value('(/EVENT_INSTANCE/SchemaName)[1]', 'sysname');
		SET @lcObjectName = @lcEventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'sysname'); 
		SET @lcObjectType = @lcEventData.value('(/EVENT_INSTANCE/ObjectType)[1]', 'sysname');
		SET @lcCommandText = @lcEventData.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'varchar(max)');	
		SELECT @lcGrantees = STUFF((SELECT ','+ x.value('.[1]', 'varchar(100)') FROM @lcEventData.nodes('/EVENT_INSTANCE/Grantees/Grantee') t(x) FOR XML PATH('')),1,1,'') 
		SELECT @lcPermissions = STUFF((SELECT ','+ x.value('.[1]', 'varchar(100)') FROM @lcEventData.nodes('/EVENT_INSTANCE/Permissions/Permission') t(x) FOR XML PATH('')),1,1,'')  	
		-----------------------------------------------------------------------------------------------------------------------------------------------			   
		EXEC [_Schema_Changes].dbo.spLog_Security_Change @lcPostTime, @lcEventType, @lcLoginName, @lcDatabaseName, @lcSchemaName, @lcObjectName, @lcObjectType, @lcCommandText, @lcGrantees, @lcPermissions, @lcEventData, @lcCheck_Key, @lcRoleName
		
	END
END;

GO

ENABLE TRIGGER [trgTrack_Security_Changes] ON ALL SERVER
GO


