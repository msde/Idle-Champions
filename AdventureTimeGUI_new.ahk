#SingleInstance force
;Level Up Script
;by mikebaldi1980
;5/27/21
;2021-11-19(Emmes): add stop at 50 briv stacks, level 2000 max
;put together with the help from many different people. thanks for all the help.
; put briv on q
; no briv on e
;----------------------------
;	User Settings
;	various settings to allow the user to Customize how the Script behaves
;----------------------------			
global ScriptSpeed := 10	    ;sets the delay after a directedinput, ms
global gHewSlot := 2			;Hew's formation slot
global gJimothy := 0			;Jim Chicken toggle
global gBrivSwap := 0
global gClickLeveling := 0
global gFkeySpam := 0
global gRight := 1
global gSpeedTime := 0
global gBrivZone := 500
global gAzakaFarm := 0
global gSpamQ := 1
global gMaxMonsters := 100
global gMaxLevel := 2000
global gJimStopZone := gMaxLevel
;variables to consider changing if restarts are causing issues
global gOpenProcess	:= 10000	;time in milliseconds for your PC to open Idle Champions
global gGetAddress := 5000		;time in milliseconds after Idle Champions is opened for it to load pointer base into memory
;end user settings
global gSlotData := []
global gSeatToggle := [0,0,0,0,0,0,0,0,0,0,0,0]

;address of Contractual Obligations
global addressCO := 0x2D880DC8

;stats
global gStackCountH     :=
global gCurrentZone     :=

SetWorkingDir, %A_ScriptDir%

;wrapper with memory reading functions sourced from: https://github.com/Kalamity/classMemory
#include classMemory.ahk

;Check if you have installed the class correctly.
if (_ClassMemory.__Class != "_ClassMemory")
{
	msgbox class memory not correctly installed. Or the (global class) variable "_ClassMemory" has been overwritten
	ExitApp
}

;pointer addresses and offsets
#include IC_MemoryFunctions.ahk

