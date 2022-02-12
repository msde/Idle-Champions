class IC_BrivSharedFunctions_Class extends IC_SharedFunctions_Class
{
    steelbones := ""
    sprint := ""
    
    RestartAdventure( reason := "" )
    {
            g_SharedData.LoopString := "ServerCall: Restarting adventure"
            this.CloseIC( reason )
            if(this.sprint != "" AND this.steelbones != "" AND (this.sprint + this.steelbones) < 190000)
                response := g_serverCall.CallPreventStackFail(this.sprint + this.steelbones)
            response := g_ServerCall.CallEndAdventure()
            response := g_ServerCall.CallLoadAdventure( this.CurrentAdventure )
            g_SharedData.TriggerStart := true
    }

    SetUserCredentials()
    {
        this.UserID := this.Memory.ReadUserID()
        this.UserHash := this.Memory.ReadUserHash()
        this.InstanceID := this.Memory.ReadInstanceID()
        ; needed to know if there are enough chests to open using server calls
        this.TotalGems := this.Memory.ReadGems()
        this.TotalSilverChests := this.Memory.GetChestCountByID(1)
        this.TotalGoldChests := this.Memory.GetChestCountByID(2)
        this.sprint := this.Memory.ReadHasteStacks()
        this.steelbones := this.Memory.ReadSBStacks()
    }

    ; sets the user information used in server calls such as user_id, hash, active modron, etc.
    ResetServerCall()
    {
        this.SetUserCredentials()
        g_ServerCall := new IC_BrivServerCall_Class( this.UserID, this.UserHash, this.InstanceID )
        version := this.Memory.ReadGameVersion()
        if(version != "")
            g_ServerCall.clientVersion := version
        ; TODO: Update these values based on memory reads
        g_ServerCall.webroot := this.Memory.ReadWebRoot() ? this.Memory.ReadWebRoot() : g_ServerCall.webroot
        g_ServerCall.networkID := this.Memory.ReadPlatform() ? this.Memory.ReadPlatform() : g_ServerCall.networkID
        g_ServerCall.activeModronID := this.Memory.ReadActiveGameInstance() ? this.Memory.ReadActiveGameInstance() : 1 ; 1, 2, 3 for modron cores 1, 2, 3
        g_ServerCall.activePatronID := this.Memory.ReadPatronID() ; 0 = no patron
        g_ServerCall.UpdateDummyData()
    }


    /*  WaitForModronReset - A function that monitors a modron resetting process.

        Returns:
        bool - true if completed successfully; returns false if reset does not occur within 75s
    */
    WaitForModronReset( timeout := 75000)
    {
        StartTime := A_TickCount
        ElapsedTime := 0
        g_SharedData.LoopString := "Modron Resetting..."
        this.SetUserCredentials()
        if(this.sprint != "" AND this.steelbones != "" AND (this.sprint + this.steelbones) < 190000)
            response := g_serverCall.CallPreventStackFail( this.sprint + this.steelbones)
        while (this.Memory.ReadResetting() AND ElapsedTime < timeout)
        {
            ElapsedTime := A_TickCount - StartTime
        }
        g_SharedData.LoopString := "Loading z1..."
        Sleep, 50
        while(!this.Memory.ReadUserIsInited() AND ElapsedTime < timeout)
        {
            ElapsedTime := A_TickCount - StartTime
        }
        if (ElapsedTime >= timeout)
        {
            return false
        }
        return true
    }

    ActivateLastWindow()
    {
        if(!g_BrivUserSettings["RestoreLastWindowOnGameOpen"])
            return
        Sleep, 100 ; extra wait for window to load
        hwnd := this.Hwnd
        WinActivate, ahk_id %hwnd% ; Idle Champions likes to be activated before it can be deactivated            
        savedActive := this.SavedActiveWindow
        WinActivate, %savedActive%
    }
}

class IC_BrivServerCall_Class extends IC_ServerCalls_Class
{
    ; forces an attempt for the server to remember stacks
    CallPreventStackFail(stacks)
    {
        response := ""
        stacks := g_SaveHelper.GetEstimatedStackValue(stacks)
        userData := g_SaveHelper.GetCompressedDataFromBrivStacks(stacks)
        checksum := g_SaveHelper.GetSaveCheckSumFromBrivStacks(stacks)
        save :=  g_SaveHelper.GetSave(userData, checksum, this.userID, this.userHash, this.networkID, this.clientVersion, this.instanceID)
        try
        {
            response := this.ServerCallSave(save)
        }
        catch, ErrMsg
        {
            g_SharedData.LoopString := "Failed to save Briv stacks"
        }
        return response
    }
}

class IC_BrivGemFarm_Class
{
    TimerFunctions := {}

    

    SharedRunData[]
    {
        get 
        {
            try
            {
                return ComObjActive("{416ABC15-9EFC-400C-8123-D7D8778A2103}")
            }
            catch, Err
            {
                return new IC_SharedData_Class
            }
        }
    }

