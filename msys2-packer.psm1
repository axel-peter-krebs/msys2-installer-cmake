# This scripts sets the parameters so build and install MSYS2 packages from source.
param (
    #[parameter(Position=0,Mandatory=$True)][String] $MSYS2_Path, set in Env:MSYS2_HOME
    [parameter(Position=1,Mandatory=$False)][String] $MSYS2_User_Home,
    [parameter(Position=2,Mandatory=$False)][String] $MSYS2_Packages_URL,
    [parameter(Position=3,Mandatory=$False)][String] $MSYS2_Packages_Dest,
    [parameter(Position=4,Mandatory=$False)][String] $MINGW64_Packages_URL,
    [parameter(Position=5,Mandatory=$False)][String] $MINGW64_Packages_Dest
)

$load_facts = [pscustomobject]@{
    user_home_path = $null
    msys2_pkgs_git_repo_dir = $null
    msys2_pkgs_git_status = $null
    mingw64_pkgs_git_repo_dir = $null
    mingw64_pkgs_git_status = $null
    debug_messages = @()
};

# Path must be set previously (not a parameter to module)
$msys2_install_path = "$Env:MSYS2_HOME";
if($msys2_install_path -eq $null) {
    $script:load_facts.'debug_messages' += "The Env:MSYS2_HOME was empty.. Must be a failure of the invoking script!";
}

# Create the default user home - only if MSYS2 installation is proper.
Function Set_Create_Default_User_Home() {

    # If the directory for user 'qafila' does not exist, installation was either corrupted or the script run for the first time - create new!
    if($(Test-Path "$MSYS2_Path\home\qafila") -ne $True) {
        New-Item -Path "$MSYS2_Path\home" -Name "qafila" -ItemType "Directory"
    }
    $Env:HOME = Convert-Path "$MSYS2_Path\home\qafila";
    $script:load_facts.'user_home_path' = $Env:HOME
}

$absolute_user_home_path_exists = Test-Path $($MSYS2_User_Home);

# "$HOME" would not work on Windows.. Note: The Env:HOME variable is only valid during the shell session!
if($absolute_user_home_path_exists) {
    $Env:HOME = Convert-Path "$MSYS2_User_Home";
    $script:load_facts.'user_home_path' = $Env:HOME;
}

# An out-of-msys2 user home path was not provided - test if user home path exists in MSYS2 installation or set default user 'qafila'
else {

    # 1) is the default user passed as parameter? special case..
    if($MSYS2_User_Home -eq 'qafila') {
        Set_Create_Default_User_Home;
    }
    else {
        
        # 2) A user name was provided, not 'qafila' - check if it already exists in HOME path of MSYS2 installation..
        $MSYS2_user_home_exists = Test-Path "$($MSYS2_Path)\home\$($MSYS2_User_Home)"; # user name relative to MSYS2 installation, th.i. MSYS2/home/{user}
        if($MSYS2_user_home_exists) {
            $Env:HOME = Convert-Path "$($MSYS2_Path)\home\$($MSYS2_User_Home)";
            $script:load_facts.'user_home_path' = $Env:HOME;
        }
        else {
            Set_Create_Default_User_Home;
        }
    }
}

# Check preconditions for building packages

$msys2_package_repo_exists = Test-Path $($MSYS2_Packages_Dest);
if($msys2_package_repo_exists) {
    $script:load_facts.'msys2_pkgs_git_repo_dir' = $MSYS2_Packages_Dest;
}

$mingw64_package_repo_exists = Test-Path $($MINGW64_Packages_Dest);
if($mingw64_package_repo_exists) {
    $script:load_facts.'mingw64_pkgs_git_repo_dir' = $MINGW64_Packages_Dest;
}

Function Test_Perl() {
    perl -s install.pl
}

Export-ModuleMember 'Test_Perl';
