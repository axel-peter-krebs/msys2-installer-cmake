Motto: As good old Cygwin had a nice GUI.. I want one for MSYS2!

Goal: Build Linux toolchains (MINGW32, MINGW64, UCRT64, CLANG64/LLVM) for use on Windows using Cmake.
	Optionally, provide build environments for XMake, Bazel et al.

Motivation: 

Although it is possible to build Windows GUI, DLL a.s.o. on Linux (Using the mingw toolchains provided for Linux, 
s. https://www.mingw-w64.org/downloads/), in order to build Unix/Linux programs on Windows, a GCC or CLANG/LLVM 
compiler port is needed; this is provided by the MSYS2 toolchains suporting several platforms (at first, MINGW-w64 
for both i386 and x86_64, of course, but also the newer runtime UCRT64, as well as the LLVM/Clang toolchain). 

Installation steps:

	* Download MSYS2-base installer and install into folder 'msys2' (this can be changed via 'msys2.properties' file).
	* Configure MSYS2 installation: A User for building packages should be established, defaulting to user 'vagrant'
	  (therefore, MSYS configuration files reside in folder 'vagrant', but must be renamed before being usable).
	* In order to connect and download GitHub sources, he/she should be able to connect via the GitHub SSH device..
	  -> Use MSYS2 GNU tools to generate keys
	  -> Install GitBash for Windows 
	* Prepare msys64 for building with cmake (install packages with pacman; this can be done by executing ps1 scripts)
	  - 
	  - 
	* Install additional packages needed: 
	  - mingw-w64-x86_64-xmake 
	  
	* The 'llvm-mingw' builder builds toolchains for Windows platforms, cmp. the *.sh scripts contained in the 'source';
	  However, these will be migrated to a Perl script which in turn can be executed from PowerShell.
	  Note: Perl is pre-installed on the initial MSYS2 installation (whilst Python etc. is not; this will be done with PKGBUILD)
	* Provide PS commands to build toolchain on the current system. 

Samples: 

* Build an application with cegui library and run tests.
* Build a minmal Ruby gem and run specs.