    ;=====================================================
    ;Primary Functions for Briv Gem Farm
    ;=====================================================
    ;The primary loop for gem farming using Briv and modron.
    GemFarm()
    {
        static lastResetCount := 0
        g_SharedData.TriggerStart := true
        g_SF.Hwnd := WinExist("ahk_exe IdleDragons.exe")
        Process, Exist, IdleDragons.exe
        g_SF.PID := ErrorLevel
        Process, Priority, % g_SF.PID, High
        g_SF.Memory.OpenProcessReader()
        if(g_SF.VerifyAdventureLoaded() < 0)
            return
        g_SF.CurrentAdventure := g_SF.Memory.ReadCurrentObjID()
        g_SF.ResetServerCall()
        g_SF.GameStartFormation := g_BrivUserSettings[ "BrivJumpBuffer" ] > 0 ? 3 : 1
        g_SaveHelper.Init() ; slow call, loads briv dictionary (3+s)
        formationModron := g_SF.Memory.GetActiveModronFormation()
        formationQ := g_SF.FindChampIDinSavedFormation( 1, "Speed", 1, 58 )
        formationW := g_SF.FindChampIDinSavedFormation( 2, "Stack Farm", 1, 58 )
        formationE := g_SF.FindChampIDinSavedFormation( 3, "Speed No Briv", 0, 58 )
        if(!formationQ OR !formationW OR !formationE)
            return
        g_PreviousZoneStartTime := A_TickCount
        g_SharedData.StackFail := 0

	this.InitStackRestartMetrics()
        loop
        {
            g_SharedData.LoopString := "Main Loop"
            Critical, Off ; make sure this isn't stuck from something else
            Sleep, 10
            CurrentZone := g_SF.Memory.ReadCurrentZone()
            if(CurrentZone == "" AND !g_SF.SafetyCheck()) ; Check for game closed
                g_SF.ToggleAutoProgress( 1, false, true ) ; Turn on autoprogress after a restart
            g_SF.SetFormation(g_BrivUserSettings)
            if ( g_SF.Memory.ReadResetsCount() > lastResetCount OR g_SharedData.TriggerStart) ; first loop or Modron has reset
            {
                g_SharedData.BossesHitThisRun := 0
                g_SF.ToggleAutoProgress( 0, false, true )
                g_SF.WaitForFirstGold()
                keyspam := Array()
                if g_BrivUserSettings[ "Fkeys" ]
                    keyspam := g_SF.GetFormationFKeys(formationModron)
                doKeySpam := true
                keyspam.Push("{ClickDmg}")
                this.DoPartySetup()
                lastResetCount := g_SF.Memory.ReadResetsCount()
                StartTime := g_PreviousZoneStartTime := A_TickCount
                g_SharedData.StackFail := 0
                if(!g_SharedData.StackFail)
                    g_SharedData.StackFail := this.CheckForFailedConv()
                g_SharedData.SwapsMadeThisRun := 0
                PreviousZone := 1

                this.WelcomeBackClick()

                g_SharedData.TriggerStart := false
                g_SharedData.LoopString := "Main Loop"
            }
            if (g_SharedData.StackFail != 2)
                g_SharedData.StackFail := Max(this.TestForSteelBonesStackFarming(), g_SharedData.StackFail)
            if (g_SharedData.StackFail == 2 OR g_SharedData.StackFail == 4 OR g_SharedData.StackFail == 6 ) ; OR g_SharedData.StackFail == 3
                g_SharedData.TriggerStart := true
            if (!Mod( g_SF.Memory.ReadCurrentZone(), 5 ) AND Mod( g_SF.Memory.ReadHighestZone(), 5 ) AND !g_SF.Memory.ReadTransitioning())
                g_SF.ToggleAutoProgress( 1, true ) ; Toggle autoprogress to skip boss bag
            if (g_SF.Memory.ReadResetting())
                this.ModronResetCheck()
            if(CurrentZone > PreviousZone) ; needs to be greater than because offline could stacking getting stuck in descending zones.
            {
                PreviousZone := CurrentZone
                if(!Mod( g_SF.Memory.ReadHighestZone(), 5 ))
                {
                    g_SharedData.TotalBossesHit++
                    g_SharedData.BossesHitThisRun++
                }
                if(doKeySpam AND g_BrivUserSettings[ "Fkeys" ] AND g_SF.AreChampionsUpgraded(formationQ))
                {
                    g_SF.DirectedInput(hold:=0,release:=1, keyspam) ;keysup
                    keyspam := ["{ClickDmg}"]
                    doKeySpam := false
                }
                g_SF.InitZone( keyspam )
            }
            g_SF.ToggleAutoProgress( 1 )
            if(g_SF.CheckifStuck())
            {
                g_SharedData.TriggerStart := true
                g_SharedData.StackFail := StackFailStates.FAILED_TO_PROGRESS ; 3
                g_SharedData.StackFailStats.TALLY[g_SharedData.StackFail] += 1
            }
            Sleep, 20 ; here to keep the script responsive.
        }
    }

    ;===========================================
    ;Functions for updating GUI stats and timers
    ;===========================================

    CreateTimedFunctions()
    {
        this.TimedFunctions := {}
        fncToCallOnTimer :=  ObjBindMethod(this, "UpdateStatTimers")
        this.TimerFunctions[fncToCallOnTimer] := 200
        fncToCallOnTimer :=  ObjBindMethod(this, "UpdateStartLoopStats")
        this.TimerFunctions[fncToCallOnTimer] := 3000
        if(IsFunc(Func("IC_MemoryFunctions_ReadMemory")))
        {
            fncToCallOnTimer :=  Func("IC_MemoryFunctions_ReadMemory")
            this.TimerFunctions[fncToCallOnTimer] := 250
        }
        if(IsFunc(Func("IC_BrivGemFarm_Class.UpdateBrivClassStats")))
        {
            fncToCallOnTimer := ObjBindMethod(IC_BrivGemFarm_Class, "UpdateBrivClassStats")
            this.TimerFunctions[fncToCallOnTimer] := 250
        }
        fncToCallOnTimer := ObjBindMethod(this, "UpdateGUIFromCom")
        this.TimerFunctions[fncToCallOnTimer] := 100
        fncToCallOnTimer := ObjBindMethod(g_SF, "MonitorIsGameClosed")
        this.TimerFunctions[fncToCallOnTimer] := 200
    }

