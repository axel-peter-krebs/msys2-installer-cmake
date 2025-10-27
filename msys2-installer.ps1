# 
param(
    [parameter(Position=0,Mandatory=$False)][Bool] $show_debug_information
)

Function _log_if_debug([string] $debug_message) {
    if ($show_debug_information -eq $true) {
        Write-Host $debug_message
    }
}

$settings = @{} # user overrides

$Current_Script_loc = $PSScriptRoot
# Assume sensible defaults for MSYS2 location, MSYS2 user, download location, source location
$Download_loc = "$Current_Script_loc\downloads"
$Sources_loc = "$Current_Script_loc\sources" # Note: There's no 'git' folder; download will be unpacked next to git checkouts!
$Msys2_loc = "$Current_Script_loc\msys64" # default, can be overridden
$Msys2_user = 'vagrant'
$Msys_download_url = ""
$Msys_packages_url = ""
$Msys_mingw64_master_url = ""
$Msys_mingw64_hdl_url = ""

# Could introduce configuration here by reading a 'settings.XYZ' file..
$settingsFile = Convert-Path "$Current_Script_loc\msys2.properties"
Import-Csv $settingsFile -Header Key,Value -Delimiter "=" | ForEach-Object { 
    $script:settings[$_.Key] = $_.Value 
}

foreach ($key in $script:settings.Keys) { # override defaults
    #Write-Host "`tKey: $key, Value: $($settings[$key])" 
    $overridden = $False
    if($key -eq 'msys2.download.url') {
        $overridden = $True
        $Msys_download_url = $settings[$key];
    }
    elseif($key -eq 'msys2.packages.master.url') {
        $overridden = $True
        $Msys_packages_url = $settings[$key];
    }
    elseif($key -eq 'msys2.mingw64.master.url') {
        $overridden = $True
        $Msys_mingw64_master_url = $settings[$key];
    }
    elseif($key -eq 'msys2.mingw64.hdl.url') {
        $overridden = $True
        $Msys_mingw64_hdl_url = $settings[$key];
    }
    if($key -eq 'msys2.user.home') {
        $overridden = $True
        $Msys2_user = $settings[$key];
    }
    if($key -eq 'msys2.install.dir') {
        $overridden = $True
        $Msys2_loc = $settings[$key];
    }
    if($overridden -eq $True){
        _log_if_debug "Overriding default settings! Key '$key' defined as '$($script:settings[$key])'";
    }
}

# Set the path to the MSYS2 executables (GNU programs)
Write-Host "Loading MSYS2 module.."
Import-Module "$Current_Script_loc\msys2-env.psm1" -ArgumentList @($script:Msys2_loc,$script:Msys2_user)
Write-Host "Done loading MSYS2 module. Type 'msys_info' to display current settings."
$module_messages = Get_Module_Load_Messages;
if($module_messages.Count -ne 0) {
    Write-Host "There have been some problems loading the local MSYS2 installation. Debug-messages:"
    foreach($msg in $module_messages) {
        Write-Host "$msg";
    }
    Set-Location $Current_Script_loc
}
else {
    $msys_user_home_path = msys_User_Home #| Write-Host
    Set-Location $msys_user_home_path
}
