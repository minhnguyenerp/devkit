#                                                                                                        
# GDB initialisation commands for Code::Blocks
#
#show version
set confirm off
set width 0
set height 0
set breakpoint pending on
set print asm-demangle on
set unwindonsignal on
set print elements 0
#set debugevents on
set disassembly-flavor att
catch throw
source C:\Devel\CodeBlocks\share\codeblocks/scripts/stl-views-1.0.3.gdb
set args --debug-log --no-dde --no-check-associations --multiple-instance --no-splash-screen --verbose --profile=foo