    ; Starts functions that need to be run in a separate thread such as GUI Updates.
    StartTimedFunctions()
    {
        for k,v in this.TimerFunctions
        {
            SetTimer, %k%, %v%, 0
        }
    }

    StopTimedFunctions()
    {
        for k,v in This.TimerFunctions
        {
            SetTimer, %k%, Off
            SetTimer, %k%, Delete
        }
    }

    ;Updates GUI dtCurrentRunTimeID and dtCurrentLevelTimeID
    UpdateStatTimers()
    {
        static startTime := A_TickCount
        static previousZoneStartTime := A_TickCount
        static previousLoopStartTime := A_TickCount
        static lastZone := -1
        static lastResetCount := 0
        static sbStackMessage := ""
        static hasteStackMessage := ""
        static LastTriggerStart := false

        TriggerStart := IsObject(this.SharedRunData) ? this.SharedRunData.TriggerStart : LastTriggerStart
        ; Critical, On
        currentZone := g_SF.Memory.ReadCurrentZone()
        if ( g_SF.Memory.ReadResetsCount() > lastResetCount OR (g_SF.Memory.ReadResetsCount() == 0 AND g_SF.Memory.ReadAreaActive() AND lastResetCount != 0 ) OR (TriggerStart AND LastTriggerStart != TriggerStart)) ; Modron or Manual reset happend
        {
            lastResetCount := g_SF.Memory.ReadResetsCount()
            previousLoopStartTime := A_TickCount
        }

        if !g_SF.Memory.ReadUserIsInited()
        {
            ; do not update lastZone if game is loading
        }
        else if ( (currentZone > lastZone) AND (currentZone >= 2)) ; zone reset
        {
            lastZone := currentZone
            previousZoneStartTime := A_TickCount
        }
        else if ((g_SF.Memory.ReadHighestZone() < 3) AND (lastZone >= 3) AND (currentZone > 0) ) ; After reset. +1 buffer for time to read value
        {
            lastZone := currentZone
            previousLoopStartTime := A_TickCount
        }

        sbStacks := g_SF.Memory.ReadSBStacks()
        if (sbStacks == "")
        {
            if (SubStr(sbStackMessage, 1, 1) != "[")
            {
                sbStackMessage := "[" . sbStackMessage . "] last seen"
            }
        } else {
            sbStackMessage := sbStacks
        }
        hasteStacks := g_SF.Memory.ReadHasteStacks()
        if (hasteStacks == "")
        {
            if (SubStr(hasteStackMessage, 1, 1) != "[")
            {
                hasteStackMessage := "[" . hasteStackMessage . "] last seen"
            }
        } else {
            hasteStackMessage := hasteStacks
        }
        GuiControl, ICScriptHub:, g_StackCountSBID, % sbStackMessage
        GuiControl, ICScriptHub:, g_StackCountHID, % hasteStackMessage

        dtCurrentRunTime := Round( ( A_TickCount - previousLoopStartTime ) / 60000, 2 )
        runMsg := dtCurrentRunTime . " " . currentZone . "/" . lastZone
        GuiControl, ICScriptHub:, dtCurrentRunTimeID, % runMsg

        dtCurrentLevelTime := Round( ( A_TickCount - previousZoneStartTime ) / 1000, 2 )
        GuiControl, ICScriptHub:, dtCurrentLevelTimeID, % dtCurrentLevelTime
        if (IsObject(SharedRunData))
            LastTriggerStart := SharedRunData.TriggerStart
        ; Critical, Off
    }

