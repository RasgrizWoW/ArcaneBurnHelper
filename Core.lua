local addonName, ns = ...
ns = ns or _G.ArcaneBurnHelperNS
local ABH = ns.frame
local CFG = ns.CFG
local state = ns.state

local function RecordDamage(amount)
    if type(amount) == "number" and amount > 0 then
        table.insert(state.damageLog, { t = ns.Now(), amount = amount })
        ns.TrimLog(state.damageLog, CFG.dpsWindow)
    end
end

local function GetFightElapsed()
    if not state.targetFightStart then return nil end
    local elapsed = ns.Now() - state.targetFightStart
    if elapsed < 0 then elapsed = 0 end
    return elapsed
end

local function GetTargetDPS()
    ns.TrimLog(state.damageLog, CFG.dpsWindow)
    if #state.damageLog == 0 then return 0 end

    local total = 0
    for i = 1, #state.damageLog do
        total = total + state.damageLog[i].amount
    end

    local elapsed = GetFightElapsed()
    if elapsed and elapsed > 0 and elapsed < CFG.dpsWindow then
        return total / math.max(elapsed + CFG.etkGraceSeconds, 1.0)
    end

    local span = state.damageLog[#state.damageLog].t - state.damageLog[1].t
    return total / math.max(span, 1.0)
end

local function GetObservedManaPerSecond()
    ns.TrimLog(state.manaLog, CFG.manaWindow)
    if #state.manaLog < 2 then
        local _, casting = GetManaRegen()
        return casting or 0
    end

    local first = state.manaLog[1]
    local last = state.manaLog[#state.manaLog]
    local dt = last.t - first.t
    if dt <= 0 then return 0 end
    return (last.mana - first.mana) / dt
end

local function EstimateManaGemRestore(maxMana)
    return maxMana * CFG.manaGemRestorePct
end

local function GetBaselineCastingManaPS()
    local full, casting = GetManaRegen()
    if casting and casting > 0 then
        return casting
    end
    return (full or 0) * ns.GetWhileCastingSpiritFraction()
end

local function BuildSustainRotation()
    local cfg = ns.GetConfig()
    local out = {}
    for i = 1, cfg.sustainAB do out[#out + 1] = "AB" end
    for i = 1, cfg.sustainFB do out[#out + 1] = "FB" end
    if #out == 0 then out[1] = "FB" end
    return out
end

local function GetActivePotionName()
    if ns.GetConfig().potionType == "MANA" then
        return ns.FindManaPotionName()
    end
    return ns.FindDestroPotionName()
end

local function GetCooldownStates()
    local manaGemName = ns.FindManaGemName()
    local activePotionName = GetActivePotionName()
    local potionIsMana = ns.GetConfig().potionType == "MANA"

    return {
        evoReady = ns.IsSpellReady(CFG.spellEvocation),
        evoRemain = ns.GetSpellCooldownRemaining(CFG.spellEvocation),
        gemName = manaGemName,
        gemReady = ns.IsItemReady(manaGemName),
        gemRemain = ns.GetItemCooldownRemaining(manaGemName),
        potionName = activePotionName,
        potionReady = ns.IsItemReady(activePotionName),
        potionRemain = ns.GetItemCooldownRemaining(activePotionName),
        potionIsMana = potionIsMana,
    }
end


local function CooldownVisualState(remain, isReady, hasItem)
    if hasItem == false then
        return "missing"
    end
    if isReady then
        return "ready"
    end
    if type(remain) == "number" and remain ~= math.huge and remain <= ns.GetReadySoonSeconds() then
        return "soon"
    end
    return "cooldown"
end

local function SimulateRotation(mode, stopAtTime, opts)
    opts = opts or {}
    local mana, maxMana = ns.UnitMana("player")
    local activeStacks = state.abStacks or 0
    local timeSpent = 0
    local gemUsed = false
    local evoUsed = false
    local potionUsed = false
    local rotation = (mode == "BURN") and { "AB" } or BuildSustainRotation()
    local rotationIndex = 1

    local observedMPS = 0
    if UnitAffectingCombat("player") then
        observedMPS = GetObservedManaPerSecond()
    end
    local baselineMPS = GetBaselineCastingManaPS()
    local manaMPS = math.max(observedMPS, baselineMPS)
    local cd = GetCooldownStates()

    local allowGem = not opts.disableGem
    local allowEvo = not opts.disableEvo
    local allowPotion = not opts.disablePotion and cd.potionIsMana

    local gemRemain = cd.gemRemain
    local evoRemain = cd.evoRemain
    local potionRemain = cd.potionRemain
    local lowManaTrigger = ns.GetLowManaTriggerPct()

    while timeSpent < math.min(stopAtTime or CFG.simMaxTime, CFG.simMaxTime) do
        local spellKey = rotation[rotationIndex]
        local castTime = ns.GetEffectiveCastTime(spellKey)
        local spellCost = ns.GetSpellCost(spellKey, activeStacks)
        local manaPct = mana / maxMana

        if mana < spellCost then
            if allowGem and (not gemUsed) and gemRemain <= 0.05 and manaPct <= CFG.manaGemThreshold then
                mana = math.min(maxMana, mana + EstimateManaGemRestore(maxMana))
                gemUsed = true
            elseif allowPotion and (not potionUsed) and potionRemain <= 0.05 and manaPct <= lowManaTrigger then
                mana = math.min(maxMana, mana + EstimateManaGemRestore(maxMana))
                potionUsed = true
            elseif allowEvo and (not evoUsed) and evoRemain <= 0.05 and manaPct <= CFG.evocationThreshold then
                timeSpent = timeSpent + CFG.evocationChannel
                mana = math.min(maxMana, mana + (maxMana * CFG.evocationRestorePct))
                evoUsed = true
                activeStacks = 0
                rotationIndex = 1
            else
                return false, timeSpent
            end
        else
            mana = math.min(maxMana, mana - spellCost + (manaMPS * castTime))
            timeSpent = timeSpent + castTime
            gemRemain = gemRemain - castTime
            evoRemain = evoRemain - castTime
            potionRemain = potionRemain - castTime
            if spellKey == "AB" then
                activeStacks = math.min(activeStacks + 1, 3)
            else
                activeStacks = 0
            end
            rotationIndex = rotationIndex + 1
            if rotationIndex > #rotation then
                rotationIndex = 1
            end
        end
    end

    return true, timeSpent
end

local function GetTimeToLowMana(mode)
    local mana, maxMana = ns.UnitMana("player")
    if maxMana <= 0 then return nil end
    local lowMana = maxMana * ns.GetLowManaTriggerPct()
    if mana <= lowMana then return 0 end

    local activeStacks = state.abStacks or 0
    local timeSpent = 0
    local rotation = (mode == "BURN") and { "AB" } or BuildSustainRotation()
    local rotationIndex = 1
    local observedMPS = 0
    if UnitAffectingCombat("player") then
        observedMPS = GetObservedManaPerSecond()
    end
    local baselineMPS = GetBaselineCastingManaPS()
    local manaMPS = math.max(observedMPS, baselineMPS)

    while timeSpent < CFG.simMaxTime do
        local spellKey = rotation[rotationIndex]
        local castTime = ns.GetEffectiveCastTime(spellKey)
        local spellCost = ns.GetSpellCost(spellKey, activeStacks)
        mana = math.min(maxMana, mana - spellCost + (manaMPS * castTime))
        timeSpent = timeSpent + castTime
        if mana <= lowMana then
            return timeSpent
        end
        if spellKey == "AB" then
            activeStacks = math.min(activeStacks + 1, 3)
        else
            activeStacks = 0
        end
        rotationIndex = rotationIndex + 1
        if rotationIndex > #rotation then rotationIndex = 1 end
    end

    return CFG.simMaxTime
end

local function ShouldForceBurn()
    if not UnitAffectingCombat("player") then
        return false
    end

    local cd = GetCooldownStates()
    if cd.evoReady then
        return true
    end

    local timeToLowMana = GetTimeToLowMana("BURN")
    if not timeToLowMana then
        return false
    end

    if cd.gemReady or cd.gemRemain <= timeToLowMana then
        return true
    end

    if cd.potionIsMana and (cd.potionReady or cd.potionRemain <= timeToLowMana) then
        return true
    end

    return false
end

local function DetermineDisplayMode(etk)
    if ShouldForceBurn() then
        return "BURN"
    end

    if not etk or etk <= 0 then
        return "HOLD"
    end

    local burnCanKill = select(1, SimulateRotation("BURN", etk))
    local desired = burnCanKill and "BURN" or "SUSTAIN"

    if state.currentMode == desired then
        state.modeCandidate = nil
        state.modeCandidateSince = nil
        return desired
    end

    if state.modeCandidate ~= desired then
        state.modeCandidate = desired
        state.modeCandidateSince = ns.Now()
        return state.currentMode or "HOLD"
    end

    if (ns.Now() - (state.modeCandidateSince or 0)) >= CFG.burnHysteresisSeconds then
        state.currentMode = desired
        state.modeCandidate = nil
        state.modeCandidateSince = nil
        return desired
    end

    return state.currentMode or "HOLD"
end

function ns.RefreshDisplay()
    ns.DecayABStacksIfNeeded()

    if not ABH or not ABH.row1ETK or not ABH.row2AB then
        return
    end

    local hp = ns.GetTargetHealth()
    local etk = nil
    if hp then
        local dps = GetTargetDPS()
        if dps > 0 then
            etk = hp / dps
        end
    end

    local inCombat = UnitAffectingCombat("player") and state.targetGUID ~= nil
    local sustainOOM, burnOOM, sustainLow, burnLow = nil, nil, nil, nil
    if inCombat then
        sustainOOM = select(2, SimulateRotation("SUSTAIN"))
        burnOOM = select(2, SimulateRotation("BURN"))
        sustainLow = GetTimeToLowMana("SUSTAIN")
        burnLow = GetTimeToLowMana("BURN")
    end

    local mode = DetermineDisplayMode(etk)
    state.currentMode = mode
    local cd = GetCooldownStates()
    local lowLabel = ns.GetLowManaLabel() .. "%"
    local evoState = CooldownVisualState(cd.evoRemain, cd.evoReady, true)
    local gemState = CooldownVisualState(cd.gemRemain, cd.gemReady, cd.gemName ~= nil)
    local potionState = CooldownVisualState(cd.potionRemain, cd.potionReady, cd.potionName ~= nil)

    ABH.row1ETK:SetText("ETK: " .. ns.FormatSeconds(etk))
    ABH.row1Slow:SetText("S " .. lowLabel .. ": " .. ns.FormatSeconds(sustainLow))
    ABH.row1Blow:SetText("B " .. lowLabel .. ": " .. ns.FormatSeconds(burnLow))
    ABH.row1Soom:SetText("S OOM: " .. ns.FormatSeconds(sustainOOM))
    ABH.row1Boom:SetText("B OOM: " .. ns.FormatSeconds(burnOOM))
    ns.UpdateModeText(mode)

    ABH.row2AB:SetText("AB" .. tostring(state.abStacks or 0))
    ns.SetABTextColor(state.abStacks or 0)
    ABH.row2Armor:SetText("Armor: " .. ns.GetArmorLabel())
    ns.UpdateCooldownCue(evoState, gemState, potionState)
end

SLASH_ARCANEBURNHELPER1 = "/abh"
SlashCmdList["ARCANEBURNHELPER"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "lock" then
        ns.GetConfig().locked = true
        if ns.UpdateLockState then ns.UpdateLockState() end
        print("ArcaneBurnHelper: locked")
    elseif msg == "unlock" then
        ns.GetConfig().locked = false
        if ns.UpdateLockState then ns.UpdateLockState() end
        print("ArcaneBurnHelper: unlocked")
    elseif msg == "reset" then
        ArcaneBurnHelperDB.point = nil
        ABH:ClearAllPoints()
        ABH:SetPoint(unpack(CFG.defaultPoint))
        local cfg = ns.GetConfig()
        cfg.frameWidth = CFG.width
        cfg.frameHeight = CFG.height
        cfg.frameScale = 1.0
        ABH:SetSize(cfg.frameWidth, cfg.frameHeight)
        if ns.ApplyFrameScale then
            ns.ApplyFrameScale(cfg.frameScale, false)
        else
            ABH:SetScale(cfg.frameScale)
        end
        if ns.UpdateLockState then ns.UpdateLockState() end
        print("ArcaneBurnHelper: reset")
    elseif msg == "options" then
        ns.OpenOptions()
    else
        print("/abh lock | unlock | reset | options")
    end
end

ABH:RegisterEvent("ADDON_LOADED")
ABH:RegisterEvent("PLAYER_ENTERING_WORLD")
ABH:RegisterEvent("PLAYER_TARGET_CHANGED")
ABH:RegisterEvent("UNIT_POWER_UPDATE")
ABH:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
ABH:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ABH:RegisterEvent("PLAYER_REGEN_ENABLED")
ABH:RegisterEvent("PLAYER_REGEN_DISABLED")

ABH:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "ArcaneBurnHelper" then
            ns.CopyDefaults(CFG.defaults, ArcaneBurnHelperDB)
            ns.CreateOptionsPanel()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if ArcaneBurnHelperDB.point then
            local p = ArcaneBurnHelperDB.point
            self:ClearAllPoints()
            self:SetPoint(p[1], UIParent, p[3], p[4], p[5])
        end
        local cfg = ns.GetConfig()
        self:SetSize(cfg.frameWidth or CFG.width, cfg.frameHeight or CFG.height)
        if ns.ApplyFrameScale then
            ns.ApplyFrameScale(cfg.frameScale or 1.0, false)
        else
            self:SetScale(cfg.frameScale or 1.0)
        end
        if ns.UpdateLockState then ns.UpdateLockState() end

        local mana = ns.UnitMana("player")
        table.insert(state.manaLog, { t = ns.Now(), mana = mana })
        ns.RefreshDisplay()

    elseif event == "PLAYER_TARGET_CHANGED" then
        state.targetGUID = ns.TargetGUID()
        wipe(state.damageLog)
        state.targetFightStart = nil
        ns.RefreshDisplay()

    elseif event == "UNIT_POWER_UPDATE" then
        local unit = ...
        if unit == "player" then
            local mana = ns.UnitMana("player")
            table.insert(state.manaLog, { t = ns.Now(), mana = mana })
            ns.TrimLog(state.manaLog, CFG.manaWindow)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" then
            local nowTime = ns.Now()
            local spellName = spellID and GetSpellInfo(spellID)
            if spellID == CFG.spellIDArcaneBlast or spellName == CFG.spellArcaneBlast then
                local current = state.abStacks or 0
                ns.SetABStacks(math.min(current + 1, 3))
                state.lastABCastSuccessAt = nowTime
                if state.targetGUID and not state.targetFightStart then
                    state.targetFightStart = nowTime - ns.GetEffectiveCastTime("AB")
                end
            elseif spellName == CFG.spellFrostbolt then
                if state.targetGUID and not state.targetFightStart then
                    state.targetFightStart = nowTime - ns.GetEffectiveCastTime("FB")
                end
            end
            ns.RefreshDisplay()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(state.damageLog)
        state.targetFightStart = nil
        ns.RefreshDisplay()

    elseif event == "PLAYER_REGEN_DISABLED" then
        state.targetGUID = ns.TargetGUID()
        ns.RefreshDisplay()

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent,
              hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = CombatLogGetCurrentEventInfo()

        local currentTargetGUID = state.targetGUID or ns.TargetGUID()
        state.targetGUID = currentTargetGUID

        if currentTargetGUID and destGUID == currentTargetGUID then
            local amount = nil
            if subevent == "SWING_DAMAGE" then
                amount = arg12
            elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
                amount = arg15
                if type(amount) ~= "number" then
                    amount = arg12
                end
            end
            RecordDamage(amount)
            if type(amount) == "number" and amount > 0 and not state.targetFightStart then
                state.targetFightStart = ns.Now()
            end
        end
    end
end)

ABH:SetScript("OnUpdate", function(self, elapsed)
    state.lastUpdate = state.lastUpdate + elapsed
    if state.lastUpdate >= CFG.updateInterval then
        state.lastUpdate = 0
        ns.RefreshDisplay()
    end
end)
