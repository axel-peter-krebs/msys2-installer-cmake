# Set environment variables for the local MSYS2 (msys64) installation

# "$HOME" would not work.. replace!
#$Env:HOME = Convert-Path $ScriptHomeLocation
# We're $HOME already, so this would be unecessary..
#Set-Location -Path $Env:HOME

# Assuming that $ScriptHomeLocation is any directory under MSYS\home, the relative path to MSYS is: cd .\..\..
#$Env:MSYS2_HOME = Convert-Path "${ScriptHomeLocation}\..\.." 
#Write-Host "Env:MSYS2_HOME set to $Env:MSYS2_HOME"

# The only crucial question to answer is, which Python is usable in this environment,
# th.i. CLANG64, CLANGARM64, MINGW32 ,MINGW64, or UCRT64? 
# TODO Install required MSYS packages via craftenv.psm1
#$Env:MSYSTEM = "ucrt64" 

# Now that we have the MSYS root, the paths to Python, Ruby etc. are standardized. 
# Memento: The EXE used depends on the architecture specified in MSYSTEM!
#$Env:Path = "$Env:MSYS2_HOME\$Env:MSYSTEM\bin\;$Env:MSYS2_HOME\usr\bin\;" + $Env:Path;
#$whichPython3 = which python3
#$whichPip3 = which pip3
#Write-Host "Using Python in $whichPython3, pip: $whichPip3"