    ;Updates the stats tab's once per run stats
    UpdateStartLoopStats()
    {
        static TotalRunCount := 0
        static FailedStacking := 0
        static FailedStackConv := 0
        static SlowRunTime := 0
        static FastRunTime := 0
        static ScriptStartTime := 0
        static CoreXPStart := 0
        static GemStart := 0
        static GemSpentStart := 0
        static BossesPerHour := 0
        static LastResetCount := 0
        static RunStartTime := A_TickCount
        static IsStarted := false ; Skip recording of first run
        static StackFail
        static SilverChestCountStart := 0
        static GoldChestCountStart := 0
        static LastTriggerStart := false
        static ActiveGameInstance := 1
        static FailRunTime := 0
        static TotalRunCountRetry := 0

        ; Critical, On
        if !isStarted
        {
            LastResetCount := g_SF.Memory.ReadResetsCount()
            isStarted := true
        }

        ;testReadAreaActive := g_SF.Memory.ReadAreaActive()
        StackFail := Max(StackFail, this.SharedRunData.StackFail)
        TriggerStart := IsObject(this.SharedRunData) ? this.SharedRunData.TriggerStart : LastTriggerStart
        if ( g_SF.Memory.ReadResetsCount() > LastResetCount OR (g_SF.Memory.ReadResetsCount() == 0 AND g_SF.Memory.ReadOfflineDone() AND LastResetCount != 0 ) OR (TriggerStart AND LastTriggerStart != TriggerStart) )
        {
            while(!g_SF.Memory.ReadOfflineDone() AND IsObject(this.SharedRunData) AND this.SharedRunData.TriggerStart)
            {
                ; Critical, Off
                Sleep, 50
                ; Critical, On
            }
            ; CoreXP starting on FRESH run.
            if(!TotalRunCount OR (TotalRunCount AND TotalRunCountRetry < 2 AND (!CoreXPStart OR !GemStart)))
            {
                if(TotalRunCount)
                    TotalRunCountRetry++
                ActiveGameInstance := g_SF.Memory.ReadActiveGameInstance()
                CoreXPStart := g_SF.Memory.GetCoreXPByInstance(ActiveGameInstance)
                GemStart := g_SF.Memory.ReadGems()
                GemSpentStart := g_SF.Memory.ReadGemsSpent()
                LastResetCount := g_SF.Memory.ReadResetsCount()
                SilverChestCountStart := g_SF.Memory.GetChestCountByID(1)
                GoldChestCountStart := g_SF.Memory.GetChestCountByID(2)
                
                ; start count after first run since total chest count is counted after first run
                if(IsObject(this.SharedRunData)) 
                {
                    this.SharedRunData.PurchasedGoldChests := 0
                    this.SharedRunData.PurchasedSilverChests := 0    
                }
                
                FastRunTime := 1000
                ScriptStartTime := A_TickCount
            }
            if(IsObject(IC_InventoryView_Component) AND g_InventoryView != "") ; If InventoryView AddOn is available
            {
                InventoryViewRead := ObjBindMethod(g_InventoryView, "ReadInventory")
                InventoryViewRead.Call(TotalRunCount)
            }
            LastResetCount := g_SF.Memory.ReadResetsCount()
            PreviousRunTime := round( ( A_TickCount - RunStartTime ) / 60000, 2 )
            GuiControl, ICScriptHub:, PrevRunTimeID, % PreviousRunTime

            if (TotalRunCount AND (!StackFail OR StackFail == 6))
            {
                if (SlowRunTime < PreviousRunTime)
                    GuiControl, ICScriptHub:, SlowRunTimeID, % SlowRunTime := PreviousRunTime
                if (FastRunTime > PreviousRunTime)
                    GuiControl, ICScriptHub:, FastRunTimeID, % FastRunTime := PreviousRunTime
            }
            if ( StackFail ) ; 1 = Did not make it to Stack Zone. 2 = Stacks did not convert. 3 = Game got stuck in adventure and restarted.
            {
                GuiControl, ICScriptHub:, FailRunTimeID, % PreviousRunTime
                FailRunTime += PreviousRunTime
                GuiControl, ICScriptHub:, TotalFailRunTimeID, % round( FailRunTime, 2 )
                GuiControl, ICScriptHub:, FailedStackingID, % ArrFnc.GetDecFormattedArrayString(this.SharedRunData.StackFailStats.TALLY)
            }

            GuiControl, ICScriptHub:, TotalRunCountID, % TotalRunCount
            dtTotalTime := (A_TickCount - ScriptStartTime) / 3600000
            GuiControl, ICScriptHub:, dtTotalTimeID, % Round( dtTotalTime, 2 )
            GuiControl, ICScriptHub:, AvgRunTimeID, % Round( ( dtTotalTime / TotalRunCount ) * 60, 2 )

            if(g_SF.Memory.GetCoreXPByInstance(ActiveGameInstance))
                BossesPerHour := Round( ( ( g_SF.Memory.GetCoreXPByInstance(ActiveGameInstance) - CoreXPStart ) / 5 ) / dtTotalTime, 2 )
            GuiControl, ICScriptHub:, bossesPhrID, % BossesPerHour

            GemsTotal := ( g_SF.Memory.ReadGems() - GemStart ) + ( g_SF.Memory.ReadGemsSpent() - GemSpentStart )
            GuiControl, ICScriptHub:, GemsTotalID, % GemsTotal
            GuiControl, ICScriptHub:, GemsPhrID, % Round( GemsTotal / dtTotalTime, 2 )

            if (IsObject(this.SharedRunData))
            {
                this.UpdateStackRestartMetrics(this.SharedRunData)
                GuiControl, ICScriptHub:, SilversPurchasedID, % g_SF.Memory.GetChestCountByID(1) - SilverChestCountStart + (IsObject(this.SharedRunData) ? this.SharedRunData.PurchasedSilverChests : SilversPurchasedID)
                GuiControl, ICScriptHub:, GoldsPurchasedID, % g_SF.Memory.GetChestCountByID(2) - GoldChestCountStart + (IsObject(this.SharedRunData) ? this.SharedRunData.PurchasedGoldChests : GoldsPurchasedID)
                GuiControl, ICScriptHub:, SilversOpenedID, % (IsObject(this.SharedRunData) ? this.SharedRunData.OpenedSilverChests : SilversOpenedID)
                GuiControl, ICScriptHub:, GoldsOpenedID, % (IsObject(this.SharedRunData) ? this.SharedRunData.OpenedGoldChests : GoldsOpenedID)
                GuiControl, ICScriptHub:, ShiniesID, % (IsObject(this.SharedRunData) ? this.SharedRunData.ShinyCount : ShiniesID)
            }
            ++TotalRunCount
            StackFail := 0
            this.SharedRunData.StackFail := false
            this.SharedRunData.TriggerStart := false
            RunStartTime := A_TickCount
        }
        if (IsObject(this.SharedRunData))
            LastTriggerStart := this.SharedRunData.TriggerStart
        ; Critical, Off
    }

