 [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12


# Working for more than one job from same branch 
    $MachineGroup
    $MinNOfMachines 
    $Component
    $global:rflag
    $global:RunningLegsFlag
    $global:VMSwitchONDateTime=0
    $global:VMONDuration=0
     $global:IsVMSwitchedOff=0

     $timeelapse=0
function GetTime()
{
    $a = Get-Date			  
    $date=$a.ToShortDateString()
    $date=$date.Replace("/",'')
    $time=$a.ToLongTimeString()
    $dateTime=$date+" "+$time
    return  $dateTime
}
 function LogTime()	
 {
	 $a = Get-Date			  
	 $date=Get-Date -Format "MMM dd yyyy" 
		 
     $time=$a.ToLongTimeString()
     $dateTime=$date+" "+$time
      return  $dateTime
}
    
	
# This function will return 1 if given Job status is Running otherwise returns 0
function IsRunning{
param($l_Job_id)
try {
     
        write-output " IsRunning"
        $userName = 'cdmbtg'        
        $ServerName='CDMBT01'
        $DatabaseName='BuildTracker'
        $password = 'fU4n!POtat0'
        $connectionString_ = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
        $sqlConnection_ = New-Object System.Data.SqlClient.SqlConnection $ConnectionString_
        $sqlConnection_.Open()        
        $Command_CN = New-Object System.Data.SQLClient.SQLCommand
        $Command_CN.Connection = $sqlConnection_          
        write-output "__________________________________"
       # $Command_CN.CommandText ="
       # select Enls.EnlistmentSpecification_Id ,Job_id,J.name, Mappings from EnlistmentSpecificationVSTSInfo Enls , Job J
       # where Enls.EnlistmentSpecification_Id=J.EnlistmentSpecification_Id and j.Job_Id in ($($l_job_id))"  
    
	  $Command_CN.CommandText =" select Count(*) as isRunning from JobQueue where JobQueue_Id in  ( $($l_job_id) ) and 
             status in (select JobQueueStatus_Id from JobQueueStatus where IsRunning=1) "

             # write a Queary status is running and not but not sequcend 

	  
	  
    
         
       $Reader = $Command_CN.ExecuteReader()    
       $Datatable = New-Object System.Data.DataTable
       $Datatable.Load($Reader)
       $JobDetails = $Datatable
       $JobDetails | Format-Table -AutoSize

       $JobDetails.Rows.Count

       write-output "$(GetTime) : JobQueue Count(*) = $($JobDetails.isRunning)"  | Add-Content $(GetFile)


       
       $MinNOfMachines=0
       $rFlag=0
        
       if ($JobDetails.isRunning -eq 0 )
       {
         write-output " ****************Not Runnig  ***************"
         write-output "$(GetTime) :Job $l_job_id has been completed"  | Add-Content $(GetFile)
          
          $rFlag=1
          $global:rflag=1
        }
        else
        {
        write-output "$(GetTime) :Job $l_job_id is running"  | Add-Content $(GetFile)
             $rFlag=0
             $global:rflag=0

        }    
        
       # write-output "$(GetTime) : is running return value =  $rFlag "  | Add-Content $(GetFile)
                        
        return $rFlag
       
    } catch {
        $false
        echo "Exception IsRunning "
        
        write-output "$(GetTime) :Exception IsRunning"  | Add-Content $(GetFile)
    } finally {
        ## Close the connection when we're done

        

        $sqlConnection_.Close()
       
    }
  
 } 
     
function GetMetricFile()
{
  
        
        return  "E:\SwitchOFF_VM.txt" 
}


 

# This function will return Log file location 
function GetFile()
{
    $a = Get-Date
          
    $date=$a.ToShortDateString()
    $date=$date.Replace("/",'')
    $date

   return "E:\AzureVMAutomation\log\$($date)SwithOFF.txt" #Change this     
   
}

 write-output "$(GetTime) ------------------------------------------------------------------"  | Add-Content $(GetFile)
 
 # This function is start function for the script 
    function CheckBuildStatus {
    param( )
    # DB details:  Data Source=CDMBT01;Initial Catalog=BuildTracker;User ID=cdmbtg;Password=fU4n!POtat0";
    try {
        $userName = 'cdmbtg'        
        $ServerName='CDMBT01'
        $DatabaseName='BuildTracker'
        $password = 'fU4n!POtat0'
        $connectionString_ = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
        $sqlConnection_ = New-Object System.Data.SqlClient.SqlConnection $ConnectionString_
        $sqlConnection_.Open()        
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $sqlConnection_          
        write-output "__________________________________"
        $Command.CommandText ="select distinct job_id from job_details where jobName  like 'null' "
         $Reader = $Command.ExecuteReader()    
       $Datatable = New-Object System.Data.DataTable
       $Datatable.Load($Reader)
       $JobDetails = $Datatable
       $JobDetails | Format-Table -AutoSize
      
      write-output "$(GetTime) :Fetching Job_details "  | Add-Content $(GetFile)

      
     
       $MinNOfMachines=0
       $JobDetails.count
       if ($Datatable.Rows.Count -eq 0 ){
         write-output " ****************No Completed Jobs ***************"
         write-output "__________________________________"
         write-output "$(GetTime) :No Jobs found "  | Add-Content $(GetFile)
        }
        
       foreach ($row in $JobDetails)
       {
              write-output  "JOB ID $row.Job_Id"
           
                IsRunning $row.Job_Id 
             if(  $global:rflag -eq 1 ) {
                    
                    # write-output "IsRunning Flag = $global:rflag  "  | Add-Content $(GetFile)
                     get_allotted_Machines $row.Job_Id 


              }
              else{
                    write-output "Job" $row.Job_Id  "is running (flag =$global:rflag)" 
                   # write-output "Job" $row.Job_Id  "is running " | Add-Content $(GetFile)
             }
     
             			   
       }               
        
         
    } catch {
        $false
        echo "Exception in get_ComponentName "
         write-output "$(GetTime) :Exception CheckBuildStatus "  | Add-Content $(GetFile)
    } finally {
        ## Close the connection when we're done
        $sqlConnection_.Close()
       
    }
}


   # This function will fetches alloccated machine names for given JobQueue ID
    function get_allotted_Machines {
    param( $l_Job_id )
    # DB details:  Data Source=CDMBT01;Initial Catalog=BuildTracker;User ID=cdmbtg;Password=fU4n!POtat0";
    try {
     
        $global:VMONDuration=0
        $userName = 'cdmbtg'        
        $ServerName='CDMBT01'
        $DatabaseName='BuildTracker'
        $password = 'fU4n!POtat0'
        $connectionString_ = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
        $sqlConnection_ = New-Object System.Data.SqlClient.SqlConnection $ConnectionString_
        $sqlConnection_.Open()        
        $Command_CN = New-Object System.Data.SQLClient.SQLCommand
        $Command_CN.Connection = $sqlConnection_          
        write-output "__________________________________"
       # $Command_CN.CommandText ="
       # select Enls.EnlistmentSpecification_Id ,Job_id,J.name, Mappings from EnlistmentSpecificationVSTSInfo Enls , Job J
       # where Enls.EnlistmentSpecification_Id=J.EnlistmentSpecification_Id and j.Job_Id in ($($l_job_id))"  
    
     write-output "  Trace ----------------------- $l_Job_id "
	    $Command_CN.CommandText ="select AM.machineName
                               ,convert(varchar, AM.DateAndTime, 109) [DateAndTime]
                               ,DATEDIFF(MI, AM.DateAndTime 
                               ,SYSDATETIME()) [ONDuration]
                               ,JD.ProuctName
                               ,JD.BranchName from AllottedMachines AM, Job_details JD 
                                 where AM.Job_ID=JD.Job_ID
                                 and  AM.job_id IN ( $($l_job_id))
                                 and  AM.machine_id not in (select machine_id from ViewLegQueue 
                                 where status not in(select LegQueueStatus_Id from LegQueueStatus
                                 where IsCompleted=1))"
	         
        
       $Reader = $Command_CN.ExecuteReader()    
       $Datatable = New-Object System.Data.DataTable
       $Datatable.Load($Reader)
       $JobDetails = $Datatable
       $JobDetails | Format-Table -AutoSize
       write-output "__________________Fetching AllocttedMachines________________"
       write-output "  Trace ----------------------- JobDetail "
       $JobDetails
       
       write-output "$(GetTime) :Fetching AllocttedMachines which are not assigned to any of the build tracker jobs and Start-Sleep -s 5 "  | Add-Content $(GetFile)  
         
       Start-Sleep -s 5
       
       $NoRunningLegs =0
       $JobDetails.Rows.Count
       if ($Datatable.Rows.Count -eq 0 ){
            write-output " ****************No wating legs ***************"
            write-output "__________________________________"
            write-output "$(GetTime) :($($Command_CN.CommandText)) "  | Add-Content $(GetFile)
            write-output "$(GetTime) :No AllocttedMachines found  in running legs "  | Add-Content $(GetFile)
            $Command_Temp2 = New-Object System.Data.SQLClient.SQLCommand
            $Command_Temp2.Connection = $sqlConnection_  
           
              $Command_Temp2.CommandText ="  
                    select machineName from AllottedMachines  where  job_id IN( $($l_job_id))
                     "
              $Command_Temp2.CommandText
                    
              $Command_Temp2.ExecuteScalar(); 
              #write-output "$(GetTime) :Delete from Job_details  "  | Add-Content $(GetFile)  
              
               $Reader2 = $Command_Temp2.ExecuteReader()    
               $Datatable2 = New-Object System.Data.DataTable
               $Datatable2.Load($Reader2)
               $JobDetails = $Datatable2
               $JobDetails | Format-Table -AutoSize
               write-output "__________________Fetching AllocttedMachines: not being used by  runnings legs  ________________"
              # write-output "$(GetTime) :Fetching AllocttedMachines: not being used by  runnings legs "  | Add-Content $(GetFile)    	

               $NoRunningLegs =1

        }
       foreach ($row in $JobDetails)
       {
             CheckRunningLegs -l_MachineName $($row.machineName)  
             if( $global:RunningLegsFlag -eq 1)
             {
                 $global:VMSwitchONDateTime=$row.DateAndTime
                  
                  $global:VMONDuration=$row.ONDuration

                 PowerOFF -VMName $row.machineName  -ProuctName $row.ProuctName -BranchName $row.BranchName
                 If($global:IsVMSwitchedOff -eq 1){
                     DeleteAllottedMachine -l_Job_id $l_Job_id -l_MachineName $($row.machineName) 
                 }                 
             }  
             else
             {
                $NoRunningLegs=0 #Keep JobDetails table entry and check in the next iteration
                write-output "$(GetTime) : Keeping JobDetails, Since Machine is being alloccated to other Leg"  | Add-Content $(GetFile)    	

             }  
            		   
       }    
       Get-Job | Sort-Object Id -Descending | Select -First 1 | Wait-Job   
       
       if( $NoRunningLegs -eq 1)
       {
              $Command_Temp_3 = New-Object System.Data.SQLClient.SQLCommand
              $Command_Temp_3.Connection = $sqlConnection_
                # Product_Id , p.name as ProuctName,b.Branch_Id, b.Name as BranchName

              $Command_Temp_3.CommandText ="  
                    delete  from Job_details where job_id=$l_Job_id
                     "
              $Command_Temp_3.CommandText
                    
              $Command_Temp_3.ExecuteScalar(); 
              write-output "$(GetTime) :$($Command_Temp_3.CommandText) "  | Add-Content $(GetFile)
              write-output "$(GetTime) :Delete from Job_details as No machine is used by any Runnings legs  : freeing machines "
              #write-output "$(GetTime) :   Flag NoRunningLegs $NoRunningLegs"  | Add-Content $(GetFile) | Add-Content $(GetFile)  
              
               
               # Product_Id , p.name as ProuctName,b.Branch_Id, b.Name as BranchName

              $NoRunningLegs =0       
       }      
        
         
    } catch {
        $false
        echo "Exception in get_allotted_Machines "
         write-output "$(GetTime) :Exception get_allotted_Machines Job $l_Job_id "  | Add-Content $(GetFile) 

    } finally {
        ## Close the connection when we're done
        $sqlConnection_.Close()
       
    }
}

#
# This function will check given machine is alloccated to any other running JOBS
# Script is allocating min no of machines for every job submitted,
# Build tracker has its own algorithm to assign available machines for the pool 
# By this function we are make sure that allotted machine not being association to any other running Jobs
# 

function CheckRunningLegs {
  param(
      [string]$l_MachineName
        
    )
    try{
    
     $global:RunningLegsFlag=0
        $userName = 'cdmbtg'        
        $ServerName='CDMBT01'
        $DatabaseName='BuildTracker'
        $password = 'fU4n!POtat0'
        $connectionString_ = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
        $sqlConnection_ = New-Object System.Data.SqlClient.SqlConnection $ConnectionString_
        $sqlConnection_.Open()        
        $Command_CN = New-Object System.Data.SQLClient.SQLCommand
        $Command_CN.Connection = $sqlConnection_          
        write-output "__________________________________"
       
      
       # $Command_CN.CommandText ="
       # select Enls.EnlistmentSpecification_Id ,Job_id,J.name, Mappings from EnlistmentSpecificationVSTSInfo Enls , Job J
       # where Enls.EnlistmentSpecification_Id=J.EnlistmentSpecification_Id and j.Job_Id in ($($l_job_id))"  
    
        write-output "  Trace ----------------------- $l_Job_id "
	   # $Command_CN.CommandText ="
        # select machineName from AllottedMachines  where machine_id not in (select machine_id from ViewLegQueue  where status not in(select LegQueueStatus_Id from LegQueueStatus where IsCompleted=1))
        # and machineName like '$l_MachineName'

	    #"
        $Command_CN.CommandText ="
        select  Distinct M.Name from LegQueue LQ, JobQueue JQ, Machine M where JQ.JobQueue_Id=LQ.JobQueue_Id and  LQ.Machine_Id=M.Machine_Id 
		and  JQ.status in (select JobQueueStatus_Id from JobQueueStatus where IsRunning=1 ) 
		and  M.name  like '$l_MachineName' "
    
         
       $Reader = $Command_CN.ExecuteReader()    
       $Datatable = New-Object System.Data.DataTable
       $Datatable.Load($Reader)
       $JobDetails = $Datatable
       $JobDetails | Format-Table -AutoSize
       write-output "__________________Fetching AllocttedMachines________________"
       write-output "  Trace ----------------------- JobDetail "
       $JobDetails
       $JobDetails.count
       if ($Datatable.Rows.Count -eq 0 ){
            write-output " ****************$l_MachineName is not there in Runnings Jobs at the movement ***************"
            write-output "__________________________________"
            write-output "$(GetTime) :$l_MachineName is not there in Runnings Jobs at the movement"  | Add-Content $(GetFile)
            $global:RunningLegsFlag=1
       }
       else
       {
             $global:RunningLegsFlag=0
             write-output "$(GetTime) :$l_MachineName has been alloctted to other job and found in Runnings Jobs"  | Add-Content $(GetFile)

       }
       

       } catch {
        $false
        echo "Exception in get_allotted_Machines "
         write-output "$(GetTime) :($($Command_CN.CommandText)) "  | Add-Content $(GetFile) 

       
         write-output "$(GetTime) :Exception CheckRunningLegs function "  | Add-Content $(GetFile) 

    } finally {
        ## Close the connection when we're done
        $sqlConnection_.Close()
       
    }
       
       
}

# This function will deletes a machine from allotted machines table


function DeleteAllottedMachine {
    param(
     $l_Job_id,$l_MachineName
        
    )
    try{
    
            $userName = 'cdmbtg'        
        $ServerName='CDMBT01'
        $DatabaseName='BuildTracker'
        $password = 'fU4n!POtat0'
        $connectionString_ = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
        $sqlConnection_ = New-Object System.Data.SqlClient.SqlConnection $ConnectionString_
        $sqlConnection_.Open()        
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $sqlConnection_          
        write-output "__________________________________"
        $Command.CommandText =" delete  from AllottedMachines  where  machineName like '$($row.machineName)' and 
                                                    job_id=$l_Job_id"
         $Reader = $Command.ExecuteReader()    
       $Datatable = New-Object System.Data.DataTable
       $Datatable.Load($Reader)
       $JobDetails = $Datatable
       $JobDetails | Format-Table -AutoSize
       $Command.CommandText 
        
              write-output "$(GetTime) :$($Command.CommandText) "  | Add-Content $(GetFile)  
              #write-output "$(GetTime) :Delete from AllocttedMachines ($($row.machineName)) "  | Add-Content $(GetFile) 
                            
              
        } catch {
            $false
            echo "Exception in DeleteJobDetails "
         write-output "$(GetTime) :Exception in DeleteAllocttedMachines function  "  | Add-Content $(GetFile) 

    } finally {
        ## Close the connection when we're done
        $sqlConnection_.Close()
       
    } 
   }

# This function will delete job queue entry from job_details table

function DeleteJobDetails {
    param(
     [int]$l_Job_id
        
    )
    try{
    
            $userName = 'cdmbtg'        
        $ServerName='CDMBT01'
        $DatabaseName='BuildTracker'
        $password= 'fU4n!POtat0'
        $connectionString_ = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
        $sqlConnection_ = New-Object System.Data.SqlClient.SqlConnection $ConnectionString_
        $sqlConnection_.Open()        
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $sqlConnection_          
        write-output "__________________________________"
        $Command.CommandText ="  delete  from Job_details where job_id in ( $($l_Job_id))"
         $Reader = $Command.ExecuteReader()    
       $Datatable = New-Object System.Data.DataTable
       $Datatable.Load($Reader)
       $JobDetails = $Datatable
       $JobDetails | Format-Table -AutoSize
          
              write-output "$(GetTime) :$($Command.CommandText)  "  | Add-Content $(GetFile) 
              
              
              
               } catch {
        $false
        echo "Exception in DeleteJobDetails "
         write-output "$(GetTime) :Exception in DeleteJobDetails function "  | Add-Content $(GetFile) 

    } finally {
        ## Close the connection when we're done
        $sqlConnection_.Close()
       
    } 
   }
		

# This function will switch off given machine
function PowerOFF {
    param(
     $VMName, $ProuctName, $BranchName
        
    )
		#Connect-AzAccount  # Uncommnet on first run to connect to Azure 

		#Add-AzureAccount
		#Get-AzSubscription
		$Subscr = "System Center Builds IDC"
		#select-AzSubscription -SubscriptionName $Subscr 
		#Switch-AzureMode AzureResourceManager
		#$RGName="IDCES-WESTUS2-BUILD-RG"
        $RGName="IDCES-WestUS2-INFRA-RG"
		#$VMName="cl1dc"
		Get-AzVM -ResourceGroupName $RGName  #| select Name
        $global:IsVMSwitchedOff=0
        try
        {
            $VMStatus = (Get-AzVM -ResourceGroupName $RGName -Name $VMName -Status).Statuses[1].DisplayStatus
            write-output " $(GetTime)$VMStatus  " 
            if(($VMStatus.Contains( "deallocated")))
            {                
                #write-output " $(GetTime)$VMName is Switched off "| Add-Content $(GetFile)  
                $global:IsVMSwitchedOff=1
                write-output "$VMName Start Time: $global:VMSwitchONDateTime Stop Time: $(LogTime) Duration(Mins): $global:VMONDuration $ProuctName $BranchName " #| Add-Content $(GetMetricFile)

            }
            elseif(($VMStatus.Contains( "deallocating")))
            {
                 write-output " $(GetTime)$VMName is  deallocating" #| Add-Content $(GetFile) 
            }
            else
            {
               #  write-output "$(GetTime) :Power off command execution started for $VMName "  | Add-Content $(GetFile) 
                # write-output " $(GetTime)$VMName is  running hence powering off " 
                 stop-AzVM -ResourceGroupName $RGName -Name $VMName  -force -NoWait
                 write-output "$(GetTime) :Power off command executed for $VMName " | Add-Content $(GetMetricFile)
      
            }
        
        }
        catch
        {  
		$message = $_.Exception.message
           if ($_.Exception.Message.Contains("Failed"))
            { 
              write-output "Unable to power ON!! " 
              write-output "$(GetTime) :Power off Exception  "  | Add-Content $(GetFile)
              write-output "$VMName is started: $global:VMSwitchONDateTime Power off Exception" | Add-Content $(GetMetricFile)


            }             
        }

		echo $VMName "powerd OFF!!"

}




#getMinNumberOfMachines("SCOM")
#get_Jobs
#get_affinityt_branch
#CheckBuildStatus
Get-AzContext -ListAvailable -OutVariable Out -Verbose
$Out.Count
         write-output "$(GetTime) :Power off command executed for CDMBLDAZ062 " | Add-Content $(GetMetricFile)
PowerOFF -VMName CDMBLDAZ062 -ProuctName SCVMM_Test -BranchName SC2019UR_Next_Test
 
 
          write-output "$(GetTime) :done for CDMBLDAZ062 " | Add-Content $(GetMetricFile)

          write-output "$(GetTime) :$Out.Count " | Add-Content $(GetMetricFile)


    

    