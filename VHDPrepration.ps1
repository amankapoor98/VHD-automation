$product = $args[0]
$commandFilePath = $args[1]
$buildPath = $args[2]
$username = $args[3]
$password = $args[4]

if ($product -eq "VMM")
{
$appendLine = $commandFilePath+ " " +$buildPath+ " " +$username + " " +$password

if ($username -eq "" -or $password -eq ""){
Write-Host "Username and Password cannot be empty"
exit
}
}else {
$appendLine = $commandFilePath+ " " +$buildPath
}


Write-Host " Product is " $product
Write-Host " Build path is " $buildPath
Write-Host " Answer file append line is " $appendLine

#Copy Files to Local folder
$localFolder = New-Item "$env:SystemDrive\$($product)-$( get-date -f yyyy-MM-dd-hh-mm-ss)" -ItemType Directory -Force

Copy-Item \\cdmbuilds\tools\Apps\VHDCreator\AutomationScripts\SM\unattend.xml $localFolder

Copy-Item \\cdmbuilds\tools\Apps\Rel\SC2019RTM_EVAL_VHD\17763.253.amd64fre.rs5_release_svc_refresh.190108-0006_server_serverdatacentereval_en-us.vhd $localFolder

$VHDName = $product + "_RTMVHD"+ "$( get-date -f yyyy-MM-dd-hh-mm-ss)" +".vhd"

Rename-Item $localFolder\17763.253.amd64fre.rs5_release_svc_refresh.190108-0006_server_serverdatacentereval_en-us.vhd $VHDName
 
$VHDFilePath = "$($localFolder)\" + "$($VHDName)"

#Answer file modification 
Write-host " VHD Preparation started"

$filePathToUnattendXML = "$localFolder\unattend.xml"

$xml = [xml] (Get-Content $filePathToUnattendXML)

$xml.unattend.settings.component[0].FirstLogonCommands.SynchronousCommand[1].CommandLine = "$appendLine"

Write-Host " Build path added to unattend.xml"

$xml.save("$filePathToUnattendXML")

#VHD Preparation
 
Mount-VHD -Path $VHDFilePath.ToString()

$DriveLetter = (GET-DISKIMAGE $VHDFilePath | GET-DISK | GET-PARTITION).DriveLetter

$destinationFolder = $DriveLetter + ":\Windows\Panther\"

Copy-Item $localFolder\unattend.xml -destination $destinationFolder
 
Dismount-VHD $VHDFilePath

Write-host " Preparation Complete"

#VM Creation in Hyper-V
$time = (get-date).timeofday
$vmName = "VHD " + $time
$ram = 8GB
$bootDevice = "VHD"
$gen = 1
$vmSwitch = (Get-VMSwitch).Name

New-VM -Name $vmName -MemoryStartupBytes $ram -BootDevice $bootDevice -VHDPath $VHDFilePath -Generation $gen -Switch $vmSwitch

Start-VM -Name $vmName

Write-Host " VM started"

#Exporting VHD

while(1){

$vm_status = (Get-VM $vmName).state 

if ($vm_status -eq "Off"){

write-host " Exporting VHD"

Copy-Item $VHDFilePath \\cdmbuilds\tools\Apps\VHDCreator\VHD

break
}

else { Write-Host " Product is being installed... Please wait"}

Start-Sleep -Seconds 180


}

#Cleanup

Remove-Item $localFolder -Recurse

Remove-VM -Name $vmName -Force
