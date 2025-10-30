# Convenience script to manage MSYS2 installation on Windows. Goals: cmp. 'msys2-env.psm1'
# Entry point for 'msys2-env.psm1': Reading settings 'msys2.properties' (values overridden via configuration) and apply.
# If started in debug mode, print debug messages on screen.
param(
    [parameter(Position=0,Mandatory=$False)][Bool] $show_debug_information
)

#Write-Host "NEW"

Function _log_if_debug([string] $debug_message) {
    if ($show_debug_information -eq $true) {
        Write-Host $debug_message
    }
}

$Current_Script_loc = $PSScriptRoot
# Assume sensible defaults for MSYS2 location, MSYS2 user, download location, source location a.s.o.
$settings = @{
    'downloads.dir' = "$Current_Script_loc\downloads" # default location for downloads
    'sources.dir' = "$Current_Script_loc\sources" # # Note: There's not a 'git-only' folder; downloads will be unpacked next to git checkouts, even not a git clone..
    'msys2.install.dir' = "$Current_Script_loc\msys64" # default, can be overridden in msys2.properties file
    'msys2.user.home' =  'vagrant' # a MSYS" 'registered' user that has local admissive rights to installe packages, execute build tools (CMake, for example)
    'msys2.download.url' = "https://repo.msys2.org/distrib/x86_64/msys2-x86_64-20250830.exe" 
    'msys2.packages.master.url' = "https://github.com/msys2/MSYS2-packages.git"
    'msys2.mingw64.master.url' = "https://github.com/msys2/MINGW-packages.git"
    'msys2.mingw64.hdl.url' = ""
};

Function print_settings() {
    $settings.Keys | ForEach-Object{
        $message = 'Key: {0}, Value: {1}' -f $_, $settings[$_] | Write-Host
    }
}

# Could introduce configuration here by reading a 'settings.XYZ' file..
$settingsFile = Convert-Path "$Current_Script_loc\msys2.properties"
Import-Csv $settingsFile -Header Key,Value -Delimiter "=" | ForEach-Object { 
    $key = $_.Key, $val = $_.Value;
    if($key -eq 'downloads.dir') {
        $overridden = $True
        $settings.Add($key, $val);
    }
    elseif($_.Key -eq 'sources.dir') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    elseif($_.Key -eq 'msys2.install.dir') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    elseif($_.Key -eq 'msys2.user.home') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    elseif($_.Key -eq 'msys2.download.url') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    elseif($_.Key -eq 'msys2.packages.master.url') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    elseif($_.Key -eq 'msys2.mingw64.master.url') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    elseif($_.Key -eq 'msys2.mingw64.hdl.url') {
        $overridden = $True
        $settings[$_.Key] = $_.Value;
    }
    # Show overrides to user for clarification if settings in msys2.properties
    if($overridden -eq $True){
        _log_if_debug "Overriding default settings! Key '$key' defined as '$($script:settings[$key])'";
    }
}

if($show_debug_information) {
    print_settings
}

# Set the path to the MSYS2 executables (GNU programs)
Write-Host "Loading MSYS2 module.."
Import-Module "$Current_Script_loc\msys2-env.psm1" -ArgumentList @($script:settings.'msys2.install.dir',$script:settings.'msys2.user.home')
$module_load_facts = Get_Module_Load_Facts;
if($module_load_facts.'msys2_install_dir' -ne $null) {
    Write-Host "Local Msys2 installation was properly initialized. Type 'msys_info' to get information and commands."
    $msys_user_home_path = $module_load_facts.'user_home_path' #| Write-Host
    if($msys_user_home_path -ne $null) {
        Set-Location $msys_user_home_path
    }
    else {
        Set-Location $Current_Script_loc
    }
}
else {
    Write-Host "There have been some problems loading the local MSYS2 installation: "
    foreach($msg in $module_load_facts.debug_messages) {
        Write-Host "`t$msg";
    }
    Write-Host "Type 'msys_help' to get a list of repair options."
    Set-Location $Current_Script_loc
}
