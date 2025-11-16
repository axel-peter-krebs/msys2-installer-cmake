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

$Current_Script_loc = $PSScriptRoot;

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

if ($show_debug_information) {
    print_settings
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$recipes_folder = Convert-Path "$Current_Script_loc\recipes";
$perl_install_script_loc = "$Current_Script_loc\install.pl"

Function Run_Install_Script() {
    $file_exists = $False;
    while ( $file_exists -ne $True ) {
        $recipe = Read-Host -Prompt "Pls. tell me which recipe to run (YML file) or type 'x' to exit:";
        if($recipe -eq 'x') {
            $file_exists = $True; # hack
        }
        else {
            Write-Host "YAML file to execute: $recipes_folder/$recipe";

            $file_exists = Test-Path "$recipes_folder\$recipe";
            if($file_exists) {
                $yaml_file_cygpath = cygpath -u "$recipes_folder\$recipe";
                Write-Host "YAML Unix path: $yaml_file_cygpath";
                Invoke-Command { 
                    $queryRes = iex "perl -s $perl_install_script_loc $yaml_file_cygpath"; # arguments?
                    Write-Host "Receipe successfully executed!";
                }
            }
            else {
                Write-Host "A file '$recipe' wasn't found; pls. specifiy a valid path!";
            }
        }
    }
}

# When MSYS2 installation is found valid (synched and clean), the user may choose 
# to enter the 'packing' environment, s. while loop below
Function Start_Packing() {

    Write-Host "Inspecting package-build environment (user) .."

    # next step is to enable build environment for MSYS2 packages
    $msys2_packages_master_src_dir = $script:settings.'sources.dir' + "\MSYS2-packages-master";
    $mingw64_packages_master_src_dir = $script:settings.'sources.dir' + "\MINGW-packages-master";
    Import-Module "$Current_Script_loc\msys2-packer.psm1" -ArgumentList @(
        $script:settings.'msys2.packages.master.url',
        $msys2_packages_master_src_dir,
        $script:settings.'msys2.mingw64.packages.master.url',
        $mingw64_packages_master_src_dir
    )

    $msys_user_home_path = Convert-Path $($Env:HOME)
    if($msys_user_home_path -ne $null) {
        Write-Host "Env:HOME was properly initialized.";
        Set-Location $msys_user_home_path
    }
    else {
        Write-Host "Env:HOME seems to be missing.. ";
        Set-Location $Current_Script_loc
    }

}

# Set the path to the MSYS2 executables (GNU programs)
Write-Host "Loading MSYS2 installer.."
Import-Module "$Current_Script_loc\msys2-env.psm1" -ArgumentList @(
    $script:settings.'msys2.install.dir',
    $script:settings.'msys2.download.url'
)

# Now, Perl modules are somewhat different in MSYS2.. We have to look at https://packages.msys2.org/queue
# The point is, we cannot execute the YAML installer Perl file without having loaded the required Perl modules!
$requiredPerlModules = @(
    "perl-YAML-Syck"
);

$module_load_facts = Get_Module_Load_Facts;
if($module_load_facts.'msys2_clean' -eq $True) {
    Write-Host "Local MSYS2 installation was properly initialized..";

    # Check whether the installation contains the required Perl modules
    $installedPackages = $module_load_facts.'msys2_packages';
    #$installablePackages = $requiredPerlModules | Where {$installedPackages -NotContains $_}
    $installablePackages = @();
    foreach ($pkg in $requiredPerlModules) {
        if ($pkg -in $installedPackages.Keys) {
            Write-Host "Package already installed: $pkg";
        }
        else {
            $installablePackages += $pkg;
        }
    }
    if ( $installablePackages.count -gt 0 ) {
        Write-Host "Some required packages are missing!";
        foreach ($pkg in $installablePackages) {
            Write-Host "Package $pkg is missing."
        }
        #Export-ModuleMember "Msys_Install_Required_Packages";
        Function Msys_Install_Required_Packages() {
            Write-Host ("Installing required packages..");
            foreach ($_pkg in $installablePackages) {
                Msys_Install_Package($_pkg);
            }
        }
    }

    # Set the user Env:HOME here for modules 
    $user_home_path = $script:settings.'msys2.user.home';
    if ($user_home_path -ne 'qafila') { # user settings 
        Write-Host "User HOME set to absolute path $user_home_path; will register as Env:HOME variable..";
        $Env:HOME = Convert-Path $user_home_path;
    }
    else { # default 
        Write-Host "User HOME was not set, will register default (qafila) as Env:HOME variable..";
        $Env:HOME =  Convert-Path "$Current_Script_loc\quafila";
    }
    
    # TODO: Build the menu dynamically, resp. which functions are available
    $exitWhile = $False;
    do {
        $activity = Read-Host -Prompt "Please choose an activity: \
            Type 'H' to get information about this MSYS2 installation. \
            Type 'I' to run a YAML installer recipe. \
            Type 'P' to install missing Perl modules. \
            Type 'A' for a MSYS2-packing (package building) environment. \
            Type 'X' to exit this menu.";
        switch ($activity) {
            H {
                Msys_Help
                $exitWhile = $True;
            }
            P {
                Msys_Install_Required_Packages
            }
            I {
                Run_Install_Script
            }
            A {
                Start_Packing
                $exitWhile = $True;
            }

            X {
                Set-Location $Current_Script_loc;
                $exitWhile = $True;
            }
            default { 
                "Your input has not been recognized as a valid option!" 
            }
        }
    } while ( ! $exitWhile);
}
else {
    Write-Host "There have been problems loading the local MSYS2 installation.. Messages: "
    foreach($msg in $module_load_facts.debug_messages) {
        Write-Host "`t$msg";
    }
    Write-Host "Type 'msys_help' to get a list of options."
    Set-Location $Current_Script_loc; 
}
