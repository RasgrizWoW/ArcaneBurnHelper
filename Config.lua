local addonName, ns = ...
ns = ns or {}
_G.ArcaneBurnHelperNS = ns

ArcaneBurnHelperDB = ArcaneBurnHelperDB or {}

ns.CFG = {
    width = 270,
    height = 128,
    minScale = 0.70,
    maxScale = 2.50,
    defaultPoint = { "CENTER", UIParent, "CENTER", 0, 220 },
    updateInterval = 0.20,
    dpsWindow = 10.0,
    etkGraceSeconds = 3.0,
    manaWindow = 8.0,
    simMaxTime = 180.0,
    spellArcaneBlast = "Arcane Blast",
    spellFrostbolt = "Frostbolt",
    spellEvocation = "Evocation",
    spellIDArcaneBlast = 30451,
    auraMageArmor = "Mage Armor",
    auraMoltenArmor = "Molten Armor",
    talentArcaneMeditationTab = 1,
    talentArcaneMeditationIndex = 8,
    t5Multiplier = 1.20,
    evocationRestorePct = 0.60,
    evocationChannel = 8.0,
    manaGemRestorePct = 0.23,
    manaGemThreshold = 0.25,
    evocationThreshold = 0.10,
    lowManaTriggerPct = 0.20,
    burnHysteresisSeconds = 1.25,
    manaGemNames = {
        "Mana Emerald", "Mana Ruby", "Mana Citrine", "Mana Jade", "Mana Agate"
    },
    manaPotionNames = {
        "Super Mana Potion", "Fel Mana Potion", "Major Mana Potion"
    },
    destroPotionNames = {
        "Destruction Potion"
    },
    arcaneBlastManaCostByStack = { [0] = 195, [1] = 341, [2] = 488, [3] = 634 },
    baseCastTimes = { AB = 2.5, FB = 3.0 },
    defaults = {
        locked = false,
        sustainAB = 2,
        sustainFB = 3,
        armorType = "MOLTEN",
        t5_2pc = false,
        potionType = "DESTRO",
        lowManaPercent = 20,
        readySoonSeconds = 15,
        frameWidth = 270,
        frameHeight = 128,
        frameScale = 1.0,
    },
}

ns.state = {
    targetGUID = nil,
    damageLog = {},
    manaLog = {},
    abStacks = 0,
    lastABCastSuccessAt = nil,
    lastUpdate = 0,
    currentMode = "HOLD",
    modeCandidate = nil,
    modeCandidateSince = nil,
    targetFightStart = nil,
    cachedManaGemName = nil,
    cachedManaGemAt = 0,
    cachedManaPotionName = nil,
    cachedManaPotionAt = 0,
    cachedDestroPotionName = nil,
    cachedDestroPotionAt = 0,
}

function ns.CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            ns.CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.GetConfig()
    ns.CopyDefaults(ns.CFG.defaults, ArcaneBurnHelperDB)
    return ArcaneBurnHelperDB
end

function ns.Now()
    return GetTime()
end

function ns.Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

function ns.FormatSeconds(v)
    if not v or v <= 0 then return "--" end
    if v >= 100 then return string.format("%.0f", v) end
    return string.format("%.1f", v)
end

function ns.IsModernSettings()
    return Settings and Settings.RegisterCanvasLayoutCategory and Settings.OpenToCategory
end

function ns.UnitMana(unit)
    return UnitPower(unit, 0) or 0, UnitPowerMax(unit, 0) or 1
end

function ns.TargetGUID()
    if UnitExists("target") and UnitCanAttack("player", "target") then
        return UnitGUID("target")
    end
    return nil
end

function ns.GetTargetHealth()
    if not UnitExists("target") or UnitIsDead("target") then return nil end
    local hp = UnitHealth("target")
    local hpMax = UnitHealthMax("target")
    if not hp or hp <= 0 or not hpMax or hpMax <= 0 then return nil end
    return hp, hpMax
end

function ns.TrimLog(log, cutoff)
    local t = ns.Now()
    while #log > 0 and (t - log[1].t) > cutoff do
        table.remove(log, 1)
    end
end

function ns.GetSpellCooldownRemaining(spell)
    local start, duration, enabled = GetSpellCooldown(spell)
    if not start or not duration or enabled == 0 then return 0 end
    local remain = (start + duration) - ns.Now()
    if remain < 0 then remain = 0 end
    return remain
end

function ns.IsSpellReady(spell)
    return ns.GetSpellCooldownRemaining(spell) <= 0.05
end

function ns.SafeGetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag)
    end
    return 0
end

function ns.SafeGetContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
    return nil
end

function ns.SafeGetContainerItemCooldown(bag, slot)
    if C_Container and C_Container.GetContainerItemCooldown then
        return C_Container.GetContainerItemCooldown(bag, slot)
    end
    if GetContainerItemCooldown then
        return GetContainerItemCooldown(bag, slot)
    end
    return nil, nil, 0
