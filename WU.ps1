$RGName="IDCES-WestUS2-INFRA-RG" 

$jobIDs= New-Object System.Collections.Generic.List[System.Object]
get-content \\cdmbuilds\Private\Scratch\v-labhu\Test-Signing\Machines.txt | foreach-object {
$VMName = $_
$newJob = Start-ThreadJob -ScriptBlock { param($resource, $vmname) start-AzVM -ResourceGroupName $resource -Name $VMName } -ArgumentList $RGName,$VMName 
$jobIDs.Add($newJob.Id)
#Wait until all machines have finished starting before proceeding to the Update Deployment
$jobsList = $jobIDs.ToArray()
if ($jobsList)
{
    Write-Output "Waiting for machines to finish starting..."
    Wait-Job -Id $jobsList
}

foreach($id in $jobsList)
{
    $job = Get-Job -Id $id
    if ($job.Error)
    {
        Write-Output $job.Error
    }

}          


}


get-content \\cdmbuilds\Private\Scratch\v-labhu\Test-Signing\Machines.txt | foreach-object {
        $VMName = $_

        Write-Host "Tigring windows updates ogen $VMName "
       
        Copy-Item -Recurse \\cdmbuilds\Private\Scratch\v-surych\WUScripts\ \\$VMName\C$\
        Invoke-Command -ComputerName $VMName -ScriptBlock { C:\WUScripts\WU.ps1 }  
}


 
 #switch off 


#Install-Module -Name ThreadJob -RequiredVersion 2.0.0