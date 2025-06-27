[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Add-Type -Path 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\ReferenceAssemblies\v2.0\Microsoft.TeamFoundation.Client.dll'
Add-Type -Path 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\ReferenceAssemblies\v2.0\Microsoft.TeamFoundation.Build.Client.dll'

[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Build.Client")

function GetTime()	
{
    $a = Get-Date			  
    $date=$a.ToShortDateString()
    $time=$a.ToLongTimeString()
    $dateTime=$date+" "+$time
         
    return $dateTime
}

function GetFile()
{
    $a = Get-Date      
    $date=$a.ToShortDateString()
    $date=$date.Replace("/",'')
    $LogFile = $scriptPath +"\logs\$($date)SwitchOffManual.txt"
        
    return $LogFile 
}

function PowerOFF($VMName)
{
	#Connect-AzAccount  # Uncomment on first run to connect to Azure 
    $User = "cdmbld@microsoft.com"
    $PWord = ConvertTo-SecureString -String "Dcrt1cdafm2m25@20253" -AsPlainText -Force
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User,$PWord 
    Connect-AzAccount -Credential $Credential 
    Select-AzSubscription  "System Center Builds IDC"

        $RGName="IDCES-WestUS2-INFRA-RG"

        try
        {
            stop-AzVM -ResourceGroupName $RGName -Name $VMName -force -NoWait | Add-Content $(GetFile)
            #stop-AzVM -ResourceGroupName $RGName -Name $VMName -force -NoWait | Add-Content $(GetFile)
            Write-Output "$(GetTime) Powering off $VMName" | Add-Content $(GetFile)

            (Get-Content $Global:filePath) -notmatch $vm | Out-File $Global:filePath

            if((Get-Content $Global:filePath) -match "false")
            {
                Write-Output "$(GetTime) Removing running VMs list as there are no builds" | Add-Content $(GetFile)
                Remove-Item -Path $Global:filePath -Force
            }         
        }
        catch
        {  
              Write-Output "$(GetTime) PowerOFF: $_"  | Add-Content $(GetFile)         
        }

}

function UpdateRunningList($VM)
{
    if(![bool]((Get-Content $Global:filePath) -like $VM))
    {
        $VM >> $Global:filePath
    }
}

function CheckAndStopAllVMs()
{
    try
    {
        $buildserver = $Global:tfs.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])
        $buildAgentSpec = $buildServer.CreateBuildAgentSpec()

        foreach($vm in $Global:runningVMsHash.Keys)
        {
            Write-Output "$(GetTime) Querying $vm for any running builds" | Add-Content $(GetFile)
            $buildAgentSpec.ServiceHostName = $vm
            $buildAgentQueryRes = $buildServer.QueryBuildAgents($buildAgentSpec)
            $flag = $false
            foreach($ag in $buildAgentQueryRes.Agents)
            {
		        #Write-Output "$(GetTime) ag in CheckAndStopAllVMs $ag" | Add-Content $(GetFile)
                #if($ag.IsReserved)
                if($ag.ReservedForBuild -ne $null)
                {
                    Write-Output "$(GetTime) Build is running on VM $vm. Not powering off and updating in RunningVMs list" | Add-Content $(GetFile)
                    UpdateRunningList $vm
                    $flag = $true
                    break
                }
            }
            if(!$flag)
            {
                PowerOFF $vm
            }
        }
    } catch {
        Write-Output "$(GetTime) CheckAndStopAllVMs: $_" | Add-Content $(GetFile)
    }
}