    UpdateGUIFromCom()
    {
        static SharedRunData
        ;activeObjects := GetActiveObjects()
        try ; avoid thrown errors when comobject is not available.
        {
            SharedRunData := ComObjActive("{416ABC15-9EFC-400C-8123-D7D8778A2103}")
            if(!g_isDarkMode)
                GuiControl, ICScriptHub: +cBlack, LoopID, 
            else
                GuiControl, ICScriptHub: +cSilver, LoopID, 
            GuiControl, ICScriptHub:, LoopID, % SharedRunData.LoopString
            GuiControl, ICScriptHub:, SwapsMadeThisRunID, % SharedRunData.SwapsMadeThisRun
            GuiControl, ICScriptHub:, BossesHitThisRunID, % SharedRunData.BossesHitThisRun
            GuiControl, ICScriptHub:, TotalBossesHitID, % SharedRunData.TotalBossesHit
        }
        catch
        {
            GuiControl, ICScriptHub: +cRed, LoopID, 
            GuiControl, ICScriptHub:, LoopID, % "Error reading from gem farm script [Closed Script?]."
        }
    }

    ;=====================================================
    ;Functions for Briv Stack farming, mostly for gem runs
    ;=====================================================
    ;Various checks to determine when to stack SteelBones should be stacked or failed to stack.
    TestForSteelBonesStackFarming()
    {
        CurrentZone := g_SF.Memory.ReadCurrentZone()
        stacks := this.GetNumStacksFarmed()
        stackfail := 0
        forcedReset := false
        forcedResetReason := ""
        ; passed stack zone, start stack farm. Normal operation.
        if ( stacks < g_BrivUserSettings[ "TargetStacks" ] AND CurrentZone > g_BrivUserSettings[ "StackZone" ] )
            this.StackFarm()
        else
        {
            ; stack briv between min zone and stack zone if briv is out of jumps (if stack fail recovery is on)
            if (g_SF.Memory.ReadHasteStacks() < 50 AND g_SF.Memory.ReadSBStacks() < g_BrivUserSettings[ "TargetStacks" ] AND CurrentZone > g_BrivUserSettings[ "MinStackZone" ] AND g_BrivUserSettings[ "StackFailRecovery" ] AND CurrentZone < g_BrivUserSettings[ "StackZone" ] )
            {
                stackFail := StackFailStates.FAILED_TO_REACH_STACK_ZONE ; 1
                g_SharedData.StackFailStats.TALLY[stackfail] += 1
                this.StackFarm()
            }
            else
            { 
                ; Briv ran out of jumps but has enough stacks for a new adventure, restart adventure
                if ( g_SF.Memory.ReadHasteStacks() < 50 AND stacks > g_BrivUserSettings[ "TargetStacks" ] AND g_SF.Memory.ReadHighestZone() > 10)
                {
                    stackFail := StackFailStates.FAILED_TO_REACH_STACK_ZONE_HARD ; 4
                    g_SharedData.StackFailStats.TALLY[stackfail] += 1
                    forcedReset := true
                    forcedResetReason := "Briv ran out of jumps but has enough stacks for a new adventure"
                }
                ; stacks are more than the target stacks and party is more than "ResetZoneBuffer" levels past stack zone, restart adventure
                ; (for restarting after stacking without going to modron reset level)
                if ( stacks > g_BrivUserSettings[ "TargetStacks" ] AND CurrentZone > g_BrivUserSettings[ "StackZone" ] + g_BrivUserSettings["ResetZoneBuffer"])
                {
                    stackFail := StackFailStates.FAILED_TO_RESET_MODRON ; 6
                    g_SharedData.StackFailStats.TALLY[stackfail] += 1
                    forcedReset := true
                    forcedResetReason := " Stacks > target stacks & party > " . g_BrivUserSettings["ResetZoneBuffer"] . " levels past stack zone"
                }
                if(forcedReset)
                    g_SF.RestartAdventure(forcedResetReason)
            }
        }
        return stackfail
    }

    ;thanks meviin for coming up with this solution
    ;Gets total of SteelBonesStacks + Haste Stacks
    GetNumStacksFarmed()
    {
        ; original:
        ; if ( g_BrivUserSettings[ "RestartStackTime" ] )
        ; to accomodate early stacking:
        ; return steelbones + 47 if we are past stack zone like online stacking and have stacks
        ; There is a point during modron reset where we have reset current zone, but not converted stacks
        currentZone := g_SF.Memory.ReadCurrentZone()
        sbStacks := g_SF.Memory.ReadSBStacks()
        ; if ( g_BrivUserSettings[ "RestartStackTime" ] AND (g_SF.Memory.ReadCurrentZone() < g_BrivUserSettings[ "StackZone" ]) AND (g_SF.Memory.ReadCurrentZone() > 0) )
        if ( g_BrivUserSettings[ "RestartStackTime" ] AND ((currentZone < g_BrivUserSettings[ "StackZone" ]) OR currentZone >= g_SF.ModronResetZone))
        {
            return sbStacks + g_SF.Memory.ReadHasteStacks()
        }
        else
        {
            ; If restart stacking is disabled, we'll stack to basically the exact
            ; threshold.  That means that doing a single jump would cause you to
            ; lose stacks to fall below the threshold, which would mean StackNormal
            ; would happen after every jump.
            ; Thus, we use a static 47 instead of using the actual haste stacks
            ; with the assumption that we'll be at minimum stacks after a reset.
            return sbStacks + 47
        }
    }

