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
    $LogFile = $scriptPath +"\logs\$($date)SwitchONManual.txt"
        
    return $LogFile 
}

function PowerON($VMName)
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

        $VMStatus = (Get-AzVM -ResourceGroupName $RGName -Name $VMName -Status).Statuses[1].DisplayStatus
        if(!($VMStatus -match "running"))
        {
            start-AzVM -ResourceGroupName $RGName -Name $VMName  -NoWait | Add-Content $(GetFile)

            Write-Output "$(GetTime) Powering on $VMName" | Add-Content $(GetFile)
        }
        else
        {
            Write-Output "$(GetTime) Already powered on $VMName" | Add-Content $(GetFile)
        }
    }
    catch
    {
        Write-Output "$(GetTime) Unable to power ON!! $_" | Add-Content $(GetFile)
    }
  
}

[string]$scriptPath = $PSScriptRoot
$line = "--------------------------------------------------------------------------------------------"
Write-Output "$line" | Add-Content $(GetFile)

$filePath = $scriptPath + "\logs\RunningVMs.txt"

$runningVMs = [System.Collections.ArrayList]@()
if(Test-Path -Path $filePath)
{
    foreach($line in Get-Content $filePath)
    {
        $i = $runningVMs.Add($line)
    }
}

$serverName = "https://cdmvstf.corp.microsoft.com/tfs/cdm"
$teamProject = "CDM_SFE"
$tfs = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($serverName)
$buildserver = $tfs.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])

$buildSpecification = $buildServer.CreateBuildDetailSpec($teamProject)
$buildSpecification.BuildNumber = "*"
$buildSpecification.InformationTypes = $null
$buildSpecification.Status = "InProgress"
$buildSpecification.QueryOptions = "None"
$tfsBuilds = $buildServer.QueryBuilds($buildSpecification)

$buildDefUris = ($tfsBuilds.Builds).BuildDefinitionUri

foreach($buildDefUri in $buildDefUris)
{
    $tempDef = $buildserver.GetBuildDefinition($buildDefUri)
    Write-Output "$(GetTime) Build definition is $($tempDef.Name)" | Add-Content $(GetFile)

    $index = $tempDef.ProcessParameters.IndexOf("CDMTFSAZBLD")
    if($index -ne -1)
    {
        Write-Output "$(GetTime) Agent name found at $index" | Add-Content $(GetFile)
        $AgentName = $tempDef.ProcessParameters.SubString($index,15)
        Write-Output "$(GetTime) Agent name is $AgentName" | Add-Content $(GetFile)

        $buildAgentSpec = $buildserver.CreateBuildAgentSpec()
        $buildAgentSpec.Name = $AgentName
        $buildAgentQueryRes = $buildserver.QueryBuildAgents($buildAgentSpec)
        $VMName = $($($($buildAgentQueryRes.Agents[0]).ServiceHost).Name)
        Write-Output "$(GetTime) VMName is $VMName" | Add-Content $(GetFile)

        if(!($runningVMs.Contains($VMName)))
        {
            $i = $runningVMs.Add($VMName)
            $VMName >> $filePath
        }
        PowerON $VMName
    }
    else
    {
        Write-Output "$(GetTime) Agent name not found" | Add-Content $(GetFile)
    }
}