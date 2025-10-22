# Python management; Note: Installation of modules can only be achieved in a 'virtual environment' (venv);
# The reason is that MSYS2 calls to pip will result in an error: 'externally-managed-environment'; therefore,
# this script is primarily occupied with venv setup. 
# Note: Since the version of the Python used dependes on the system architecture, the executability of the venv
# depends on the platform it's currently running on!
param(
    [parameter(Position=0,Mandatory=$True)][String] $Install_Root_Path
)

# Import-Module powershell-yaml

# Set encoding that Python understands ..
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
# $OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# Necessary to get write access
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$settings = @{} # new Hashtable();
$pythonInstallDir = "#root/python" # Default (installed in folder); can be overridden in settings.properties
$pythonExe = "python.exe" # maybe other, e.g. python3.13t.exe or equal
# These are compound of the former to set PATH environment
$pythonScriptsDir = "Scripts" # Standard
$pythonWindowsUtilitiesDir = "winutils" # EMBEDDED
$pythonExeFullPath = "NOT_SET"
$pythonVenvDir = ".venv" # TODO
$pythonVenvActivateScript = "Scripts\Activate.ps1"

Function Set_Paths([string] $pythonDir, [string] $pythonScriptsDir, [string] $pythonWinUtilsDir) {
    $script:pythonExeFullPath = "$pythonDir\$script:pythonExe"; # either 'python.exe' or overridden
    $env:Path = "$pythonDir;$pythonScriptsDir;$pythonWinUtilsDir;" + $env:Path
    #if($pythonShimsFullPath -ne "NOT_SET") {
        #Write-Host "pythonShimsFullPath set to $pythonShimsFullPath"
        #cmd.exe /c "$pythonShimsFullPath\env.bat" | Write-Host
    #}
}

Function Init_Vars() {
    # Iterate settings.. Memento: sequence undetermined (has to be done in one sweep)
    foreach ($key in $settings.Keys) { 
        #Write-Host "Key|Value: $key|$($settings[$key])"
        if("$key".StartsWith('python.install.dir')) {
            $script:pythonInstallDir = $settings[$key]; # Validity up to configuration            
        }
        # Use other than python.exe (override)
        elseif("$key".EndsWith('python.exe')) {
            $script:pythonExe = $settings[$key];
        }
        ### TODO Scripts dir
        elseif("$key".StartsWith('python.winutil.dir')) {
            $script:pythonWindowsUtilitiesDir = $settings[$key];
        }
    }

    $_pyRoot, $_pyScripts, $_pyUtils = ""
    # If the install root has not been given in the settings file, we must take care  of it
    if($script:pythonInstallDir -eq "#root/python") {
        $_pyRoot = "$($Install_Root_Path)\python"; # manual Python installation (embedded) 
        $_pyScripts = "$($Install_Root_Path)\python\Scripts"; # manual Python installation (embedded) 
        $_pyUtils = "$($Install_Root_Path)\$($script:pythonWindowsUtilitiesDir)"; # 'winutils'
    }
    else {
        $_pyRoot = "$($script:pythonInstallDir)" 
        $_pyScripts = "$($script:pythonInstallDir)\$($script:pythonScriptsDir)" 
        $_pyUtils = "$($script:pythonWindowsUtilitiesDir)"
    }
    
    & Set_Paths $_pyRoot $_pyScripts $_pyUtils
}

Function Add_Property([String] $Key, [String] $Value) {
    begin{}
    process{
        $script:settings[$Key] = $Value 
    }
    end{}
}

# $props is kept in memory, thusly be returned here
Function Get_Settings() {
    return $settings;
}

Function Print_Settings() {
    Write-Host "Settings: "
    foreach ($key in $settings.Keys) { 
        #Write-Host "`tKey: $key, Value: $($settings[$key])" 
        Write-Host "Key|Value: $key|$($settings[$key])";
    }
    Write-Host "Root of Python installation: " $script:pythonInstallDir;
    Write-Host "Path to Python executable is:" $script:pythonExeFullPath;
    Write-Host "Path to Python Scripts: $script:pythonScriptsDir";
    Write-Host "Python winutils can be found at: $script:pythonWindowsUtilitiesDir";
}

Function Test_Python_VV() {
    if($pythonExeFullPath -eq "NOT_SET") {
        return "No python.exe found on env:PATH!"
    }
    else {
        #Write-Host "Executing Python command with $pythonExeFullPath .."
        $erg = & $pythonExeFullPath "-VV"
        return $erg
    }
}

Function Create_Venv() {
    #Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    #Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
    Set-executionpolicy Bypass -scope Process
    Write-Host "Creating Python virtualenvironment (venv) in $pythonVenvDir"
    & $pythonExeFullPath -m venv "$($pythonVenvDir)"
}

Function Source_Venv_Activate() {
    $activatePath = Convert-Path "$($Install_Root_Path)\$($pythonVenvDir)\$($pythonVenvActivateScript)"
    if (Test-Path $activatePath){
       Write-Host "Calling 'activate' in $activatePath "
       . $activatePath
    }
    
}

Function Download_Source() {

    # This necessary for PYENV to allow for downloads
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

}

<#

$venvDir = "$caller_path\.venv" # hard-coded; 
$pythonVersion = ""
$pythonModules = New-Object string[] ''  # new Hashtable();
$pipInspect = ""

# This Function actually gathers information about the local (MSYS2) Python environment. 
Function Ensure_Python3() {
    # python -m ensurepip # No.. we are not going to use the system-wide pip, but the venv..
    python -VV;
    #$pipInspect = @(python -m pip inspect);
    #python -m venv -h 
}

Function Print_Env() {
    Write-Host "MYSY2 Python: " python -VV;
    Write-Host "MSYS2 Python modules (pip): $pythonModules"
    Write-Host "MSYS2 Python 'pip inspect': $pipInspect"
}


Function Install_Venv() {
    Set-ExecutionPolicy Unrestricted -Force -Scope Process
    $ex_pol = Get-ExecutionPolicy
    Write-Host "Installing / Updating venv in $venvDir Execition-Policy: $ex_pol"
    python -m venv $venvDir --copies 
}

Function Source_Venv_Activate() {
    . "$venvDir\bin\Activate.ps1" $venvDir
}

Function Install_MSYS2() {
    # Download the archive
    (New-Object System.Net.WebClient).DownloadFile('', 'msys2.exe')
    .\msys2.exe -y -oC:\  # Extract to C:\msys64
    Remove-Item msys2.exe  # Delete the archive again
}
#>

Export-ModuleMember -Function 'Add_Property'
Export-ModuleMember -Function 'Get_Settings'
Export-ModuleMember -Function 'Init_Vars'
Export-ModuleMember -Function 'Print_Settings'
Export-ModuleMember -Function 'Enter_Python'
Export-ModuleMember -Function 'Test_Python_VV'
Export-ModuleMember -Function 'Create_Venv'
Export-ModuleMember -Function 'Source_Venv_Activate'
#Export-ModuleMember -Function 'Source_Venv_Activate'
