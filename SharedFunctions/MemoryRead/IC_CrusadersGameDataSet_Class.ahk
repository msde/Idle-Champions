; CrusadersGameDataSet class contains IC's CrusadersGameDataSet class structure. Useful for finding information in defines.
; Note static loc is == its instance loc
#include %A_LineFile%\..\IC_GameObjectStructure_Class.ahk

class IC_CrusadersGameDataSet_Class
{
    moduleOffset := 0
    structureOffsets := 0

    __new(moduleOffset := 0, structureOffsets := 0)
    {
        this.moduleOffset := moduleOffset
        this.structureOffsets := structureOffsets
        this.Refresh()
    }

    GetVersion()
    {
        return "v2.0.2, 2022-08-22, IC v0.463+"
    }

    Refresh()
    {
        this.Main := new _ClassMemory("ahk_exe IdleDragons.exe", "", hProcessCopy)
        this.BaseAddress := this.Main.getModuleBaseAddress("mono-2.0-bdwgc.dll")+this.moduleOffset ; v463+
        this.CrusadersGame := {}
        this.CrusadersGame.Defs := {}
        this.CrusadersGame.Defs.CrusadersGameDataSet := new GameObjectStructure( this.structureOffsets ) ; v464
        this.CrusadersGame.Defs.CrusadersGameDataSet.BaseAddress := this.BaseAddress
        this.CrusadersGame.Defs.CrusadersGameDataSet.Is64Bit := this.Main.isTarget64bit
        if(!this.Main.isTarget64bit)
        {
            #include %A_LineFile%\..\Imports\IC_CrusadersGameDataSet32_Import.ahk
        }
        else
        {
            #include %A_LineFile%\..\Imports\IC_CrusadersGameDataSet64_Import.ahk
        }
    }
}

class IC_CrusadersGameDataSet64_Class
{
    __new()
    {
        this.Refresh()
    }

    GetVersion()
    {
        return "v1.2.0, 2022-08-16, IC v0.463+, 64-bit"  
    }

    Refresh()
    {
        this.Main := new _ClassMemory("ahk_exe IdleDragons.exe", "", hProcessCopy)
        this.BaseAddress := this.Main.getModuleBaseAddress("mono-2.0-bdwgc.dll")+0x0049C7C8 ; v463
        this.CrusadersGame := {}
        this.CrusadersGame.Defs := {}
        this.CrusadersGame.Defs.CrusadersGameDataSet := new GameObjectStructure( [0x40, 0xC30] ) ; v463
        this.CrusadersGame.Defs.CrusadersGameDataSet.BaseAddress := this.BaseAddress
        this.CrusadersGame.Defs.CrusadersGameDataSet.Is64Bit := true
        #include %A_LineFile%\..\Imports\IC_CrusadersGameDataSet64_Import.ahk
    }
}
