# Convenience script to manage MSYS2 installation on Windows. Goals: cmp. 'msys2-env.psm1' and 'msys2-packer.psm1'.
# Entry point for 'msys2-env.psm1': Reading settings 'msys2.properties' (values overridden via configuration) and apply.
# If started in debug mode, print debug messages on screen.
param(
    [parameter(Position=0,Mandatory=$False)][Bool] $show_debug_information
)

#Write-Host "NEW"

Function __log_if_debug([string] $debug_message) {
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
    'msys2.user.dir' =  'qafila'; <# a MSYS" 'registered' user that has local admissive rights to install packages, execute build tools (CMake, for example) a.m. \
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
    
    __log_if_debug "Import-Csv# key: $key, value: $val";
    
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
    elseif($key -eq 'msys2.user.dir') {
        $overridden = $True
    }

    # Show overrides to user for clarification if settings in msys2.properties
    if($overridden -eq $True){
        __log_if_debug "Overriding default settings: Key '$key' defined as '$($script:settings[$key])' will be overridden with '$val'!";
        $settings[$key] = $val;
    }
}

if ($show_debug_information) {
    print_settings
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Now, Perl modules are somewhat different in MSYS2.. We have to look at https://packages.msys2.org/queue
# The point is, we cannot execute the YAML installer Perl file without having loaded the required Perl modules!
$requiredPerlModules = @(

);

# Set the path to the MSYS2 executables (GNU programs)
Write-Host "Loading MSYS2 installer.."
Import-Module "$Current_Script_loc\msys2-env.psm1" -ArgumentList @(
    $script:settings.'msys2.install.dir',
    $script:settings.'msys2.download.url'
)

$module_load_facts = Get_Module_Load_Facts;

$required_packages_for_running_installer = @(
    "perl-YAML-Syck",
    "perl-Path-Tiny",
    "perl-File-Which",
    "perl-Params-Util"
);
$recipes_folder = Convert-Path "$Current_Script_loc\recipes";
$perl_install_script_loc = "$Current_Script_loc\install.pl"

Function Run_Install_Script() {
    $file_exists = $False;
    while ( $file_exists -ne $True ) {
        $recipe = Read-Host -Prompt "`nPls. tell me which recipe to run (YAML file), or type 'x' to exit.";
        if($recipe -eq 'x') {
            $file_exists = $True; # hack
        }
        else {
            Write-Host "YAML file to execute: $recipes_folder\$recipe";
            $file_exists = Test-Path "$recipes_folder\$recipe";
            if ($file_exists) {
                # Now, if we want to use the MSYS2-Perl, we mimic a Unix-like environment, bcs. we will execute Perl in Bash
                $perl_install_script_cygpath = cygpath -u $perl_install_script_loc;
                $yaml_file_cygpath = cygpath -u "$recipes_folder\$recipe";
                Invoke-Command { 
                    #$queryRes = iex "perl -s $perl_install_script_loc $yaml_file_cygpath"; # arguments?
                    $perl_cmd = "perl -s $perl_install_script_cygpath $yaml_file_cygpath $script:settings['msys2.install.dir']";
                    iex "bash -c '$perl_cmd'"; # execute Perl in bash!!!
                    Write-Host "Receipe successfully executed!";
                }
            }
            else {
                Write-Host "A file '$recipe' wasn't found; pls. specifiy a valid path!";
            }
        }
    }
}

$required_packages_for_packing = @(
    "base-devel",
    "perl-File-Next"
);

# When MSYS2 installation is found valid (synched and clean), the user may choose 
# to enter the 'packing' environment, s. while loop below
Function Start_Packing() {

    Write-Host "Inspecting package-build environment (user) .."

    # next step is to enable build environment for MSYS2 packages; the path to the package sources
    # is hard-coded for convenience.
    $msys2_packages_master_src_dir = "$Current_Script_loc\MSYS2-packages-master";
    $mingw64_packages_master_src_dir = "$Current_Script_loc\MINGW-packages-master";

    Import-Module "$Current_Script_loc\msys2-packer.psm1" -ArgumentList @(
        $script:settings.'msys2.packages.master.url',
        $msys2_packages_master_src_dir,
        $script:settings.'msys2.mingw64.packages.master.url',
        $mingw64_packages_master_src_dir
    )

    $packer_load_facts = Get_Packer_Load_Facts;
    Write-Host "The MSYS2 git repository for packages is in " $packer_load_facts.'msys2_pkgs_git_repo_dir';
    Write-Host "The MINGW-W64 git repository for packages is in " $packer_load_facts.'mingw64_pkgs_git_repo_dir';

    $pkg_kind = Read-Host -Prompt "What kind of package do you want to build (type 'c' for MSYS2 [Cygwin], 'w' for MINGW-W64 packages, or 'x' to exit)?";
    if ( $pkg_kind -eq 'c' ) {
        $pkg = Read-Host -Prompt "Which package?";
        Make_MSYS2_Package($pkg);
    }
    elseif ($pkg_kind -eq 'w') {
        $pkg = Read-Host -Prompt "Which package?";
        Make_MINGW_Package($pkg);
    }

    #Make_MINGW_Package($pkg);
    return "OK";
}

# TODO: Build the menu dynamically, resp. which functions are available
Function Loop_Menu() {
    $exitWhile = $False;
    do {
        $activity = Read-Host -Prompt "Please choose an activity: 
        Type 'H' to get information about this MSYS2 installation. 
        Type 'Y' to run a YAML installer recipe. 
        Type 'P' for a MSYS2-packing (package building) environment. 
        Type 'X' to exit this menu.";
        switch ($activity) {
            H {
                Msys_Help
                $exitWhile = $True;
            }
            Y {
                Run_Install_Script
                 # Stay in loop
            }
            P {
                $retval = Start_Packing
                if($retval -eq "OK") {
                    Write-Host "Packaging ended with 'OK'";
                }
                else {
                    Write-Host "Something enucpected happended..";
                }
                #$exitWhile = $True;
            }
            X {
                Set-Location $Current_Script_loc;
                $exitWhile = $True;
            }
            default { 
                Write-Host "Your input has not been recognized as a valid option!" 
            }
        }
    } while ( ! $exitWhile);
}

if($module_load_facts.'msys2_clean' -eq $True) {
    Write-Host "Local MSYS2 installation was properly initialized.";

    # Check whether the installation contains the required Perl modules for YAML installer
    $installed_packages = $module_load_facts.'msys2_packages';

    #$installablePackages = $requiredPerlModules | Where {$installedPackages -NotContains $_}
    $missing_yaml_packages = @();
    Write-Host "Checking if requirements for YAML installation are met..";
    foreach ($pkg in $required_packages_for_running_installer) {
        if ($pkg -in $installed_packages.Keys) {
            Write-Host "`tRequired package '$pkg' already installed.";
        }
        else {
            $missing_yaml_packages += $pkg;
        }
    }
    if ( $missing_yaml_packages.count -gt 0 ) {
        Write-Host "Some packages for running the YAML installer are missing!";
        foreach ($pkg in $missing_yaml_packages) {
            Write-Host "`tPackage $pkg not found."
        }
    }
    
    $missing_packer_dependencies = @();
    Write-Host "Checking if requirements for building MSYS2 packages are met..";
    foreach ($pkg in $required_packages_for_packing) {
        if ($pkg -in $installed_packages.Keys) {
            Write-Host "`tRequired package '$pkg' already installed.";
        }
        else {
            $missing_packer_dependencies += $pkg;
        }
    }
    if ( $missing_packer_dependencies.count -gt 0 ) {
        Write-Host "Some dependencies for building MSYS2 packages are missing!";
        foreach ($pkg in $missing_packer_dependencies) {
            Write-Host "`tPackage $pkg not found."
        }
    }

    # Set the user Env:HOME here 
    $msys2_user_dir = $script:settings.'msys2.user.dir';
    $msys_user_home_path = Convert-Path $($msys2_user_dir)
    if ($msys_user_home_path -ne $null) { # user settings 
        #Write-Host "User HOME set to absolute path $user_home_path";
        $Env:HOME = Convert-Path $msys_user_home_path;
    }
    
    <#
    if($Env:HOME -ne $null) {
        Write-Host "Environment was properly initialized.. Will lead you to Env:HOME directory now.";
        Set-Location $Env:HOME;
    }
    else {
        Write-Host "Env:HOME seems to be missing.. ";
        Set-Location $Current_Script_loc
    }
    #>

    Loop_Menu
}
else {
    Write-Host "There have been problems loading the local MSYS2 installation.. Messages: "
    foreach($msg in $module_load_facts.debug_messages) {
        Write-Host "`t$msg";
    }
    Write-Host "Type 'msys_help' to get a list of options."
    Set-Location $Current_Script_loc; 
}
