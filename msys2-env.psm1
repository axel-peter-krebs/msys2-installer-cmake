# msys2-env.psm1 [Essentially a PS client to MSYS2\usr\bin programs]
# Goals: 
# - Set environment variables for the local MSYS2 (MSYS2) installation: Env:MSYS2_HOME 
# - Return a hashtable of environment 'facts', that is, has the MSYS2 installation been found, which packages are installed, a.s.o.
param (
    [parameter(Position=0,Mandatory=$True)][String] $MSYS2_Path,
    [parameter(Position=1,Mandatory=$False)][String] $MSYS2_Download_URL,
    [parameter(Position=2,Mandatory=$False)][Bool] $sync_on_start
)

<#
Write-Host "MSYS2_Path: $MSYS2_Path"
Write-Host "MSYS2_Download_URL: $MSYS2_Download_URL"
Write-Host "sync_on_start: $sync_on_start"
#>

# When executing this script, some facts about the environment are gathered 
# and kept in this hashtable for investigation by the caller.
$load_facts = [pscustomobject]@{
    msys2_install_dir = $null
    msys2_clean = $False # eq 'synchronized'; 
    msys2_packages = @{} # make list of installed packages available outside this module
    avail_progs = @()
    debug_messages = @()
};

# Provide loading errors for calling script - on demand
Function Get_Module_Load_Facts() {
    return $script:load_facts; # TODO 'explode' packages array
}

Export-ModuleMember 'Get_Module_Load_Facts'; # Print information about the MSYS2 installation 

# Test if $MSYS2_Path and $MSYS2_User exist.. 
$MSYS2_path_exists = Test-Path $($MSYS2_Path);

if($MSYS2_path_exists -ne $True) {
    $script:load_facts.'debug_messages' += "Could not find path to MSYS2 installation, looking @ '$MSYS2_Path'! \
        Either change the 'msys2.install.dir' property in 'msys2.properties' to point to a valid MSYS2 installation, \
        or install MSYS2 in the 'MSYS2' subdirectory (default) manually.";
}
else {
    $Env:MSYS2_HOME = Convert-Path "$($MSYS2_Path)"; # we'll test this later..
    $script:load_facts.'msys2_install_dir' = $Env:MSYS2_HOME;
}

