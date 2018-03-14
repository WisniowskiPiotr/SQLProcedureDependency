
DECLARE @V_BrokerEnabled bit
SELECT @V_BrokerEnabled = is_broker_enabled
	FROM sys.databases
	WHERE name = DB_NAME()
IF (@V_BrokerEnabled != 1)
	BEGIN
		ALTER DATABASE DB_NAME 
			SET NEW_BROKER 
			WITH ROLLBACK IMMEDIATE;
	END