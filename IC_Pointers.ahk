;Updates installed after the date of this script may result in the pointer addresses no longer being accurate.
;date of script: 8/8/2020
;IC Version 1.13.3 (v342) 8/7/2020 5:0 3:43 PM

;Open a process with sufficient access to read and write memory addresses (this is required before you can use the other functions)
;You only need to do this once. But if the process closes/restarts, then you will need to perform this step again. Refer to the notes section below.
;Also, if the target process is running as admin, then the script will also require admin rights!
;Note: The program identifier can be any AHK windowTitle i.e.ahk_exe, ahk_class, ahk_pid, or simply the window title.
;hProcessCopy is an optional variable in which the opened handled is stored. 
global idle := new _ClassMemory("ahk_exe IdleDragons.exe", "", hProcessCopy) 

;This is how we find our way in memory to the data we want. Updating the game may require updating the values stored in these variables.
global pointerBaseLN 			:= idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x039FC60	;Level Number Pointer Base
global arrayPointerOffsetsLN 		:= [0x2A8, 0xAA8, 0x28, 0x18, 0xC, 0xA8, 0x98]			;Level Number Pointer Ofsets
global pointerBaseSB			:= idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x039FC60	;Steelbones Stacks Pointer Base
global arrayPointerOffsetsSB 		:= [0x2A8, 0xD50]						;Steelbones Stacks Pointer Offsets
global pointerBaseHS			:= idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x039FC60	;Steelbones Stacks Pointer Base
global arrayPointerOffsetsHS 		:= [0x2A8, 0xD54]						;Steelbones Stacks Pointer Offsets
global pointerBaseHL 			:= idle.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x039FC60	;Havilar's Current Level Pointer Base
global arrayPointerOffsetsHL 		:= [0x2A8, 0xAA8, 0x8, 0xC, 0x8, 0xEC, 0x16C]			;Havilar's Current Level Pointer Ofsets