# Now that we have MSYS2 on PATH, we can check some progs and config, like existing files etc. 
# AND: install packages! (Maybe)
# Note: All MSYS2 progs ought to be called in a bash-like manner, e.g. iex "sh -c $program"!
if($script:load_facts.'msys2_install_dir' -ne $null) {

    # Set 'Env:Path' variable to 'Env:MSYS2_HOME\usr\bin\' so we can execute programs like 
    # 'cygpath', 'rm', 'uname'. 'which' etc.
    $Env:Path = "$Env:MSYS2_HOME\usr\bin\;" + $Env:Path;

    # now, which toolchain to use? 
    $user_env_msystem = $Env:MSYSTEM;
    if ( $user_env_msystem -eq $null ) {
        $script:load_facts.'debug_messages' += "The environment variable MSYSTEM is not set! ";
    }
    # $Env:MSYSTEM = "ucrt64" ??? 

    # Note: In PS, we cannot access the MSYS2 filesystem yet! To operate om files, we must translate
    # all paths with 'cygpath'!
    $pacman_lock_file = cygpath -w /var/lib/pacman/db.lck;
    $cyg_root = cygpath -w /
    $cyg_home = cygpath -w /home

    # Now that we have the MSYS2 executables in PATH, the paths to GNU programs are standardized. 
    # Memento: The EXE used here is that of MSYS2 (Cygwin), but not MINGW64 etc.
    $u_name_rv = iex "uname -rv";
    $which_bash = iex "sh -c 'which bash'";
    $which_curl = iex "sh -c 'which curl'";
    $which_git = iex "sh -c 'which git'";
    $which_perl = iex "sh -c 'which perl'";
    $which_wget = iex "sh -c 'which wget'";

    $script:load_facts.'avail_progs' += ($which_bash, $which_curl, $which_git, $which_perl, $which_wget);

    $msys2Packages = @(); # Read currently installed packages with pacman -Q
    $pacmanQuery = "pacman -Q";
    $pacmanSyncAllPackages = "pacman -Suy --noconfirm"; 
    $pacmanSystemUpdate = "pacman -Syyuu --noconfirm"; # check if core system updates are available
    # $pacmanInstall = "pacman -S --needed --noconfirm #{pkg}" TODO string replacement
    
    # Using the Windows port of pacman here
    Function __query_packages() {
        #Write-Host "Querying local packages.."
        $queryRes = iex "sh -c '$pacmanQuery'";  # this returns a string, separated by empty space
        $res = $queryRes -split ' '; # does not have any notion of a 'step'!
        $dual_toggle = 1;
        $currentPackageName = '';
        $currentVersion = '';
        foreach($elem in $res) { # assume order: pkg_name, pkg_version
            if ($dual_toggle -eq 1) {
                #Write-Host "cnt=1, elem = $elem"
                $currentPackageName = $elem;
                $dual_toggle = 2; # set-1-up
            }
            elseif($dual_toggle -eq 2) {
                #Write-Host "cnt=2, elem = $elem"
                $packageAndVersionTuple = @{$currentPackageName=$elem} ;
                $script:msys2Packages += $packageAndVersionTuple; # add tuple
                $dual_toggle = 1; # set-1-down
                $currentpackageName = '' # re-set
                $currentVersion = '' # re-set
            }
        } 
    }

    # some convenience functions

    Function Msys_List_Packages() {
        foreach ($package_and_version_tuple in $script:msys2Packages) {
            $package_and_version_tuple.Keys | ForEach-Object {
                $package_version = $package_and_version_tuple[$_];
                Write-Host $_ ":" $package_version;
            }
        }
    }

    # Immediately invoke this function.. There's no function.apply method like Scala etc.
    $pacman_lock = Test-Path $pacman_lock_file;
    #Write-Host "Pacman lock file exists: $pacman_lock";

    Function Msys_Sync_Packages() {
        $updateRes = "";
        if($pacman_lock -eq $True) {
            Write-Host "Cannot synchronize database: pacman found locked! Unlock with 'msys_unlock' and try again."
        }
        else {
            $updateRes = iex "sh -c '$pacmanSyncAllPackages' 2>&1";  # this returns a string, separated by empty space
            __query_packages;
            $script:load_facts.'msys2_packages' = $script:msys2Packages; 
            $script:load_facts.'msys2_clean' = $True; 
        }
        return $script:load_facts;
    }

    if ( $pacman_lock -eq $True ) { # True = pacman locked
        $script:load_facts.'debug_messages' += "Cannot load packages: file $pacman_lock_file exists! Unlock with 'msys_unlock'."

        Function Msys_Unlock() {
            try {
                Remove-Item -LiteralPath $pacman_lock_file -Force;
                # TODO: reload the whole script!
                $script:pacman_lock = $False;
            }
            catch [System.IO.FileNotFoundException] {
                Write-Output "Unlocking was not successful: $($PSItem.ToString())"
            }
        }

        Export-ModuleMember 'Msys_Unlock'; # Remove the db.lck file
    }
    else {

        if ($sync_on_start) {
            $up2date = Msys_Sync_Packages;
            #$updAvail -match '(.+)Starting core system upgrade(?<status>.+)';
            #$updAvail -match '(.+)Starting full system upgrade(.+)';
            #$script:load_facts.'msys2_clean' = $True;
            Write-Host "Update successful";
        }
        else {
            Write-Host "The property 'sync.on.start' was set to 'False': MSYS2 not updated!";
            __query_packages; # Fill the array nonetheless
            $script:load_facts.'msys2_packages' = $script:msys2Packages; 
        }
        # TODO: synchronize automatically?
    }

    Function Msys_Install_Package() {
        param (
            [parameter(Position=0,Mandatory=$True)][String] $pkg
        )
        try {
            $cmd = "$pacmanInstall $pkg";
            Write-Host "Installing package with command expression: $cmd";
            iex "sh -c '$cmd'";
        }
        catch {
            Write-Host "Problem installing $pkg!";
        }

    }

    Function Msys_System_Upgrade() {
        try {
             Write-Host "Updating packages with '$pacmanSystemUpdate'";
             iex $pacmanSystemUpdate;
        }
        catch {
            Write-Host "Problem updating MSYS2 core!";
        }
    }

    Function Msys_Info() {
        Write-Host "Local MSYS2 installation in '$Env:MSYS2_HOME' [$u_name_rv]";
        Write-Host "Invoke the cmdlet 'get_module_load_facts' to see all configuration settings.";
        Write-Host "[Also, MSYS2 installed tools are available, e.g. 'printenv', pacman -Q, bash etc.]"
    }

    Function Msys_Help() {
        Write-Host "Available options are: ";
        Write-Host "`tType 'msys_info' to print some information about this MSYS2 installation.";
        Write-Host "`tType 'msys_list_packages' to list all packages found installed.";
        Write-Host "`tType 'msys_sync_packages' to synchronize the MSYS2 database ('clean').";
        Write-Host "`tType 'msys_install_package [package_name]' to install a package (and its dependencies).";
        Write-Host "`tType 'msys_system_upgrade to upgrade MSYS2 (Core libraries and packages).";
    }

    Export-ModuleMember 'Msys_Info'; # print information about this MSYS2 installation
    Export-ModuleMember 'Msys_List_Packages';  # List installed packages
    Export-ModuleMember 'Msys_Sync_Packages';  # Update the database
    Export-ModuleMember 'Msys_Install_Package';  # Install a package
    Export-ModuleMember 'Msys_System_Upgrade';

}

else {

    Function Msys2_Install() {
        param (
            [parameter(Position=0,Mandatory=$False)][String] $download_url,
            [parameter(Position=1,Mandatory=$False)][String] $download_folder
        )
        Write-Host "Installing MSYS2 to $MSYS2_Path .."
        $_dwnld_url = "";
        #& 'C:\Program Files\IIS\Microsoft Web Deploy\msdeploy.exe'
        if ($download_url -ne $null) {
            $_dwnld_url = $download_url;
        }
        else {
            if($MSYS2_Download_URL -ne $null) {
                $_dwnld_url = $MSYS2_Download_URL;
            }
            else {
                Write-Host "Problem: You've neither specified a download URL as an argument, \
                    nor was the download URL given in the msys2.properties file!"
                return
            }
        }
    }

    Function Msys_Help() {
        Write-Host "Available options are: "
        Write-Host "`tmsys_install [download_url] [download_folder]: Installs the downloaded MSYS2 to $MSYS2_Path (as specified in 'msys2.install.dir')"
        Write-Host "`tHint: If you want to install to another location, you must specify this property in 'msys2.properties'."
        
    }

    Export-ModuleMember 'Msys2_Install';
}

Export-ModuleMember 'Msys_Help';
