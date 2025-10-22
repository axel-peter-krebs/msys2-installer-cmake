# This is the entry point to the MSYS2 Toolchain administration (setup) tool;
# Goal: Learn PS ;-)
param(
    #[parameter(Position=0,Mandatory=$True)][String] $call_path # Calling script must specify where S/W has to be installed
)

# We are here:
$ScriptHomeLocation = (get-item $PSScriptRoot )

# When exiting, cleanup or anything..
<#
Register-EngineEvent PowerShell.Exiting -Action { 
    $Yes_No = Read-Host "Exit? (J/n, default n)"
    Write-Host "You've entered $Yes_No" 
    #if($Yes_No == "n") {
        #powershell -noexit -file $MyInvocation.MyCommand.Path $ScriptHomeLocation
        #$host.enternestedprompt()
    #}
    Start-Sleep -Seconds 3
    exit
}
#>

Import-Module -Name "$ScriptHomeLocation\craftenv.psm1" -ArgumentList "$ScriptHomeLocation"

$settingsFile = Convert-Path "$ScriptHomeLocation\settings.properties"

# Try always to read the settings.properties file
Import-Csv $settingsFile -Header Key,Value -Delimiter "|" | ForEach-Object { 
    Add_Property ($_.Key, $_.Value)
}

& Init_Vars

& Test_Python_VV | Write-Host 

#& bash -c '. .venv/bin/activate'
# call Source_Venv_Activate manually

#$outcome = python "setup.py" -NoNewWindow 2>&1 - no.. Script execution will be done in the craftenv.psm1 module!

Set-Location $ScriptHomeLocation