Gui, MyWindow:New
Gui, MyWindow:+Resize -MaximizeBox
Gui, MyWindow:Add, Button, x415 y25 w60 gSave_Clicked, Save
Gui, MyWindow:Add, Button, x415 y+10 w60 gRun_Clicked, `Run
Gui, MyWindow:Add, Button, x415 y+10 w60 gAzaka_Clicked, Azaka
Gui, MyWindow:Add, Button, x415 y+10 w60 gJimothy_Clicked, Jimothy
Gui, MyWindow:Add, Button, x415 y+10 w60 gReload_Clicked, `Reload
Gui, MyWindow:Add, Tab3, x5 y5 w400, Setup|Debug|
Gui, Tab, Setup
Gui, MyWindow:Add, Text, x15 y30 w120, Seats to level with Fkeys:
Loop, 12
{
	i := gSeatToggle[A_Index]
	if (A_Index = 1)
	Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x15 y+5 w60, Seat %A_Index%
	Else if (A_Index <= 6)
	Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x+5 w60, Seat %A_Index%
	Else if (A_Index = 7)
	Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x15 y+5 w60, Seat %A_Index%
	Else
	Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x+5 w60, Seat %A_Index%
}
Gui, MyWindow:Add, Edit, vNewaddressCO x15 y+10 w150, % addressCO
Gui, MyWindow:Add, Text, x+5, numContractsFufilled Mem Address
Gui, MyWindow:Add, Checkbox, vgClickLeveling Checked%gClickLeveling% x15 y+15, `Click Leveling
Gui, MyWindow:Add, Checkbox, vgFkeySpam Checked%gFkeySpam% x15 y+5, Spam Fkeys
Gui, MyWindow:Add, Checkbox, vgRight Checked%gRight% x15 y+5, Spam Right
Gui, MyWindow:Add, Checkbox, vgSpamQ Checked%gSpamQ% x15 y+5, Spam Q
Gui, MyWindow:Add, Checkbox, vgMaxLevelStop Checked%gMaxLevelStop% x15 y+5, Stop at max level
Gui, MyWindow:Add, Text, x15 y+15, Hew Slot: 
Gui, MyWindow:add, Text, vHewSlotID x+2 w50, ???
Gui, MyWindow:Add, Text, x15 y+2, Jimothy Running?
Gui, MyWindow:Add, Text, vJimothy_ClickedID x+2 w50, No
Gui, MyWindow:Add, Text, x15 y+2, Hew Alive? 
Gui, MyWindow:Add, Text, vHewAliveID x+2 w300, Maybe Jimothy isn't running yet.
Gui, MyWindow:Add, Text, x15 y+2, Current Level:
Gui, MyWindow:Add, Text, vReadCurrentZoneID x+2 w50, % gCurrentZone
Gui, MyWindow:Add, Text, vReadCurrentZone2ID x+2 w50, % gCurrentZone
Gui, MyWindow:Add, Text, x15 y+2, Briv Haste Stacks:
Gui, MyWindow:Add, Text, vHasteStacksID x+2 w50, % gStackCountH
Gui, MyWindow:Add, Edit, vNewMaxMonsters x15 y+5, % gMaxMonsters
Gui, MyWindow:Add, Text, x+5, Max Monsters
Gui, MyWindow:Add, Text, x15 y+10, Monsters Spawned:
Gui, MyWindow:Add, Text, x+5 vReadMonstersSpawnedID, ???
Gui, MyWindow:Add, Text, x15 y+15, numContractsFufilled:
Gui, MyWindow:Add, Text, vnumContractsFufilledID x+2 w50, % numContractsFufilled
Gui, MyWindow:Add, Text, x15 y+2, TigerCount:
Gui, MyWindow:Add, Text, vTigerCountID x+2 w50, % TigerCount
Gui, MyWindow:Add, Text, x15 y+2, Address CO:
Gui, MyWindow:Add, Text, vAddressCOID x+2 w100,

Gui, MyWindow:Show

Save_Clicked:
{
	Gui, Submit, NoHide
	Loop, 12
	{
		gSeatToggle[A_Index] := CheckboxSeat%A_Index%
	}
	gFKeys :=
	Loop, 12
	{
		if (gSeatToggle[A_Index])
		{
			gFKeys = %gFKeys%{F%A_Index%}
		}
	}
	GuiControl, MyWindow:, gFKeysID, % gFKeys
	addressCO := NewaddressCO
	GuiControl, MyWindow:, addressCOID, % addressCO
	GuiControl, MyWindow:, gClickLevelingID, % gClickLeveling
	GuiControl, MyWindow:, gFkeySpamID, % gFkeySpam
	GuiControl, MyWindow:, gRightID, % gRight
	GuiControl, MyWindow:, gSpamQID, % gSpamQ

	return
}

Reload_Clicked:
{
	Reload
	return
}

Run_Clicked:
{
	OpenProcess()
	; ModuleBaseAddress()
	loop
	{
		GuiControl, MyWindow:, gloopID, Run_Clicked
		if (gClickLeveling)
		DirectedInput("{SC027}")
		if (gFkeySpam)
		DirectedInput(gFKeys)
		if (gRight)
		DirectedInput("{Right}")
		if (gSpamQ)
		DirectedInput("q")
		if (gMaxLevelStop AND ReadCurrentZone(1) > gMaxLevel)
		{
			StopProgression()
			Break
		}
	}
	return
}

Azaka_Clicked:
{
	OpenProcess()
	; ModuleBaseAddress()
	AzakaFarm()
}

FindHew()
{
    loop, 10
    {
        ChampSlot := A_Index - 1
        if (ReadChampIDbySlot(1,, ChampSlot) = 75)
        {
            gHewSlot := ChampSlot
            GuiControl, MyWindow:, HewSlotID, % gHewSlot
            Break
        }
    }
    return
}

Jimothy_Clicked:
{
    GuiControl, MyWindow:, Jimothy_ClickedID, Yes
	OpenProcess()
	; ModuleBaseAddress()
	FindHew()
	loop
	{
		UpdateStacks()
		Jimothy()
		SwapOutBriv()
	        if (gStackCountH < 50)
		{
			StopProgression()
			GuiControl, MyWindow:, Jimothy_ClickedID, No Stacks
			Break
		}
		if (ReadCurrentZone(1) < 700)
		{
			LevelUp()
		}
		if (ReadCurrentZone(1) > gMaxLevel)
		{
			StopProgression()
			GuiControl, MyWindow:, Jimothy_ClickedID, No Done
			Break
		}
        ;sleep, ScriptSpeed
	}
	return
}

MyWindowGuiClose() 
{
	MsgBox 4,, Are you sure you want to `exit?
	IfMsgBox Yes
	ExitApp
    IfMsgBox No
    return True
}

