ReloadBrivGemFarmSettings()
{
    g_BrivUserSettings := g_SF.LoadObjectFromJSON( A_LineFile . "\..\BrivGemFarmSettings.json" )
    If !IsObject( g_BrivUserSettings )
    {
        g_BrivUserSettings := {}
        g_BrivUserSettings["WriteSettings"] := true
    }
    if ( g_BrivUserSettings[ "Fkeys" ] == "" )
        g_BrivUserSettings[ "Fkeys" ] := 1
    if ( g_BrivUserSettings[ "AvoidBosses" ] == "" )
        g_BrivUserSettings[ "AvoidBosses" ] := 0
    if ( g_BrivUserSettings[ "StackFailRecovery" ] == "" )
        g_BrivUserSettings[ "StackFailRecovery" ] := 1
    if ( g_BrivUserSettings[ "StackZone" ] == "" )
        g_BrivUserSettings[ "StackZone" ] := 700
    if (g_BrivUserSettings[ "TargetStacks" ] == "")
        g_BrivUserSettings[ "TargetStacks" ] := 4000
    if ( g_BrivUserSettings[ "RestartStackTime" ] == "" )
        g_BrivUserSettings[ "RestartStackTime" ] := 12000
    if ( g_BrivUserSettings[ "DoChests" ] == "" )
        g_BrivUserSettings[ "DoChests" ] := 1
    if ( g_BrivUserSettings[ "BuySilvers" ] == "" )
        g_BrivUserSettings[ "BuySilvers" ] := 1
    if ( g_BrivUserSettings[ "BuyGolds" ] == "" )
        g_BrivUserSettings[ "BuyGolds" ] := 0
    if ( g_BrivUserSettings[ "OpenSilvers" ] == "" )
        g_BrivUserSettings[ "OpenSilvers" ] := 1
    if ( g_BrivUserSettings[ "OpenGolds" ] == "" )
        g_BrivUserSettings[ "OpenGolds" ] := 1
    if ( g_BrivUserSettings[ "MinGemCount" ] == "" )
        g_BrivUserSettings[ "MinGemCount" ] := 0
    if (g_BrivUserSettings[ "DashWaitBuffer" ] == "")    
        g_BrivUserSettings[ "DashWaitBuffer" ] := 30
    if ( g_BrivUserSettings[ "WindowXPositon" ] == "" )
        g_BrivUserSettings[ "WindowXPositon" ] := 0
    if ( g_BrivUserSettings[ "WindowYPositon" ] == "" )
        g_BrivUserSettings[ "WindowYPositon" ] := 0
    if ( g_BrivUserSettings[ "HiddenFarmWindow" ] == "" )
        g_BrivUserSettings[ "HiddenFarmWindow" ] := 0
    if ( g_BrivUserSettings[ "DoChestsContinuous" ] == "" )
        g_BrivUserSettings[ "DoChestsContinuous" ] := 0
    if ( g_BrivUserSettings[ "ResetZoneBuffer" ] == "" )
        g_BrivUserSettings[ "ResetZoneBuffer" ] := 41
    if ( g_BrivUserSettings[ "MinStackZone" ] == "" )
        g_BrivUserSettings[ "MinStackZone" ] := 200
    if ( g_BrivUserSettings[ "BrivJumpBuffer" ] == "" )
        g_BrivUserSettings[ "BrivJumpBuffer" ] := 0
    if ( g_BrivUserSettings[ "DisableDashWait" ] == "" )
        g_BrivUserSettings[ "DisableDashWait" ] := false
    if ( g_BrivUserSettings[ "RestoreLastWindowOnGameOpen" ] == "" )
        g_BrivUserSettings[ "RestoreLastWindowOnGameOpen" ] := false

    if ( g_BrivUserSettings[ "AvoidBossBuffer" ] == "" )
        g_BrivUserSettings[ "AvoidBossBuffer" ] := 0  ; Set to 1 if you want `e` formation on j==1 as well
    if ( g_BrivUserSettings[ "PreferredZoneMod5" ] == "" )
        g_BrivUserSettings[ "PreferredZoneMod5" ] := -1  ; Preferred mod5 value post-stack.  Set to -1 to disable
    if ( g_BrivUserSettings[ "DisableDashWaitSetup" ] == "" )
        g_BrivUserSettings[ "DisableDashWaitSetup" ] := false ; disable dashwait on first zone/load
    if ( g_BrivUserSettings[ "DisableDashWaitStack" ] == "" )
        g_BrivUserSettings[ "DisableDashWaitStack" ] := false ; disable dashwait after restack

    if(g_BrivUserSettings["WriteSettings"] := true)
    {
        g_BrivUserSettings.Delete("WriteSettings")
        g_SF.WriteObjectToJSON( A_LineFile . "\..\BrivGemFarmSettings.json" , g_BrivUserSettings )   
    }     
}
