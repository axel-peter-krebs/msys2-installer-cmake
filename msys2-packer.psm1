# This scripts sets the parameters so build and install MSYS2 packages from source.
param (
    #[parameter(Position=0,Mandatory=$True)][String] $MSYS2_Path, set in Env:MSYS2_HOME
    #[parameter(Position=1,Mandatory=$False)][String] $MSYS2_User_Home,
    [parameter(Position=1,Mandatory=$False)][String] $MSYS2_Packages_URL,
    [parameter(Position=2,Mandatory=$False)][String] $MSYS2_Packages_Dest,
    [parameter(Position=3,Mandatory=$False)][String] $MINGW64_Packages_URL,
    [parameter(Position=4,Mandatory=$False)][String] $MINGW64_Packages_Dest
)

$load_facts = [pscustomobject]@{
    msys2_pkgs_git_repo_dir = $null
    msys2_pkgs_git_status = $null
    mingw64_pkgs_git_repo_dir = $null
    mingw64_pkgs_git_status = $null
    debug_messages = @()
};

Function Get_Packer_Load_Facts() {
    return $script:load_facts; 
}

Export-ModuleMember 'Get_Packer_Load_Facts';

# Path must be set previously (not a parameter to module)
$msys2_install_path = "$Env:MSYS2_HOME";
if($msys2_install_path -eq $null) {
    $script:load_facts.'debug_messages' += "The Env:MSYS2_HOME was empty.. Must be set prior to invoking this module!";
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

Function MakePKG_MSYS2() {
    param (
        [parameter(Position=0,Mandatory=$True)][String] $pkg_name
    )
    $msys2_packages_dir = $script:load_facts.'msys2_pkgs_git_repo_dir';
    $pkgbuild_dir = "$msys2_packages_dir\$pkg_name";
    $pgkbuild_cygpath = cygpath -u $pkgbuild_dir;
    Write-Host "Building package in $pgkbuild_cygpath.."
    $result = "INCOMPLETE";
    try {
        Push-Location $pkgbuild_dir; # now, current path for bash is this location
        #iex "sh -c '. /etc/makepkg.conf'"; #| Write-Host
        #$print_srcinfo_cmd = "makepkg --printsrcinfo";
        #iex "sh -c '$print_srcinfo_cmd'";
        $bash_cmd = "makepkg --packagelist";
        #$bash_cmd = "makepkg --check $pkg"; no key verification! (TODO)
        #$bash_cmd = "makepkg $pkg";
        $result = iex "sh -c '$bash_cmd' 2>&1"; # This will source the bash scripts, e.g. set environments etc.
        Pop-Location
    }
    catch {
        Write-Host "Problem installing $pkg!";

    }
    return $result;
}
Export-ModuleMember 'MakePKG_MSYS2'; 

# Now, for running 'makepkg', we need a bash-like environment.. 
Function MakePKG_MINGW() {
    param (
        [parameter(Position=0,Mandatory=$True)][String] $pkg_name
    )
    $mingw64_packages_dir = $script:load_facts.'mingw64_pkgs_git_repo_dir';
    $pkgbuild_dir = "$mingw64_packages_dir\$pkg_name";
    $pgkbuild_cygpath = cygpath -u $pkgbuild_dir;
    Write-Host "Building package in $pgkbuild_cygpath.."
    try {
        Push-Location $pkgbuild_dir; # now, current path for bash is this location
        #iex "sh -c '. /etc/makepkg.conf'"; #| Write-Host
        #$print_srcinfo_cmd = "makepkg --printsrcinfo";
        #iex "sh -c '$print_srcinfo_cmd'";
        #$list_packages_cmd = "makepkg --packagelist";
        #iex "sh -c '$list_packages_cmd'";
        $bash_cmd = "makepkg $pkg";
        iex "bash -c '$bash_cmd'";
        Pop-Location
    }
    catch {
        Write-Host "Problem installing $pkg!";
    }
    return "OK";
}

Export-ModuleMember 'MakePKG_MINGW'; 
