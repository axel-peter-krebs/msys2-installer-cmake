Motto: As good old Cygwin had a nice GUI.. I want one for MSYS2!

Goal: Build Linux toolchains (MINGW32, MINGW64, UCRT64, CLANG64/LLVM) for use on Windows using Xmake.

Motivation: 

Although it is possible to build Windows GUI, DLL a.s.o. on Linux (Using the mingw toolchains provided for Linux, 
s. https://www.mingw-w64.org/downloads/), in order to build Unix/Linux programs on Windows, a GCC or CLANG/LLVM 
compiler port is needed; this is provided by the MSYS2 toolchains suporting several platforms (at first, MINGW-w64 
for both i386 and x86_64, of course, but also the newer runtime UCRT64, as well as the LLVM/Clang toolchain). 

Installation steps:

- Download MSYS2-base installer and install into folder 'msys64'
- Prepare msys64 for building with cmake (install packages with pacman; this can be done by executing ps1 scripts)
- Install additional packages needed: 
  - mingw-w64-x86_64-xmake 
  
- The 'llvm-mingw' builder builds toolchains for Windows platforms, cmp. the *.sh scripts contained in the 'source'
- Provide PS commands to build toolchain on current system. 

Samples: 

- Build an application with cegui library and run tests.