end

local function FindItemByNames(names, cacheNameKey, cacheTimeKey)
    local now = ns.Now()
    if ns.state[cacheTimeKey] and (now - ns.state[cacheTimeKey]) < 2.0 then
        return ns.state[cacheNameKey]
    end

    local found = nil
    for bag = 0, 4 do
        local slots = ns.SafeGetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = ns.SafeGetContainerItemLink(bag, slot)
            if link then
                local itemName = GetItemInfo(link)
                if itemName then
                    for _, desired in ipairs(names) do
                        if itemName == desired then
                            found = desired
                            break
                        end
                    end
                end
            end
            if found then break end
        end
        if found then break end
    end

    ns.state[cacheNameKey] = found
    ns.state[cacheTimeKey] = now
    return found
end

function ns.FindManaGemName()
    return FindItemByNames(ns.CFG.manaGemNames, "cachedManaGemName", "cachedManaGemAt")
end

function ns.FindManaPotionName()
    return FindItemByNames(ns.CFG.manaPotionNames, "cachedManaPotionName", "cachedManaPotionAt")
end

function ns.FindDestroPotionName()
    return FindItemByNames(ns.CFG.destroPotionNames, "cachedDestroPotionName", "cachedDestroPotionAt")
end

function ns.GetItemCooldownRemaining(itemName)
    if not itemName then return math.huge end

    for bag = 0, 4 do
        local slots = ns.SafeGetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = ns.SafeGetContainerItemLink(bag, slot)
            if link then
                local foundName = GetItemInfo(link)
                if foundName == itemName then
                    local start, duration, enabled = ns.SafeGetContainerItemCooldown(bag, slot)
                    if not start or not duration or enabled == 0 then
                        return 0
                    end
                    local remain = (start + duration) - ns.Now()
                    if remain < 0 then remain = 0 end
                    return remain
                end
            end
        end
    end

    return math.huge
end

function ns.IsItemReady(itemName)
    return ns.GetItemCooldownRemaining(itemName) <= 0.05
end

function ns.GetPotionTypeLabel()
    local cfg = ns.GetConfig()
    return cfg.potionType == "MANA" and "Mana" or "Destro"
end

function ns.GetArmorLabel()
    local cfg = ns.GetConfig()
    return cfg.armorType == "MAGE" and "Mage" or "Molten"
end

function ns.GetLowManaTriggerPct()
    local cfg = ns.GetConfig()
    local pct = tonumber(cfg.lowManaPercent) or (ns.CFG.lowManaTriggerPct * 100)
    pct = ns.Clamp(pct, 5, 50)
    return pct / 100
end

function ns.GetLowManaLabel()
    return tostring(math.floor((ns.GetLowManaTriggerPct() * 100) + 0.5))
end


function ns.GetReadySoonSeconds()
    local cfg = ns.GetConfig()
    local v = tonumber(cfg.readySoonSeconds) or 15
    return ns.Clamp(v, 0, 30)
end

function ns.GetArcaneMeditationFraction()
    local _, _, _, _, rank = GetTalentInfo(ns.CFG.talentArcaneMeditationTab, ns.CFG.talentArcaneMeditationIndex)
    rank = rank or 0
    return rank * 0.10
end

function ns.GetMageArmorFraction()
    local cfg = ns.GetConfig()
    if cfg.armorType == "MAGE" then
        return 0.30
    end
    return 0.00
end

function ns.GetWhileCastingSpiritFraction()
    return ns.GetArcaneMeditationFraction() + ns.GetMageArmorFraction()
end

function ns.GetSpellHasteMultiplier()
    if UnitSpellHaste then
        return 1 + ((UnitSpellHaste("player") or 0) / 100)
    end
    return 1.0
end

function ns.GetEffectiveCastTime(spellKey)
    local base = ns.CFG.baseCastTimes[spellKey] or 2.5
    return base / ns.GetSpellHasteMultiplier()
end

function ns.GetABCostForActiveStacks(activeStacks)
    local cost = ns.CFG.arcaneBlastManaCostByStack[ns.Clamp(activeStacks or 0, 0, 3)] or 195
    if ns.GetConfig().t5_2pc then
        cost = cost * ns.CFG.t5Multiplier
    end
    return cost
end

function ns.GetSpellCost(spellKey, activeABStacks)
    if spellKey == "AB" then
        return ns.GetABCostForActiveStacks(activeABStacks)
    end
    if spellKey == "FB" then
        return 330
    end
    return 0
end

function ns.SetABStacks(v)
    ns.state.abStacks = ns.Clamp(v or 0, 0, 3)
end

function ns.DecayABStacksIfNeeded()
    local last = ns.state.lastABCastSuccessAt
    if last and (ns.Now() - last) >= 8.0 then
        ns.SetABStacks(0)
        ns.state.lastABCastSuccessAt = nil
    end
end
