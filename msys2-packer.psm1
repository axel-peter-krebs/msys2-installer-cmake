# This scripts sets the parameters so build and install MSYS2 packages from source.
param (
    #[parameter(Position=0,Mandatory=$True)][String] $MSYS2_Path, set in Env:MSYS2_HOME
    #[parameter(Position=1,Mandatory=$False)][String] $MSYS2_User_Home,
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

$packers_home = $Env:HOME; # set before module invocation
$user_home_path_exists = Test-Path $packers_home;
if($user_home_path_exists) {
    $script:load_facts.'user_home_path' = $packers_home;
}
else {
    $script:load_facts.'debug_messages' += "The path to the user's home '$packers_home' wasn't found!";
    return;
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
