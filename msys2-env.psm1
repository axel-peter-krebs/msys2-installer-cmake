# msys2-env.psm1 [Essentially a PS client to MSYS2\usr\bin programs]
# Goals: 
# - Set environment variables for the local MSYS2 (MSYS2) installation: Env:MSYS2_HOME and Env:HOME (for user 'qafila', 
#   if parameter 'MSYS2_User_Home' is not set to another location)
# - Return a hashtable of environment 'facts', that is, has the MSYS2 installation been found, which packages are installed, a.s.o.
param (
    [parameter(Position=0,Mandatory=$True)][String] $MSYS2_Path,
    [parameter(Position=1,Mandatory=$False)][String] $MSYS2_Download_URL
)

<#
Write-Host "MSYS2_Path: $MSYS2_Path"
Write-Host "MSYS2_Download_URL: $MSYS2_Download_URL"
#>

$requiredPerlModules = @{
    "cpanminus" = "1.7048-2"
}

# When executing this script, some facts about the environment are gathered 
# and kept in this hashtable for investigation by the caller.
$load_facts = [pscustomobject]@{
    msys2_install_dir = $null
    msys2_packages = @{}
    which_git = $null
    debug_messages = @()
};

# Provide loading errors for calling script - on demand
Function Get_Module_Load_Facts() {
    return $script:load_facts; # TODO 'explode' packages array
}

Export-ModuleMember 'Get_Module_Load_Facts'; # Print information about the MSYS2 installation (for calling script)

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
if($script:load_facts.'msys2_install_dir' -ne $null) {

    #Write-Host "Found MSYS2 installation in " $script:load_facts.'msys_install_dir'

    $Env:Path = "$Env:MSYS2_HOME\usr\bin\;" + $Env:Path;

    # $Env:MSYSTEM = "ucrt64" ??? 

    $can_operate_pacman = Test-Path /var/lib/pacman/db.lck

    # Now that we have the MSYS2 executables in PATH, the paths to GNU programs are standardized. 
    # Memento: The EXE used here is that of MSYS2, but not MINGW64 etc.
    $u_name_rv = uname -rv;
    $which_bash = which bash;
    $which_perl = which perl;
    $which_wget = which wget
    $which_git = which git;
    $script:load_facts.'which_git' = $which_git; # this could as well be another installation on the host!
    $cyg_root = cygpath -w /
    $cyg_home = cygpath -w /home
    $pacman_lock_file = cygpath -w /var/lib/pacman/db.lck;
    $msys2Packages = @() # Read currently installed packages with pacman -Q
    $pacmanQuery = pacman -Q
    $pacmanUpdate = pacman -Suy

    Function Msys_Unlock() {
        try {
            rm $pacman_lock_file;
            # TODO: reload script
        }
        catch [System.IO.FileNotFoundException] {
            Write-Output "Unlocking was not successful: $($PSItem.ToString())"
        }
    }

    Function Msys_Update() {
        if($can_operate_pacman -eq $False) {
            Write-Host "pacman found locked! Unlock with 'msys_unlock'."
        }
        else {
            Invoke-Command { 
                $updateRes = "$pacmanUpdate";  # this returns a string, separated by empty space
                Write-Host "Update successful, result: $updateRes"
            } 
        }
    }

    # Using the Windows port of pacman here
    Function query_packages() {
        #Write-Host "Querying local packages.."
        Invoke-Command { 
            $queryRes = "$pacmanQuery";  # this returns a string, separated by empty space
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
    }

    # Immediately invoke this function.. There's no function.apply method like Scala etc.
    $pacman_lock = Test-Path $pacman_lock_file;
    if($pacman_lock -eq $False) {
        query_packages; # Fills the package-version array ('msys2Packages'), s.a.
        $script:load_facts.'msys2_packages' = $msys2Packages; # make package list available outside this module
    }
    else {
        Write-Host "Cannot stat packages: $pacman_lock.. Unlock with 'msys_unlock'"
    }

    Function Msys_List_Packages() {
        foreach ($package_and_version_tuple in $script:msys2Packages) {
            $package_and_version_tuple.Keys | ForEach-Object {
                $package_version = $package_and_version_tuple[$_]
                Write-Host $_ ":" $package_version
            }
        }
        
    }

    $updateablePerlModules = @{
        "perl-devel" = "1.36-1"
        "perl-YAML-Syck" = "1.36-1"
    };

    # now, we've got the already installed MSYS2 packages, diff with requirements

    Function Msys_Install_Or_Update_Perl_Modules() {
        $updateablePerlModules.Keys | ForEach-Object {
            Write-Host "Required: " $_ ", version: " $updateablePerlModules[$_];
            $pkg_query = $null;
            try {
                & pacman -S --needed --noconfirm $_;
            }
            catch {
                Write-Host "Problem: " $_
            }
            
        }
    }
    
    Function Msys_Info() {
        Write-Host "Local MSYS2 installation in '$Env:MSYS2_HOME' [$u_name_rv]";
        Write-Host "Invoke the cmdlet 'Get_Module_Load_Facts' to see all configuration settings."
        Write-Host "Invoke 'Msys_List_Packages' to list all packages found installed."
        Write-Host "Invoke 'Msys_Update' to update packages to their latest version."
        Write-Host "[Also, MSYS2 installed tools are available, e.g. 'printenv', pacman -Q, bash etc.]"
    }

    Export-ModuleMember 'msys_Info'; # print information about this MSYS2 installation
    Export-ModuleMember 'Msys_List_Packages';  # List installed packages
    Export-ModuleMember "Msys_Install_Or_Update_Perl_Modules"
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

    Function msys_Help() {
        Write-Host "Available options are: "
        Write-Host "`tmsys_Install download_url [download_folder]: Installs the downloaded MSYS2 to $MSYS2_Path (as specified in 'msys2.install.dir')"
        Write-Host "`tHint: If you want to install to another location, you must specify this property in 'msys2.properties'."
    }

    Export-ModuleMember 'msys_Help';
    Export-ModuleMember 'msys_Install';
}
