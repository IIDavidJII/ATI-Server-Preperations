#############################################################
#By: David Young                                            #
#                                                           #
#Date: 11-13-2019 Created script to create file and capture #
#                 1. nTime tasks information                #
#                 2. Sql database recovery models           #
#                 3. SQL Agent Jobs status                  #
#############################################################

###RUN FROM nTIME HOST and ensure you have access to the SQL Database with user running

#configure output directory and Database here
$dir = 'C:\Temp\nTimeTasks.txt'
$DBServer = 'WYKOFF-01-2K12\OASIS'
$nTimeHost = 'L60907'

#nTime task names
$nTimeTaskNames = 'AccountBalanceExpirationJob','GroupPromoIssuanceJob','TransactionalUnitsExpirationJob','TransactionArchivalJob'

#define Table
$dt = New-Object System.Data.Datatable
[void]$dt.Columns.Add("Task")
[void]$dt.Columns.Add("LastRun")
[void]$dt.Columns.Add("LastResult")
[void]$dt.Columns.Add("NextRun")


#add row for each nTimeTask
Foreach ($task in $nTimeTaskNames)
  {
    $Command = invoke-command -ComputerName $nTimeHost {Get-ScheduledTaskInfo -TaskName $using:task -TaskPath (Get-ScheduledTask -TaskName $using:task).TaskPath} 
    [void]$dt.Rows.Add($Command.TaskName,$Command.LastRunTime,$Command.LastTaskResult,$Command.NextRunTime)
  }

Select-Object -InputObject $dt | Out-File -FilePath $dir

#SQL Recovery table
$cmdSQLRestore = Invoke-Sqlcmd  -query "WITH LastRestores AS
                                        (
                                        SELECT
                                            DatabaseName = [d].[name] ,
                                            [d].[compatibility_level] ,
                                            [d].recovery_model_desc,
                                            RowNum = ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY r.[restore_date] DESC)
                                        FROM master.sys.databases d
                                        LEFT OUTER JOIN msdb.dbo.[restorehistory] r ON r.[destination_database_name] = d.Name
                                        )
                                        SELECT DatabaseName, recovery_model_desc, compatibility_level
                                        FROM [LastRestores]
                                        WHERE [RowNum] = 1" -Verbose -ServerInstance $DBServer| Format-List | Out-String

Add-Content -Value $cmdSQLRestore -Path $dir


#SQL Jobs
$cmdSQLJobs = Invoke-Sqlcmd  -Query "SELECT 
 job_id
,name
,[ENABLED] = IIF(NULLIF(enabled,0) IS NULL,'FALSE','TRUE')
,[Date Created]= FORMAT(date_created, 'dd/MM/yyyy')
,[Date Modified] = FORMAT(date_modified, 'dd/MM/yyyy hh:mm:ss') 
FROM msdb.dbo.sysjobs
ORDER BY date_created" -Verbose -ServerInstance $DBServer| Format-List | Out-String
$cmdSQLJobs
Add-Content -Value $cmdSQLJobs -Path $dir

