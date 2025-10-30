# msys2-env.psm1 [Essentially a PS client to MSYS2\usr\bin programs]
# Goals: 
# - Set environment variables for the local MSYS2 (msys64) installation: Env:MSYS2_HOME and Env:HOME (for user 'vagrant', 
#   if parameter 'MSYS64_User_Home' is not set to another location)
# - Return a hashtable of environment 'facts', that is, has the MSYS2 installation been found, which packages are installed.
param (
    [parameter(Position=0,Mandatory=$True)][String] $MSYS64_Path,
    [parameter(Position=1,Mandatory=$False)][String] $MSYS64_User_Home # if not set, use default user 'vagrant'
)

Write-Host "MSYS64_Path: $MSYS64_Path"
Write-Host "MSYS64_User_Home: $MSYS64_User_Home"

# When executing this script, some facts about the environment are gathered and kept in this hashtable for investication by the caller.
# TODO: covert the hashtable to a 'pscustomobject'
$load_facts = [pscustomobject]@{
    user_home_path = $null
    msys2_install_dir = $null
    msys2_packages = @{}
    debug_messages = @()
};

# Provide loading errors for calling script - on demand
Function Get_Module_Load_Facts() {
    return $script:load_facts;
}

Export-ModuleMember 'Get_Module_Load_Facts'; # Print information about the MSYS2 installation (for calling script)

# Test if $MSYS64_Path and $MSYS64_User exist.. 
$msys64_path_exists = Test-Path $($MSYS64_Path);
$absolute_user_home_path_exists = Test-Path $($MSYS64_User_Home);

# Create the default user home - only if MSYS2 installation is proper.
Function Set_Create_Default_User_Home() {

    # If the directory for vagrant does not exist, installation was either corrupted or the script run for the first time - create new!
    if($(Test-Path "$MSYS64_Path\home\vagrant") -ne $True) {
        New-Item -Path "$MSYS64_Path\home" -Name "vagrant" -ItemType "Directory"
    }
    $Env:HOME = Convert-Path "$MSYS64_Path\home\vagrant";
    $script:load_facts.'user_home_path' = $Env:HOME
}

if($msys64_path_exists -ne $True) {
    $script:load_facts.'debug_messages' += "Could not find path to MSYS2 installation, looking @ '$MSYS64_Path'! \
        Either change the 'msys2.install.dir' property in 'msys2.properties' to point to a valid MSYS2 installation, \
        or install MSYS2 in the 'msys64' subdirectory (default) manually.";
}
else {
    $Env:MSYS2_HOME = Convert-Path "$($MSYS64_Path)" # we'll test this later..
    $script:load_facts.'msys2_install_dir' = $Env:MSYS2_HOME;

    # "$HOME" would not work on Windows.. Note: The Env:HOME variable is only valid during the shell session!
    if($absolute_user_home_path_exists) {
        $Env:HOME = Convert-Path "$MSYS64_User_Home";
        $script:load_facts.'user_home_path' = $Env:HOME;
    }

    # An out-of-msys2 user home path was not provided - test if user home path exists in MSYS2 installation or set default user 'vagrant'
    else {

         # 1) is the default user passed as parameter? special case..
        if($MSYS64_User_Home -eq 'vagrant') {
            Set_Create_Default_User_Home;
        }
        else {
            
            # 2) A user name was provided, not 'vagrant' - check if it exists in HOME path of MSYS2 installation..
            $msys64_user_home_exists = Test-Path "$($MSYS64_Path)\home\$($MSYS64_User_Home)"; # user name relative to MSYS2 installation, th.i. MSYS2/home/{user}
            if($msys64_user_home_exists) {
                $Env:HOME = Convert-Path "$($MSYS64_Path)\home\$($MSYS64_User_Home)";
                $script:load_facts.'user_home_path' = $Env:HOME;
            }
            else {
                Set_Create_Default_User_Home;
            }
        }
    }
}

# Now that we have MSYS2 on PATH, we can check some progs and config, like existing files etc. 
if($script:load_facts.'msys2_install_dir' -ne $null) {

    #Write-Host "!!!!!!!!!!" $script:load_facts.'msys_install_dir'

    $Env:Path = "$Env:MSYS2_HOME\usr\bin\;" + $Env:Path;

    # $Env:MSYSTEM = "ucrt64" ??? 

    $can_install_packages = $False; # TODO: test availability of binaries and set accordingly

    # Now that we have the MSYS2 executables in PATH, the paths to Lua, Python, Ruby etc. are standardized. 
    # Memento: The EXE used here is that of MSYS2, but not MINGW64 etc.
    $u_name_rv = uname -rv
    $which_bash = which bash
    #Write-Host "Bash: $which_bash"
    $which_wget = which wget
    $cyg_home = cygpath -w /home
    #Write-Host "cygpath_home: $cyg_home"

    $msys2Packages = @() # Read currently installed packages with pacman -Q
    $pacmanQuery = pacman -Q

    # Using the Windows port of pacman here
    Function query_packages() {
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
    & query_packages # Fills the package-version array ('msys2Packages'), s.a.

    Function Msys_Packages() {
        #Write-Host $script:msys2Packages
        foreach($pkgVer in $script:msys2Packages) {
            $pkgVer # could explode.. this is actually a hash map with a single entry.
        }
    }

    Function msys_Env() {
        & printenv
    };

    # bash into MSYS2
    Function Msys_Bash() {
        param (
            [parameter(Position=0,Mandatory=$False)][String] $cmd
        )
        if($cmd -eq "") {
            & bash -c 'help set';
            return;
        }
        & bash -c $cmd
    }

    Function Msys_Info() {
        Write-Host "Local MSYS2 installation in '$Env:MSYS2_HOME'. [$u_name_rv]";
        Write-Host "Local MSYS2 user Env:HOME variable is set to '$Env:HOME'";
        Write-Host "To get more information about this MSYS2 installation, choose one of the following commands:"
        Write-Host "`tmsys_Env: Invoke 'printenv' in MSYS2."
        Write-Host "`tmsys_Bash: Bash into the user environment ($Env:HOME)"
        Write-Host "`tmsys_Packages: List installed packages."
        if($can_install_packages){
            
        }
    }

    Export-ModuleMember 'msys_Info';
    Export-ModuleMember 'msys_Env';  # Invoke MSYS2 'printenv'
    Export-ModuleMember 'msys_Packages';
    Export-ModuleMember 'msys_Bash' # Enter bash command
}
else {
    Function msys_Install() {
        param (
            [parameter(Position=0,Mandatory=$True)][String] $download_url,
            [parameter(Position=1,Mandatory=$False)][String] $download_folder
        )
        Write-Host "Installing MSYS2 to $MSYS64_Path .."
        #& 'C:\Program Files\IIS\Microsoft Web Deploy\msdeploy.exe'

    }

    Function msys_Help() {
        Write-Host "Available options are: "
        Write-Host "`tmsys_Install download_url [download_folder]: Installs the downloaded MSYS2 to $MSYS64_Path (as specified in 'msys2.install.dir')"
        Write-Host "`tHint: If you want to install to another location, you must specify this property in 'msys2.properties'."
    }

    Export-ModuleMember 'msys_Help';
    Export-ModuleMember 'msys_Install';
}


