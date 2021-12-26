; Necessary to let a hotkey interrupt itself.
#MaxThreadsPerHotkey 2

; Necessary to prevent sending keys when the user is typing
#InstallKeybdHook
global ScriptSpeed := 20

;class and methods for parsing JSON (User details sent back from a server call)
#include JSON.ahk

;wrapper with memory reading functions sourced from: https://github.com/Kalamity/classMemory
#include classMemory.ahk

global g_gameManager := new GameManager

Menu, Tray, Icon, click.png

IsGameActive() {
        WinGetTitle, title, A
        return title == "Idle Champions"
}

GetGameAhkId() {

  if g_gameManager.is64BBit()
  {
    return WinExist("ahk_exe C:\Program Files\Epic Games\IdleChampions\IdleDragons.exe")
  } else {
    return WinExist("ahk_exe C:\Program Files (x86)\Steam\steamapps\common\IdleChampions\IdleDragons.exe")
  }
}

DirectedInput(key) {
  global is_skilling
  game_ahk_id := GetGameAhkId()
  if !game_ahk_id {
    is_skilling := false
    is_ulting := false
    return
  }
  ; Don't spam keys on the game when the user typed something
  ; in the last 3 seconds
  if (A_TimeIdleKeyboard > 3000) and (A_TimeIdleMouse > 1000) {
    ControlFocus,, ahk_id %game_ahk_id%
    ControlSend,, {Blind}%key%, ahk_id %game_ahk_id%
    Sleep, %ScriptSpeed%
  }
}


ReleaseStuckKeys()
{
    if GetKeyState("Alt") && !GetKeyState("Alt", "P")
    {
      Send {Alt up}
    }
    if GetKeyState("Shift") && !GetKeyState("Shift", "P")
    {
      Send {Shift up}
    }
    if GetKeyState("Control") && !GetKeyState("Control", "P")
    {
      Send {Control up}
    }
}

IdleLevelBackground() {
  global is_skilling
  global is_ulting
  ; sleep time in milliseconds
  sleep_time := 100

  num_ticks := 0
  Loop {
    if !is_skilling {
      return
    }
    game_ahk_id := GetGameAhkId()
    if !game_ahk_id {
      is_skilling := false
      return
    }
    if !IsGameActive() {
      Sleep % sleep_time
      Continue
    }

    keys := "{Right}"
    ; Click damage
    keys := keys "{SC029}{SC029}"
    ; Champions
    keys := keys "{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}"
    DirectedInput(keys)
    
    ; Move to the next level to make boss chests faster
    DirectedInput("{Right}")

    if is_ulting {
    	; Use ultimates.  Don't use Deekin's ultimate.
    	DirectedInput("234567890{Right}")
    	ReleaseStuckKeys()
    	num_ticks := num_ticks + 1
    }

    Sleep % sleep_time
  }
}

; Ctrl+Alt+1: Start auto leveling
^!1::
    is_skilling := true
    is_ulting := false
    IdleLevelBackground()
    return


; Ctrl+Alt+2: Start auto leveling with ults
^!2::
    is_skilling := true
    is_ulting := true
    IdleLevelBackground()
    return


; Ctrl+Alt+3: Turn it off
^!3::
    is_skilling := false
    is_ulting := false
    return

; Ctrl+A: Turn it off
^A::
    is_skilling := false
    is_ulting := false
    return

; Ctrl+Shift: Turn it off
$~LShift::
    is_skilling := false
    is_ulting := false
    return

; Tab: Turn it off
$Tab::
    is_skilling := false
    is_ulting := false
    ReleaseStuckKeys()
    return