function CheckAndStopVM($vm)
{
    try
    {
        Write-Output "$(GetTime) Querying VM $vm for any running builds" | Add-Content $(GetFile)
        $buildserver = $Global:tfs.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])
        $buildAgentSpec = $buildServer.CreateBuildAgentSpec()
        $buildAgentSpec.ServiceHostName = $vm
        $buildAgentQueryRes = $buildServer.QueryBuildAgents($buildAgentSpec)
        $flag = $false
        foreach($ag in $buildAgentQueryRes.Agents)
        {
            #Write-Output "$(GetTime) ag in CheckAndStopVM $ag" | Add-Content $(GetFile)

            #if($ag.IsReserved)
            if($ag.ReservedForBuild -ne $null)
            {
                Write-Output "$(GetTime) Build is running on VM $vm. Nothing to power off and updating in RunningVMs list" | Add-Content $(GetFile)
                UpdateRunningList $vm
                $flag = $true
                break
            }
        }
        if(!$flag)
        {
            PowerOFF $vm
        }
    } catch {
        Write-Output "$(GetTime) CheckAndStopVM: $_" | Add-Content $(GetFile)
    }
}

[string]$scriptPath = $PSScriptRoot
$line = "--------------------------------------------------------------------------------------------"
Write-Output "$line" | Add-Content $(GetFile)

$Global:filePath = $scriptPath + "\logs\RunningVMs.txt"

if(!(Test-Path -Path $Global:filePath))
{
    Write-Output "$(GetTime) No txt found. Hence no need to process further" | Add-Content $(GetFile)
    exit 1
}

$Global:runningVMsHash = @{}
foreach($line in Get-Content $Global:filePath)
{
    $Global:runningVMsHash.Add($line,$false)
}

$serverName = "https://cdmvstf.corp.microsoft.com/tfs/cdm"
$teamProject = "CDM_SFE"
$Global:tfs = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($serverName)
$buildserver = $Global:tfs.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])

$buildSpecification = $buildServer.CreateBuildDetailSpec($teamProject)
$buildSpecification.BuildNumber = "*"
$buildSpecification.InformationTypes = $null
$buildSpecification.Status = "InProgress"
$buildSpecification.QueryOptions = "None"
$tfsBuilds = $buildServer.QueryBuilds($buildSpecification)

$buildDefUris = ($tfsBuilds.Builds).BuildDefinitionUri

#Write-Output "$(GetTime) tfsBuilds.Builds $tfsBuilds.Builds" | Add-Content $(GetFile)

if($tfsBuilds.Builds.Count -eq 0)
{
    Write-Output "$(GetTime) No InProgress builds found. Checking for any other case" | Add-Content $(GetFile)
    CheckAndStopAllVMs
}
else
{
    $buildDefUris = ($tfsBuilds.Builds).BuildDefinitionUri

    foreach($buildDefUri in $buildDefUris)
    {
        $tempDef = $buildserver.GetBuildDefinition($buildDefUri)
        Write-Output "$(GetTime) Build definition is $($tempDef.Name)" | Add-Content $(GetFile)

        $index = $tempDef.ProcessParameters.IndexOf("CDMTFSAZBLD")
        if($index -ne -1)
        {
            $AgentName = $tempDef.ProcessParameters.SubString($index,15)
            Write-Output "$(GetTime) Agent name is $AgentName" | Add-Content $(GetFile)

            $buildAgentSpec = $buildserver.CreateBuildAgentSpec()
            $buildAgentSpec.Name = $AgentName
            $buildAgentQueryRes = $buildserver.QueryBuildAgents($buildAgentSpec)
            $VMName = $($($($buildAgentQueryRes.Agents[0]).ServiceHost).Name)
            Write-Output "$(GetTime) VMName is $VMName" | Add-Content $(GetFile)

            if($Global:runningVMsHash.ContainsKey($VMName))
            {
                Write-Output "$(GetTime) Build running in $VMName. Updating in RunningVMs list" | Add-Content $(GetFile)
                UpdateRunningList $VMName
                $Global:runningVMsHash[$VMName] = $true
            }
        }
        else
        {
            Write-Output "$(GetTime) Agent name not found" | Add-Content $(GetFile)
        }
    }

    foreach($h in $Global:runningVMsHash.GetEnumerator())
    {
        if(!($h.Value))
        {
            Write-Output "$(GetTime) Stopping $($h.Name) and deleting from running VMs list" | Add-Content $(GetFile)
            CheckAndStopVM $h.Name
        }
    }
}