$`::
Pause
return

DirectedInput(s) 
{
	SafetyCheck()
	ControlFocus,, ahk_exe IdleDragons.exe
	ControlSend,, {Blind}%s%, ahk_exe IdleDragons.exe
	Sleep, %ScriptSpeed%
}

SafetyCheck() 
{
    While(Not WinExist("ahk_exe IdleDragons.exe")) 
    {
        Run, "C:\Program Files (x86)\Steam\steamapps\common\IdleChampions\IdleDragons.exe"
	    Sleep gOpenProcess
	    OpenProcess()
	    Sleep gGetAddress
		; ModuleBaseAddress()
		gPrevRestart := A_TickCount
		gPrevLevelTime := A_TickCount
	    ++ResetCount
    }
}

UpdateStacks()
{
    gStackCountH := ReadHasteStacks(1)
    gCurrentZone := ReadCurrentZone(1)
    GuiControl, MyWindow:, ReadCurrentZone2ID, % gCurrentZone
    GuiControl, MyWindow:, HasteStacksID, % gStackCountH
}

Jimothy()
{
	if (!ReadHeroAliveBySlot(1,, gHewSlot) OR gMaxMonsters < ReadMonstersSpawned(1))
	{
		DirectedInput("{Left}")
		StartTime := A_TickCount
		ElapsedTime := 0
		GuiControl, MyWindow:, HewAliveID, No
		while (ReadTransitioning(1) AND ElapsedTime < 5000)
		{
			Sleep, 100
			UpdateElapsedTime(StartTime)
		}
		Sleep, 100
		DirectedInput("g")
	}
    else
	GuiControl, MyWindow:, HewAliveID, Yes
	Return
}

SwapOutBriv()
{
	i := mod(ReadCurrentZone(1), 50)
	j := mod(i, 5)
	; for 2x skip and to avoid z26 and z28 and z41 on Beast Intentions
	;if (i = 23 OR i = 25 OR i = 38)
	; for 2x skip and to avoid z29 on Feast of the Moon
	;if (i = 26)
	;{
	;	DirectedInput("e")
	;	Sleep, 25
	;	DirectedInput("e")
	;	Return 1
	;}

	;for 2/3x or 7/8x skip and no special levels to avoid
	if (j = 1 OR j = 2)

	;for 2/7 skip and no special levels to avoid
	;if (j = 2)
	; 3/8 skip
	;if (j = 1)
	; 1.x skip
	; if (j=0 OR j = 2 OR j = 3)
	; 1.x skip, only bosses
	; if (j=0 OR j=1 OR j = 2 OR j = 3)
	{
		DirectedInput("e")
		Sleep, 25
		DirectedInput("e")
		Return 1
	}
	DirectedInput("q")
	Return 0
}

StopProgression()
{
	StartTime := A_TickCount
	ElapsedTime := 0
	GuiControl, MyWindow:, gLoopID, Transitioning
	while (ReadTransitioning(1) AND ElapsedTime < 5000)
	{
		Sleep, 100
		UpdateElapsedTime(StartTime)
	}
	DirectedInput("{Left}")
}

UpdateElapsedTime(StartTime)
{
	ElapsedTime := A_TickCount - StartTime
	GuiControl, MyWindow:, ElapsedTimeID, % ElapsedTime
	return ElapsedTime
}

AzakaFarm() 
{  
	TigerCount := 0
	GuiControl, MyWindow:, TigerCountID, % TigerCount
    
	loop 
	{
		numContractsFufilled := idle.read(addressCO, "Int")
		GuiControl, MyWindow:, numContractsFufilledID, % numContractsFufilled
		if (numContractsFufilled > 94)
		{
			DirectedInput("4")
			DirectedInput("9")
			++TigerCount
			GuiControl, MyWindow:, TigerCountID, % TigerCount
			numContractsFufilled := idle.read(addressCO, "Int")
			GuiControl, MyWindow:, numContractsFufilledID, % numContractsFufilled
			while (numContractsFufilled > 94)
			{
				numContractsFufilled := idle.read(addressCO, "Int")
				GuiControl, MyWindow:, numContractsFufilledID, % numContractsFufilled
				Sleep, 100				
			}
		}
		Sleep, 100
    }
}

LevelUp()
{
	DirectedInput("{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F10}{F11}{F12}")
	;ChampID := ReadChampIDbySlot(1,, slot)
	;ChampSeat := ReadChampSeatBySlot(1,, slot)
	;if (ReadChampLvlBySlot(1,, slot) < arrayMaxLvl[ChampID])
	;{
	;	DirectedInput("{F" . ChampSeat . "}")
	;}
	;specialize Nay rest will be handeled by Modron
	;if (ReadChampLvlBySlot(1,, 3) = 100)
	;{
	;	SpecializeChamp(2, 2)
	;}

}

SpecializeChamp(Choice, Choices)
{
    ScreenCenterX := (ReadScreenWidth(1) / 2)
    ScreenCenterY := (ReadScreenHeight(1) / 2)
    yClick := ScreenCenterY + 225
    ButtonWidth := 70
    ButtonSpacing := 180
    TotalWidth := (ButtonWidth * Choices) + (ButtonSpacing * (Choices - 1))
    xFirstButton := ScreenCenterX - (TotalWidth / 2)
    xClick := xFirstButton + 35 + (250 * (Choice - 1))
    WinActivate, ahk_exe IdleDragons.exe
    MouseClick, Left, xClick, yClick, 1
}
