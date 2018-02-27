USE [test_sgdb]
GO
/****** Object:  StoredProcedure [NotificationBroker].[A_JobPart_Select]    Script Date: 2017-11-28 13:48:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [NotificationBroker].[A_JobParts_Select] 
       @order_id int = -1,
       @job_id int = -1
AS
BEGIN

    SELECT 
	   JobParts.job_part_id as job_part_id
	   , order_id as order_id
	   , receive_date as receive_date
	   , return_date as return_date
	   , product as product
	   , JobParts.id as id
	   , job_id as job_id
	   , deleted as deleted
	   , falcon_phase as falcon_phase
	   , falcon_status as falcon_status
	   , holiday_job as holiday_job
	   , email_date as email_date
	   , request_description as request_description
	   , audit_content_type_id as audit_content_type_id
	   , audit_date as audit_date
	   , is_request_ext_possible as is_request_ext_possible
	   , jp_platform_client_id as jp_platform_client_id
	   , file_id as file_id
	   , file_name as file_name
	   , file_ext as file_ext
	FROM dbo.JobParts AS JobParts
	INNER JOIN dbo.TempFiles AS TempFiles ON TempFiles.job_part_id = JobParts.job_part_id
	WHERE JobParts.deleted = 0
		AND ((@job_id = -1) OR (@job_id <> -1 AND job_id = @job_id))
		AND ((@order_id = -1) OR (@order_id <> -1 AND order_id = @order_id AND job_id IS NULL))
	FOR XML PATH('row')

END

