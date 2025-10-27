# Set environment variables for the local MSYS2 (msys64) installation & convenience funct
# Essentially a PS client to MSYS2\usr\bin programs
param (
    [parameter(Position=0,Mandatory=$True)][String] $MSYS64_Path,
    [parameter(Position=1,Mandatory=$False)][String] $MSYS64_User_Home
)

$debug_messages = @();

# Provide loading errors for calling script - on demand
Function Get_Module_Load_Messages() {
    return $script:debug_messages;
}

# Test if $MSYS64_Path and $MSYS64_User exist..
$msys64_path_exists = Test-Path $($MSYS64_Path);
$can_install_packages = $False;

if($msys64_path_exists -ne $True) {
    $debug_messages += "Could not find path to MSYS2 installation, looking @ '$MSYS64_Path'! \
        Either change the MSYS2 installation directory in 'msys2.properties' file, or install in 'msys64' subdirectory.";
}
else {
    $Env:MSYS2_HOME = Convert-Path "$($MSYS64_Path)"
    $can_install_packages = $True
}

# "$HOME" would not work.. Note: The Env:HOME variable is only valid during the shell session!
if($MSYS64_User_Home -ne '') {
    $user_home_exists = Test-Path "$($MSYS64_User_Home)"; # may be outside of MSYS2 installation folder
    if($user_home_exists){
        $Env:HOME = Convert-Path "$MSYS64_User_Home";
    }
    else {
        if($msys64_path_exists) {
            $msys64_user_home_exists = Test-Path "$($MSYS64_Path)\home\$($MSYS64_User_Home)"; # user name relative to MSYS2 installation
            if($msys64_user_home_exists) {
                $Env:HOME = Convert-Path "$($MSYS64_Path)\home\$($MSYS64_User_Home)";
            }
            else {
                $debug_messages += "Env:HOME could not be set, bcs. a path '$MSYS64_Path\home\$MSYS64_User_HOME' was not detected. Using 'vagrant'.";
                if($(Test-Path "$MSYS64_Path\home\vagrant") -ne $True) {
                    New-Item -Path "$MSYS64_Path\home" -Name "vagrant" -ItemType "Directory"
                }
                $Env:HOME = Convert-Path "$MSYS64_Path\home\vagrant";
            }
        }
        else {
            $debug_messages += "Neither was a MSYS2 installation detected, nor a user HOME path for '$MSYS64_User_Home'! You can fix this by setting the respective value in 'msys2.properties' file.";
        }
    }
}

# Now that we have MSYS2 on PATH, we can check some progs and config, like existing files etc. 
# [using some NOCE features of PS, nested Functiions.
if($can_install_packages) {

    $Env:Path = "$Env:MSYS2_HOME\usr\bin\;" + $Env:Path;

    # Set-Location -Path $Env:HOME - not yet!

    # $Env:MSYSTEM = "ucrt64" ??? 

    # Now that we have the MSYS2 executables in PATH, the paths to Lua, Python, Ruby etc. are standardized. 
    # Memento: The EXE used here is that of MSYS2, but not MINGW64 etc.
    $u_name_rv = uname -rv
    $which_bash = which bash
    #Write-Host "Bash: $which_bash"
    $which_wget = which wget
    $cyg_home = cygpath -w /home
    #Write-Host "cygpath_home: $cyg_home"

    Function msys_User_Home() {
        $userHomeSet = Test-Path $Env:HOME;
        if($userHomeSet) {
            #Write-Host "Found user's HOME in path: $Env:HOME"
            return $Env:HOME;
        }
        else {
            return "NOT_FOUND";
        }
    };

    Function msys_Env() {
        & printenv
    };

    $msys2Packages = @() # Read currently installed packages with pacman -Q
    $pacmanQuery = pacman -Q
        Function get_packages() {
        return $msys2Packages;
    }

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

    & query_packages # Fills the package-version array ('msys2Packages'), s.a.

    Function Msys_Packages() {
        #Write-Host $script:msys2Packages
        foreach($pkgVer in $script:msys2Packages) {
            $pkgVer # could explode.. this is actually a hash map with a single entry.
        }
    }

    # Memento: 
    Function install_package($package) {
        
    }

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

    # GitBash is not required to build the toolchains, however, things get much easier
    Function install_Git_Bash() {
        
    }

    # In order to build the Toolchains for [system|architecture], we need some additional tools in MSYS2
    # git wget mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja mingw-w64-x86_64-cmake make mingw-w64-x86_64-python3 autoconf libtool
    Function setup_Toolchain_Build_Tools() {
        
    }

    Function install_XMake() {
        cd $Env:HOME # defined above; XMake requires a user install
        # wget https://xmake.io/shget.text -O - | bash
    }

    Function Msys_Help() {
        Write-Host "Available commands are: "
        Write-Host "`tmsys_Env: Invoke 'printenv' in MSYS2."
        Write-Host "`tmsys_Info: Show MSYS2 version and additional commands."
        Write-Host "`tmsys_Bash: Enter commands in MSYS2 bash."
    }
    
    Export-ModuleMember 'msys_Help' # Print available commands
    Export-ModuleMember 'msys_Packages'
    Export-ModuleMember 'msys_Env'  # Invoke MSYS2 'printenv'
    Export-ModuleMember 'msys_Help' # Print information about the MSYS2 installation
    Export-ModuleMember 'msys_User_Home' # The caller may want to call Set-Location
    Export-ModuleMember 'msys_Bash' # Enter bash command
}

Function Msys_Info() {
    Write-Host "Local MSYS2 installation in '$Env:MSYS2_HOME'. [$u_name_rv]"
    Write-Host "Local MSYS2 user Env:HOME variable is set to '$Env:HOME'"
    if($can_install_packages){
        Write-Host "For a list of available commands, type 'Msys_Help'"
    }
}

Export-ModuleMember 'Get_Module_Load_Messages'
Export-ModuleMember 'Msys_Info'
