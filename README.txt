Motto: As good old Cygwin had a nice GUI.. I want one for MSYS2!

To use the alien scripts, the PS must be run as Adminstrator, bcs. "Set-ExecutionPolicy Unrestricted" will be invoked..

Installation steps:
- Download Python for Windows
  Eventually run some scripts from WPy64, e.g. "python -m pip install --upgrade pip" 
- Download MSYS2-base installer
- Download llvm-mingw
- The 'llvm-mingw' builder builds toolchains for Windows platforms, cmp. the *.sh scripts contained therein
  which can be run within MSYS2; however, some preconditions must be met, that is, packages be installed.
  Note: the GCC, make etc. programs should be fit for your operating system (Windows 7,8,10,11);
  
  [The packages can be installed with craftenv]

- Provide some convenience Shells to automate installation (Powershell or Bash, when working in MSYS, e.g. GitBash)
  Note: MSYS configuration is simalr to Linux environment, such that Bash completion can be used)

Helpful system settings
- Environemtn variable PYTHONIOENCODING="utf-8"

