# Convenience script to manage MSYS2 installation on Windows. Goals: cmp. 'msys2-env.psm1' and 'msys2-packer.psm1'.
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
    'downloads.dir' = "$Current_Script_loc\downloads"; # default location for downloads
    'sources.dir' = "$Current_Script_loc\sources"; # Note: There's not a 'git-only' folder; downloads will be unpacked next to git checkouts, even not a git clone..
    'msys2.install.dir' = "$Current_Script_loc\msys64"; # default, can be overridden in msys2.properties file
    'msys2.user.home' =  'qafila'; <# a MSYS" 'registered' user that has local admissive rights to install packages, execute build tools (CMake, for example) a.m. \
        (Perl); if a relative path is given, the user 'home' will be under /home of the MSYS2 installation. 'qafila' = arab. for caravan. #>
    'msys2.download.url' = "https://repo.msys2.org/distrib/x86_64/msys2-x86_64-20250830.exe"; 
    'msys2.packages.master.url' = "https://github.com/msys2/MSYS2-packages.git"; 
    'msys2.mingw64.packages.master.url' = "https://github.com/msys2/MINGW-packages.git"; 
    'msys2.mingw64.hdl.url' = "";
};

Function print_settings() {
    $settings.Keys | ForEach-Object{
        $message = 'Key: {0}, Value: {1}' -f $_, $settings[$_] | Write-Host
    }
}

# Read the 'msys2.properties' file and override defaults if required.
$settingsFile = Convert-Path "$Current_Script_loc\msys2.properties"
Import-Csv $settingsFile -Delimiter "=" -Header Key,Value | ForEach-Object { 
    $key = $_[0].Key #| Write-Host
    $val = $_[0].Value #| Write-Host
    $overridden = $False
    
    _log_if_debug "Import-Csv# key: $key, value: $val";
    
    if($key -eq 'downloads.dir') {
        $overridden = $True
        #$settings.Add($key, $val); False: key already present
        #$settings[$key] = $val;
    }
    elseif($key -eq 'sources.dir') {
        $overridden = $True
    }
    elseif($key -eq 'msys2.install.dir') {
        $overridden = $True
    }
    elseif($key -eq 'msys2.download.url') {
        $overridden = $True
    }
    elseif($key -eq 'msys2.packages.master.url') {
        $overridden = $True
    }
    elseif($key -eq 'msys2.mingw64.packages.master.url') {
        $overridden = $True
    }
    elseif($key -eq 'msys2.mingw64.hdl.url') {
        $overridden = $True
    }
    elseif($key -eq 'msys2.user.home') {
        $overridden = $True
    }

    # Show overrides to user for clarification if settings in msys2.properties
    if($overridden -eq $True){

        _log_if_debug "Overriding default settings: Key '$key' defined as '$($script:settings[$key])' will be overridden with '$val'!";

        $settings[$key] = $val;
    }
}

if($show_debug_information) {
    print_settings
}

# Set the path to the MSYS2 executables (GNU programs)
Write-Host "Loading MSYS2 installer.."
Import-Module "$Current_Script_loc\msys2-env.psm1" -ArgumentList @(
    $script:settings.'msys2.install.dir',
    $script:settings.'msys2.download.url'
)

$module_load_facts = Get_Module_Load_Facts;
if($module_load_facts.'msys2_install_dir' -ne $null) {
    Write-Host "Local MSYS2 installation was properly initialized.. Type 'msys_info' to get information and commands."
    Write-Host "Inspecting package-build environment (user) .."

    # next step is to enable build environment for MSYS2 packages
    $msys2_packages_master_src_dir = $script:settings.'sources.dir' + "\MSYS2-packages-master";
    $mingw64_packages_master_src_dir = $script:settings.'sources.dir' + "\MINGW-packages-master";
    Import-Module "$Current_Script_loc\msys2-packer.psm1" -ArgumentList @(
        $script:settings.'msys2.user.home',
        $script:settings.'msys2.packages.master.url',
        $msys2_packages_master_src_dir,
        $script:settings.'msys2.mingw64.packages.master.url',
        $mingw64_packages_master_src_dir
    )

    $msys_user_home_path = Convert-Path $($Env:HOME)
    if($msys_user_home_path -ne $null) {
        Write-Host "Env:HOME was properly initialized.. leading you to build environment now."
        Set-Location $msys_user_home_path
    }
    else {
        Set-Location $Current_Script_loc
    }
}
else {
    Write-Host "There have been some problems loading the local MSYS2 installation. Messages: "
    foreach($msg in $module_load_facts.debug_messages) {
        Write-Host "`t$msg";
    }
    Write-Host "Type 'msys_help' to get a list of repair options."
    Set-Location $Current_Script_loc
}