    /*  StackRestart - Stops progress and wwitches to appropriate party to prepare for stacking Briv's SteelBones.
                       Falls back from a boss zone if necessary.

    Parameters:

    Returns:
    */
    ; Stops progress and switches to appropriate party to prepare for stacking Briv's SteelBones.
    StackFarmSetup()
    {
        inputValues := "{w}" ; Stack farm formation hotkey
        g_SF.DirectedInput(,, inputValues )
        g_SF.WaitForTransition( inputValues )
        g_SF.ToggleAutoProgress( 0 , false, true )
        g_SF.FallBackFromBossZone( inputValues )
        StartTime := A_TickCount
        ElapsedTime := 0
        counter := 0
        sleepTime := 50
        g_SharedData.LoopString := "Setting stack farm formation."
        while ( !g_SF.IsCurrentFormation(g_SF.Memory.GetFormationByFavorite( 2 )) AND ElapsedTime < 5000 )
        {
            ElapsedTime := A_TickCount - StartTime
            if( ElapsedTime > (counter * sleepTime)) ; input limiter..
            {
                g_SF.DirectedInput(,,inputValues)
                counter++
            }
        }
        return
    }

    ;Starts stacking SteelBones based on settings (Restart or Normal).
    StackFarm()
    {
        if ( g_BrivUserSettings[ "RestartStackTime" ] AND stacks < g_BrivUserSettings[ "TargetStacks" ] )
            this.StackRestart()
        else if (stacks < g_BrivUserSettings[ "TargetStacks" ])
            this.StackNormal()
        currentFormation := g_SF.Memory.GetCurrentFormation()
        isShandieInFormation := g_SF.IsChampInFormation( 47, currentFormation )
        if ( !g_BrivUserSettings[ "DisableDashWaitStack" ] AND !g_BrivUserSettings[ "DisableDashWait" ] AND isShandieInFormation ) ;AND g_SF.Memory.ReadHighestZone() + 50 < g_BrivUserSettings[ "StackZone"] )
            g_SF.DoDashWait( Max(g_SF.ModronResetZone - g_BrivUserSettings[ "DashWaitBuffer" ], 0) )
    }

    /*  StackRestart - Stack Briv's SteelBones by switching to his formation and restarting the game.
                       Attempts to buy are open chests while game is closed.

    Parameters:

    Returns:
    */
    ; Stack Briv's SteelBones by switching to his formation and restarting the game.
    StackRestart()
    {
        stacks := this.GetNumStacksFarmed()
        i := 0
        while ( stacks < g_BrivUserSettings[ "TargetStacks" ] AND i < 10 )
        {
            ++i
            this.StackFarmSetup()
            formationArray := g_SF.Memory.GetCurrentFormation()
            startSBStacks := g_SF.Memory.ReadSBStacks()
            g_SF.CloseIC( "StackRestart" )
            StartTime := A_TickCount
            ElapsedTime := 0
            g_SharedData.LoopString := "Stack Sleep"
            var := ""
            if ( g_BrivUserSettings[ "DoChests" ] AND formationArray != "" )
            {
                startTime := A_TickCount
                if(g_BrivUserSettings[ "DoChestsContinuous" ])
                {
                    while(g_BrivUserSettings[ "RestartStackTime" ] > ( A_TickCount - startTime ))
                    {
                        var .= this.BuyOrOpenChests(startTime) . "`n"
                    }
                }
                else
                {
                    var := this.BuyOrOpenChests() . " "
                }
                ElapsedTime := A_TickCount - StartTime
                g_SharedData.LoopString := "Sleep: " . var
            }
            while ( ElapsedTime < g_BrivUserSettings[ "RestartStackTime" ] )
            {
                ElapsedTime := A_TickCount - StartTime
                g_SharedData.LoopString := "Stack Sleep: " . g_BrivUserSettings[ "RestartStackTime" ] - ElapsedTime . var
            }
            g_SF.SafetyCheck()
            stacks := this.GetNumStacksFarmed() ; Update GUI and Globals
            this.RecordRestartMetrics(startSBStacks)
            ;check if save reverted back to below stacking conditions
            if ( g_SF.Memory.ReadCurrentZone() < g_BrivUserSettings[ "MinStackZone" ] )
            {
                Break  ; "Bad Save? Loaded below stack zone, see value."
            }
        }
        g_PreviousZoneStartTime := A_TickCount
        return
    }

    StackNormal()
    {
        stacks := this.GetNumStacksFarmed()
        if (stacks >= g_BrivUserSettings[ "TargetStacks" ] OR g_SF.Memory.ReadCurrentZone() == 1 OR g_SF.Memory.ReadHasteStacks() >= g_BrivUserSettings[ "TargetStacks" ]) ; avoids attempts to stack again after stacking has been completed and level not reset yet.
            return
        this.StackFarmSetup()
        StartTime := A_TickCount
        ElapsedTime := 0
        g_SharedData.LoopString := "Stack Normal"
        prevSB := g_SF.Memory.ReadSBStacks()
        while ( stacks < g_BrivUserSettings[ "TargetStacks" ] AND ElapsedTime < 300000 AND g_SF.Memory.ReadCurrentZone() > g_BrivUserSettings[ "MinStackZone" ] )
        {
            g_SF.FallBackFromBossZone( ["{w}"] )
            stacks := this.GetNumStacksFarmed()
            if ( g_SF.Memory.ReadSBStacks() > prevSB)
                StartTime := A_TickCount
            ElapsedTime := A_TickCount - StartTime
        }
        g_PreviousZoneStartTime := A_TickCount
        g_SF.FallBackFromZone()
        g_SF.ToggleAutoProgress( 1 )
        return
    }

    /* ;A function that checks if farmed SB stacks from previous run failed to convert to haste.
       ;If so, the script will manually end the adventure to attempt to convert the stacks, close IC, use a servercall to restart the adventure, and restart IC.
    */
    CheckForFailedConv()
    {
        CurrentZone := g_SF.Memory.ReadCurrentZone()
        ; Zone 10 gives plenty leeway for fast starts that skip level 1 while being low enough to not have received briv stacks
        ; needed to ensure DoPartySetup
        if ( g_BrivUserSettings[ "StackFailRecovery" ] AND CurrentZone <= 10)
        {
            stacks := this.GetNumStacksFarmed()
            If (g_SF.Memory.ReadHasteStacks() < g_BrivUserSettings[ "TargetStacks" ] AND stacks > g_BrivUserSettings[ "TargetStacks" ])
            {
                g_SharedData.StackFailStats.TALLY[StackFailStates.FAILED_TO_CONVERT_STACKS] += 1
                g_SF.RestartAdventure( "Failed Conversion" )
                g_SF.SafetyCheck()
                return StackFailStates.FAILED_TO_CONVERT_STACKS ; 2
            }
            If (g_SF.Memory.ReadHasteStacks() < g_BrivUserSettings[ "TargetStacks" ] AND stacks <= 50)
            {
                g_SharedData.StackFailStats.TALLY[StackFailStates.FAILED_TO_KEEP_STACKS] += 1
                return StackFailStates.FAILED_TO_KEEP_STACKS ; 5
            }
        }
        return 0
    }

    ;===========================================================
    ;Helper functions for Briv Gem Farm
    ;===========================================================
    /*  DoPartySetup - When gem farm is started or a zone is reloaded, this is called to set up the primary party.
                       Levels Shandie and Briv, waits for Shandie Dash to start, completes the quests of the zone and then go time.

        Parameters:

        Returns:
    */
    DoPartySetup()
    {
        formationFavorite1 := g_SF.Memory.GetFormationByFavorite( 1 )
        isShandieInFormation := g_SF.IsChampInFormation( 47, formationFavorite1 )
        brivSpam := ["{q}"]
        if(isShandieInFormation)
        {
            brivSpam.push("{F6}")
        }
        g_SF.LevelChampByID( 58, 170, 7000, brivSpam) ; level briv first, but also shandie to start dash timer ASAP
        if(isShandieInFormation)
        {
            g_SF.LevelChampByID( 47, 230, 7000, "{q}") ; level shandie
        }
        isHavilarInFormation := g_SF.IsChampInFormation( 56, formationFavorite1 )
        if(isHavilarInFormation)
        {
            g_SF.LevelChampByID( 56, 15, 7000, "{q}") ; level havi
            ultButton := g_SF.GetUltimateButtonByChampID(56)
            if (ultButton != -1)
                g_SF.DirectedInput(,, ultButton)
        }
        if(g_BrivUserSettings[ "Fkeys" ])
        {
            keyspam := g_SF.GetFormationFKeys(g_SF.Memory.GetActiveModronFormation()) ; level other formation champions
            keyspam.Push("{ClickDmg}")
            g_SF.DirectedInput(,release :=0, keyspam*) ;keysdown
        }
        g_SF.ModronResetZone := g_SF.Memory.GetCoreTargetAreaByInstance(g_SF.Memory.ReadActiveGameInstance()) ; once per zone in case user changes it mid run.
        if ( !g_BrivUserSettings[ "DisableDashWaitSetup" ] AND !g_BrivUserSettings[ "DisableDashWait" ] AND isShandieInFormation ) ;AND g_SF.Memory.ReadHighestZone() + 50 < g_BrivUserSettings[ "StackZone"] )
            g_SF.DoDashWait( Max(g_SF.ModronResetZone - g_BrivUserSettings[ "DashWaitBuffer" ], 0) )
        g_SF.ToggleAutoProgress( 1, false, true )
    }

    ;Waits for modron to reset. Closes IC if it fails.
    ModronResetCheck()
    {
        modronResetTimeout := 75000
        if(!g_SF.WaitForModronReset(modronResetTimeout))
            g_SF.CheckifStuck()
            ;g_SF.CloseIC( "ModronReset, resetting exceeded " . Floor(modronResetTimeout/1000) . "s" )
        g_PreviousZoneStartTime := A_TickCount
    }

    ;===========================================================
    ;functions for speeding up progression through an adventure.
    ;===========================================================

    ;=====================================================
    ;Functions for direct server calls between runs
    ;=====================================================
    /*  BuyOrOpenChests - A method to buy or open silver or gold chests based on parameters passed.

        Parameters:
        startTime - The number of milliseconds that have elapsed since the system was started, up to 49.7 days.

        Return Values:
        If no calls were made, will return a string noting so.
        On success opening or buying, will return string noting so.
        On success and shinies found, will return a string noting so.

        Note: First line is ignoring fact that once every 49 days this func can potentially be called w/ startTime at 0 ms.
    */
    BuyOrOpenChests( startTime := 0 )
    {
        startTime := startTime ? startTime : A_TickCount
        var := ""
        var2 := ""
        openSilverChestTimeEst := 3000 ; 3s
        openGoldChestTimeEst := 7000 ; 7s
        purchaseTime := 100 ; .1s
        gems := g_SF.TotalGems - g_BrivUserSettings[ "MinGemCount" ]
        if ( g_BrivUserSettings[ "BuySilvers" ] AND g_BrivUserSettings[ "RestartStackTime" ] > ( A_TickCount - startTime + purchaseTime) )
        {
            amount := Min(Floor(gems / 50), 100 )
            if(amount > 0)
            {
                response := g_ServerCall.callBuyChests( chestID := 1, amount )
                if(response.okay AND response.success)
                {
                    g_sharedData.PurchasedSilverChests += amount
                    g_SF.TotalGems := response.currency_remaining
                    gems := g_SF.TotalGems - g_BrivUserSettings[ "MinGemCount" ]
                }
                var .= " Bought " . amount . " silver chests."
            }
        }
        if ( g_BrivUserSettings[ "BuyGolds" ] AND g_BrivUserSettings[ "RestartStackTime" ] > ( A_TickCount - startTime + purchaseTime) )
        {
            amount := Min(Floor(gems / 500) , 100 )
            if(amount > 0)
            {
                response := g_ServerCall.callBuyChests( chestID := 2, amount )
                if(response.okay AND response.success)
                {
                    g_sharedData.PurchasedGoldChests += amount
                    g_SF.TotalGems := response.currency_remaining
                    gems := g_SF.TotalGems - g_BrivUserSettings[ "MinGemCount" ]
                }
                var .= " Bought " . amount . " gold chests."
            }
        }
        if ( g_BrivUserSettings[ "OpenSilvers" ] AND g_SF.TotalSilverChests > 0 AND g_BrivUserSettings[ "RestartStackTime" ] > ( A_TickCount - startTime + openSilverChestTimeEst) )
        {
            amount := Min(g_SF.TotalSilverChests, 99)
            chestResults := g_ServerCall.callOpenChests( chestID := 1, amount )
            if(chestResults.success)
            {
                g_sharedData.OpenedSilverChests += amount
                g_SF.TotalSilverChests := chestResults.chests_remaining
            }
            var2 .= g_ServerCall.ParseChestResults( chestResults )
            g_sharedData.ShinyCount += g_ServerCall.shinies
            var .= " Opened " . amount . " silver chests."
        }
        if ( g_BrivUserSettings[ "OpenGolds" ] AND g_SF.TotalGoldChests > 0 AND g_BrivUserSettings[ "RestartStackTime" ] > ( A_TickCount - startTime + openGoldChestTimeEst) )
        {
            amount := Min(g_SF.TotalGoldChests, 99)
            chestResults := g_ServerCall.callOpenChests( chestID := 2, amount )
            if(chestResults.success)
            {
                g_sharedData.OpenedGoldChests += amount
                g_SF.TotalGoldChests := chestResults.chests_remaining
            }
            var2 .= g_ServerCall.ParseChestResults( chestResults )
            g_sharedData.ShinyCount += g_ServerCall.shinies
            var .= " Opened " . amount . " gold chests."
        }
        if ( var == "" )
        {
            return "No chests opened or purchased."
        }
        else
        {
            if ( var2 != "" )
                var .= "`n" . var2
            return var
        }
    }

    ; click on welcome back.  May cause unexpected ults or viewing of Shandie's profile depending on your screen dimensions!
    WelcomeBackClick()
    {
        w := g_SF.Memory.ReadScreenWidth(1)
        h := g_SF.Memory.ReadScreenHeight(1)
        xClick := w / 2
        yClickMax := h * 0.76
        yClick := h * 0.65
        WinActivate, ahk_exe IdleDragons.exe
        while(yClick < yClickMax)
        {
            MouseClick, Left, xClick, yClick, 1
            yClick := yClick + 10
            Sleep, 25
        }
    }

    InitStackRestartMetrics()
    {
        g_SharedData.FailedStackRestart := 0
        g_SharedData.TotalStackRestartCount := 0
        g_SharedData.TotalRestartStacks := 0
        this.LastRestartStackCount := 8  ; track this many stack restarts -- limiting factor is space on stats tab
        this.LastRestartStacks := Array()
    }

    UpdateStackRestartMetrics(data)
    {
        GuiControl, ICScriptHub:, FailedStackRestartID, % data.FailedStackRestart
        GuiControl, ICScriptHub:, TotalStackRestartCountID, % data.TotalStackRestartCount
        AvgRestartStacks := Round(data.TotalRestartStacks / data.TotalStackRestartCount, 0)
        GuiControl, ICScriptHub:, AvgStackRestartStacksID, % AvgRestartStacks
        GuiControl, ICScriptHub:, LastRestartStacksID, % data.LastRestartStacksMessage
    }

    /*  RecordRestartMetrics - Record some metrics regarding offline stacking

        Parameters:
        startSBStacks - number of steelbones stacks when offline stacking started

        Returns:
    */
    RecordRestartMetrics(startSBStacks)
    {
        EndSBStacks := g_SF.Memory.ReadSBStacks()
        RestartStackCount := EndSBStacks - startSBStacks
        this.LastRestartStacks.Push(g_SF.Memory.ReadCurrentZone() . ":" . round(RestartStackCount, 0))
        if (this.LastRestartStacks.MaxIndex() > this.LastRestartStackCount)
        {
            this.LastRestartStacks.RemoveAt(1)
        }
        if (RestartStackCount < 100) ; Assume less than 100 stacks is a failed stack restart
        {
            ++g_SharedData.FailedStackRestart
        } else {
            ; only count successes in the total/average
            ++g_SharedData.TotalStackRestartCount
            g_SharedData.TotalRestartStacks += RestartStackCount
        }
        ; registered objects don't play nicely with Array, so we can't just store LastRestartStacks in g_SharedData
        g_SharedData.LastRestartStacksMessage := ""
        For k, v In this.LastRestartStacks
        {
            g_SharedData.LastRestartStacksMessage := v . " " . g_SharedData.LastRestartStacksMessage
        }
        g_SharedData.LastRestartStacksMessage := this.LastRestartStacks.MaxIndex() . ": " . g_SharedData.LastRestartStacksMessage
    }
}

#include %A_LineFile%\..\..\..\SharedFunctions\ObjRegisterActive.ahk
