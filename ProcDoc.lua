-- ProcDoc.lua

-- Local tuning defaults (prevents nil-compare crash if OnUpdate fires before VARIABLES_LOADED
-- and avoids polluting the global namespace with generic names).
local minAlpha       = 0.8
local maxAlpha       = 1.0
local minScale       = 0.9
local maxScale       = 1.0
local alphaStep      = 0.01
local pulseSpeed     = 0.4
local topOffset      = 70
local sideOffset     = 60
local timerTextAlpha = 0.85

-- 1) SavedVariables initialization
--    Creates a frame to initialize persistent settings on VARIABLES_LOADED.
local initFrame = CreateFrame("Frame", "ProcDocDBInitFrame", UIParent)
initFrame:RegisterEvent("VARIABLES_LOADED")

initFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not ProcDocDB then ProcDocDB = {} end
        if not ProcDocDB.globalVars then ProcDocDB.globalVars = {} end
        if not ProcDocDB.procsEnabled then ProcDocDB.procsEnabled = {} end
        if not ProcDocDB.actionProcDurations then ProcDocDB.actionProcDurations = {} end
        if not ProcDocDB.customProcs then ProcDocDB.customProcs = {} end

        local gv = ProcDocDB.globalVars
        -- Migrate legacy fields first, otherwise the default below hides the old value
        if gv.maxSize and gv.maxScale == nil then gv.maxScale = gv.maxSize; gv.maxSize = nil end
        -- Only set defaults if not present
        if gv.minAlpha == nil then gv.minAlpha = 0.8 end
        if gv.maxAlpha == nil then gv.maxAlpha = 1.0 end
        if gv.minScale == nil then gv.minScale = 0.9 end
        if gv.maxScale == nil then gv.maxScale = 1.0 end  -- new default (old default was 1.25)
        if gv.alphaStep == nil then gv.alphaStep = 0.01 end
        if gv.pulseSpeed == nil then gv.pulseSpeed = 0.4 end
        if gv.topOffset == nil then gv.topOffset = 70 end
        if gv.sideOffset == nil then gv.sideOffset = 60 end
        if gv.timerTextAlpha == nil then gv.timerTextAlpha = 0.85 end
        if gv.isMuted == nil then gv.isMuted = false end
        if gv.soundVolume == nil then gv.soundVolume = 1.0 end
        if gv.disableTimers == nil then gv.disableTimers = false end
        if gv.auraSource == nil then gv.auraSource = "auto" end            -- "auto" | "nampower" | "aura" | "tooltip"
        if gv.pulseReferenceFps == nil then gv.pulseReferenceFps = 60 end  -- pulse speed is calibrated to this frame rate
        if gv.dimOnLowResource == nil then gv.dimOnLowResource = true end  -- dim action procs when OOM/low rage/energy or wrong stance
        if gv.decimalTimers == nil then gv.decimalTimers = true end        -- show 0.1s decimals when remaining < 5s
        if gv.combatOnly == nil then gv.combatOnly = false end             -- only show live proc alerts while in combat


        minAlpha      = gv.minAlpha
        maxAlpha      = gv.maxAlpha
        minScale      = gv.minScale
        maxScale      = gv.maxScale
        alphaStep     = gv.alphaStep
        pulseSpeed    = gv.pulseSpeed
        topOffset     = gv.topOffset
        sideOffset    = gv.sideOffset
        timerTextAlpha= gv.timerTextAlpha

        initFrame:UnregisterEvent("VARIABLES_LOADED")
    end
end)

-- Debug helper to print current DB values
local function ProcDoc_DumpDB()
    if not ProcDocDB or not ProcDocDB.globalVars then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ProcDoc|r: DB not initialized yet.")
        return
    end
    local gv = ProcDocDB.globalVars
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ProcDoc DB Dump|r")
    DEFAULT_CHAT_FRAME:AddMessage("  minAlpha="..tostring(gv.minAlpha)
        .." maxAlpha="..tostring(gv.maxAlpha)
        .." minScale="..tostring(gv.minScale)
        .." maxScale="..tostring(gv.maxScale)
        .." pulseSpeed="..tostring(gv.pulseSpeed))
    DEFAULT_CHAT_FRAME:AddMessage("  topOffset="..tostring(gv.topOffset).." sideOffset="..tostring(gv.sideOffset)
        .." isMuted="..tostring(gv.isMuted)
        .." disableTimers="..tostring(gv.disableTimers))
end
    
-- 2) Main addon frame
local addonName = "ProcDoc"
local ProcDoc   = CreateFrame("Frame", "ProcDocAlertFrame", UIParent)

-- 3) Proc data tables
local PROC_DATA = {
    ["WARLOCK"] = {
        {
            buffName         = "Shadow Trance",
            texture          = "Interface\\Icons\\Spell_Shadow_Twilight",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\WarlockShadowTrance.tga",
            alertStyle       = "SIDES",
        },
    },
    ["MAGE"] = {
        {
            buffName         = "Clearcasting",
            texture          = "Interface\\Icons\\Spell_Shadow_ManaBurn",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidClearcasting.tga",
            alertStyle       = "TOP",
        },
        {
            buffName         = "Netherwind Focus",
            texture          = "Interface\\Icons\\Spell_Shadow_Teleport",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\MageT2.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Temporal Convergence",
            texture          = "Interface\\Icons\\Spell_Nature_StormReach",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\MageTemporalConvergence.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Flash Freeze",
            texture          = "Interface\\Icons\\Spell_Fire_FrostResistanceTotem",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\MageFlashFreeze.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Arcane Rupture",
            texture          = "Interface\\Icons\\Spell_Arcane_Blast",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\MageArcaneRupture.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Hot Streak",
            texture          = "Interface\\Icons\\Ability_Mage_Firestarter",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\WarriorRevenge.tga", -- sample texture for test button preview
            alertStyle       = "LEFT", -- preview only; live logic spawns LEFT/RIGHT/TOP2 as tiers advance
        },
    },
    ["DRUID"] = {
        {
            buffName         = "Clearcasting",
            texture          = "Interface\\Icons\\Spell_Shadow_ManaBurn",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidClearcasting.tga",
            alertStyle       = "TOP",
        },
        {
            buffName         = "Nature's Grace",
            texture          = "Interface\\Icons\\Spell_Nature_NaturesBlessing",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidNaturesGrace.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Tiger's Fury",
            texture          = "Interface\\Icons\\Ability_Mount_JungleTiger",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\HunterMongooseBite.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Astral Boon",
            texture          = "Interface\\Icons\\Spell_Arcane_StarFire",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidAstralBoon.tga",
            alertStyle       = "TOP2",
        },
        {
            buffName         = "Natural Boon",
            texture          = "Interface\\Icons\\Spell_Nature_AbolishMagic",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidNaturalBoon.tga",
            alertStyle       = "TOP2",
        },
        {
            buffName         = "Arcane Eclipse",
            texture          = "Interface\\Icons\\Spell_Nature_WispSplode",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidArcaneEclipse.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Nature Eclipse",
            texture          = "Interface\\Icons\\Spell_Nature_AbolishMagic",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidNatureEclipse.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Owlkin Frenzy",
            texture          = "Interface\\Icons\\Ability_Druid_OwlkinFrenzy",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidArcaneEclipse.tga",
            alertStyle       = "SIDES",
        },
    },
    ["SHAMAN"] = {
        {
            buffName         = "Clearcasting",
            texture          = "Interface\\Icons\\Spell_Shadow_ManaBurn",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidClearcasting.tga",
            alertStyle       = "TOP",
        },
        {
            buffName         = "Ancestral Swiftness",
            texture          = "Interface\\Icons\\Spell_Nature_RavenForm",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidNaturesGrace.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Stormstrike",
            texture          = "Interface\\Icons\\Ability_Shaman_StormStrike",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\ShamanStormstrike.tga",
            alertStyle       = "TOP2",
        },
        {
            buffName         = "Flurry",
            texture          = "Interface\\Icons\\Ability_GhoulFrenzy",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\HunterMongooseBite.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Elemental Devastation",
            texture          = "Interface\\Icons\\Spell_Fire_ElementalDevastation",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\ShamanStormstrike.tga",
            alertStyle       = "SIDES",
        },
    },
    ["HUNTER"] = {
        {
            buffName         = "Quick Shots",
            texture          = "Interface\\Icons\\Ability_Warrior_InnerRage",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\HunterQuickShots.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Scent of Blood",
            texture          = "Interface\\Icons\\Ability_Hunter_GoForTheThroat",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\HunterQuickShots.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Lock and Load",
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\Lock_and_Load.blp",
            alertStyle       = "TOP2",
        },
        {
            buffName         = "Explosive Ammunition",
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\impact.blp",
            alertStyle       = "TOP",
        },
        {
            buffName         = "Poisonous Ammunition",
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\DruidNaturesGrace.tga",
            alertStyle       = "TOP_ROTATED",
        },
        {
            buffName         = "Enchanted Ammunition",
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\serendipity.blp",
            alertStyle       = "TOP",
        },
    },
    ["WARRIOR"] = {
        {
            buffName         = "Enrage",
            texture          = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\WarriorEnrage.tga",
            alertStyle       = "SIDES",
        },
        {
            -- Turtle WoW Protection/Revenge synergy buff (#45962, +150% Revenge damage for 5s)
            buffName         = "Riposte",
            texture          = "Interface\\Icons\\Ability_Warrior_Riposte",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\WarriorRevenge.tga",
            alertStyle       = "SIDES2",
        },
    },
    ["PRIEST"] = {
        {
            buffName         = "Resurgence",
            texture          = "Interface\\Icons\\Spell_Holy_MindVision",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PriestResurgence.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Enlightened",
            texture          = "Interface\\Icons\\Spell_Holy_PowerInfusion",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PriestEnlightened.tga",
            alertStyle       = "TOP",
        },
        {
            buffName         = "Searing Light",
            texture          = "Interface\\Icons\\Spell_Holy_SearingLightPriest",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PriestSearingLight.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Shadow Veil",
            texture          = "Interface\\Icons\\Spell_Shadow_GatherShadows",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PriestShadowVeil.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Spell Blasting",
            texture          = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PriestSpellBlasting.tga",
            alertStyle       = "TOP2",
        },
        {
            buffName         = "Resurgent Shield",
            texture          = "Interface\\Icons\\Spell_Holy_BlessingOfProtection",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PriestEnlightened.tga",
            alertStyle       = "TOP2",
        },
    },
    ["PALADIN"] = {
        {
            buffName         = "Daybreak",
            texture          = "Interface\\Icons\\Spell_Holy_AuraMastery",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PaladinDaybreak.tga",
            alertStyle       = "TOP",
        },
        {
            -- Triggered by Crusader Strike. Reduces damage of the next blocked attack.
            -- Lasts 10 seconds. (Turtle WoW spell #51336-#51340)
            buffName         = "Zealous Defense",
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\Grand_Crusader.tga",
            alertStyle       = "SIDES2",
        },
        {
            buffName         = "Holy Judgement",
            texture          = "Interface\\Icons\\Ability_Paladin_JudgementBlue",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PaladinJudgement.tga",
            alertStyle       = "TOP2",
        },
        {
            buffName         = "Holy Might",
            texture          = "Interface\\Icons\\Spell_Holy_HolyNova",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PaladinDaybreak.tga",
            alertStyle       = "SIDES",
        },
    },
    ["ROGUE"] = {
        {
            buffName         = "Remorseless",
            texture          = "Interface\\Icons\\Ability_FiegnDead",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\RogueRemorseless.tga",
            alertStyle       = "SIDES",
        },
        {
            buffName         = "Tricks of the Trade",
            texture          = "Interface\\Icons\\INV_Misc_Key_03",
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\RogueTricksoftheTrade.tga",
            alertStyle       = "TOP",
        },
    },
}

local ACTION_PROCS = {
    ["ROGUE"] = {
        {
            buffName        = "Riposte",  
            texture         = "Interface\\Icons\\Ability_Warrior_Challange",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\RogueRiposte.tga",
            alertStyle      = "SIDES",
            spellName       = "Riposte"
        },
        {
            buffName        = "Surprise Attack",  
            texture         = "Interface\\Icons\\Ability_Rogue_SurpriseAttack",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\RogueSuddenDeath.tga",
            alertStyle      = "SIDES2",
            spellName       = "Surprise Attack"
        },
    },
    ["WARRIOR"] = {
        {
            buffName        = "Overpower", 
            texture         = "Interface\\Icons\\Ability_MeleeDamage",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\WarriorOverpower.tga",
            alertStyle      = "TOP",
            spellName       = "Overpower"
        },
        {
            buffName        = "Execute", 
            texture         = "Interface\\Icons\\inv_sword_48",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\WarriorExecute.tga",
            alertStyle      = "TOP2",
            spellName       = "Execute"
        },
        {
            buffName        = "Counterattack",
            texture         = "Interface\\Icons\\Ability_Warrior_Riposte",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\WarriorCounterattack.tga",
            alertStyle      = "LEFT",
            spellName       = "Counterattack"
        },
        {
            buffName       = "Revenge",
            texture         = "Interface\\Icons\\Ability_Warrior_Revenge",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\WarriorRevenge.tga",
            alertStyle      = "RIGHT",
            spellName       = "Revenge"
        }
    },
    ["MAGE"] = {
        {
            buffName        = "Arcane Surge", 
            texture         = "Interface\\Icons\\INV_Enchant_EssenceMysticalLarge",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\MageArcaneSurge.tga",
            alertStyle      = "TOP2",
            spellName       = "Arcane Surge"
        },
    },
    ["HUNTER"] = {
        {
            buffName        = "Lacerate",
            texture         = "Interface\\Icons\\Spell_Lacerate_1c",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\HunterMongooseBite.tga",
            alertStyle      = "SIDES",
            spellName       = "Lacerate"
        },
        -- Kill Command behaves inconsistently: IsUsableAction returns 1 if it has been triggered, independently if it is on CD or not.
        -- I decided to create an alternative method to check if it is in CD using the spellbook
        -- If this server-side issue is fixed, this can be easily reverted
        {
            buffName        = "Kill Command",
            texture         = "Interface\\Icons\\ability_hunter_killcommand",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\HunterBaitedShot.tga",
            alertStyle      = "TOP",
            spellName       = "Kill Command",
            useSpellbookForCooldown     = true,
        }
    },
    ["PALADIN"] = {
        {
            buffName        = "Hammer of Wrath", 
            texture         = "Interface\\Icons\\Ability_Thunderclap",
            alertTexturePath= "Interface\\AddOns\\ProcDoc\\img\\PaladinHammer.tga",
            alertStyle      = "SIDES",
            spellName       = "Hammer of Wrath"
        },
        -- New: Spellbook-based cooldown procs (no action bar slot required)
        {
            buffName         = "Judgement",
            -- No action button texture lookup (use spellbook cooldown), so leave texture empty
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PaladinJudgement.tga",
            alertStyle       = "RIGHT",
            spellName        = "Judgement",
            useSpellbook     = true,
        },
        {
            buffName         = "Hammer of Justice",
            texture          = nil,
            alertTexturePath = "Interface\\AddOns\\ProcDoc\\img\\PaladinJustice.tga",
            alertStyle       = "LEFT",
            spellName        = "Hammer of Justice",
            useSpellbook     = true,
        },    

    },
}
local DEFAULT_ALERT_TEXTURE = "Interface\\AddOns\\ProcDoc\\img\\DruidClearcasting.tga"

-- Optional fixed durations (seconds) for action-based proc windows.
-- These emulate a timeout so the alert auto-clears even if the action remains usable.
local ACTION_PROC_DEFAULT_DURATIONS = {
    ["Overpower"]       = 5,  
    ["Riposte"]         = 5,  
    ["Counterattack"]   = 5,  
    ["Revenge"]         = 5,  
    ["Surprise Attack"] = 5,  
    ["Arcane Surge"]    = 4,
    ["Lacerate"]        = 4,
    ["Kill Command"]    = 4,
}

-- Hot Streak (Turtle WoW custom, stack-based visual) constants (Vanilla 1.12 compatible logic)
local HOT_STREAK_BUFF_NAME = "Hot Streak"
-- Re-use existing textures in the addon: WarriorEnrage for side build-up, MageArcaneRupture for final top burst.
local HOT_STREAK_SIDE_TEXTURE = "Interface\\AddOns\\ProcDoc\\img\\WarriorRevenge.tga"
local HOT_STREAK_TOP_TEXTURE  = "Interface\\AddOns\\ProcDoc\\img\\MageHotStreak.tga"
local hotStreakLastTier = 0  -- 0,3,4,5 (we only care about tiers 3/4/5)


-- Ensure DB tables exist and load saved globals
local function ProcDoc_EnsureDB()
    if not ProcDocDB then ProcDocDB = {} end
    if not ProcDocDB.globalVars then ProcDocDB.globalVars = {} end
    if not ProcDocDB.procsEnabled then ProcDocDB.procsEnabled = {} end
    if not ProcDocDB.actionProcDurations then ProcDocDB.actionProcDurations = {} end
    if not ProcDocDB.customProcs then ProcDocDB.customProcs = {} end
end

local function ProcDoc_LoadGlobalsFromDB()
    ProcDoc_EnsureDB()
    local gv = ProcDocDB.globalVars
    -- Migrate any legacy fields
    if gv.maxSize and not gv.maxScale then gv.maxScale = gv.maxSize; gv.maxSize = nil end

    if gv.minAlpha   ~= nil then minAlpha   = gv.minAlpha   end
    if gv.maxAlpha   ~= nil then maxAlpha   = gv.maxAlpha   end
    if gv.minScale   ~= nil then minScale   = gv.minScale   end
    if gv.maxScale   ~= nil then maxScale   = gv.maxScale   end
    if gv.pulseSpeed ~= nil then pulseSpeed = gv.pulseSpeed end
    if gv.topOffset  ~= nil then topOffset  = gv.topOffset  end
    if gv.sideOffset ~= nil then sideOffset = gv.sideOffset end
end

local function GetActionProcDuration(spellName)
    if not spellName then return nil end
    local overrides = ProcDocDB.actionProcDurations
    if overrides and overrides[spellName] and overrides[spellName] > 0 then
        return overrides[spellName]
    end
    return ACTION_PROC_DEFAULT_DURATIONS[spellName]
end

-- 4) Alert frame pool

local alertFrames = {}

local function CreateAlertFrame(style)
    local alertObj = {}
    alertObj.isActive      = false
    alertObj.isActionBased = false
    alertObj.isTest        = false
    alertObj.isDimmed      = false
    alertObj._appliedDim   = nil
    alertObj.style         = style
    alertObj.textures      = {}
    -- Timer related fields
    alertObj.sliceGroups   = {}   -- (legacy; unused after reverting wipe)
    alertObj.timerTexts    = {}   -- per base texture index -> fontstring
    alertObj.hasTimer      = false
    alertObj.procStartTime = nil
    alertObj.procDuration  = nil
    alertObj.zeroShown     = false
    alertObj.pulseAlpha    = minAlpha
    alertObj.pulseDir      = alphaStep

    -- Decide frame size and positions based on style
    if style == "TOP" or style == "TOP2" or style == "TOP_ROTATED" then
        alertObj.baseWidth  = 256
        alertObj.baseHeight = 128

        local tex = ProcDoc:CreateTexture(nil, "OVERLAY")
        local offsetY = (style == "TOP2") and (topOffset + 50) or topOffset
        tex:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
        tex:SetWidth(alertObj.baseWidth)
        tex:SetHeight(alertObj.baseHeight)
        tex:SetAlpha(0)
        if style == "TOP_ROTATED" then
            tex:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
        end
        tex:Hide()
        table.insert(alertObj.textures, tex)
    elseif style == "SIDES" or style == "SIDES2" then
        alertObj.baseWidth  = 128
        alertObj.baseHeight = 256

        local left = ProcDoc:CreateTexture(nil, "OVERLAY")
        local right = ProcDoc:CreateTexture(nil, "OVERLAY")

        local offsetX = (style == "SIDES2") and (sideOffset + 50) or sideOffset
        left:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)
        right:SetPoint("CENTER", UIParent, "CENTER", offsetX, topOffset - 150)

        left:SetWidth(alertObj.baseWidth)
        left:SetHeight(alertObj.baseHeight)
        left:SetAlpha(0)
        left:Hide()

        right:SetWidth(alertObj.baseWidth)
        right:SetHeight(alertObj.baseHeight)
        right:SetTexCoord(1, 0, 0, 1)
        right:SetAlpha(0)
        right:Hide()

        table.insert(alertObj.textures, left)
        table.insert(alertObj.textures, right)
    elseif style == "LEFT" then
        -- Single left-side vertical texture (same positioning as the LEFT half of SIDES2, no mirrored partner)
        alertObj.baseWidth  = 128
        alertObj.baseHeight = 256

        local tex = ProcDoc:CreateTexture(nil, "OVERLAY")
        local offsetX = sideOffset + 50 -- mimic SIDES2 left offset spacing
        tex:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)
        tex:SetWidth(alertObj.baseWidth)
        tex:SetHeight(alertObj.baseHeight)
        tex:SetAlpha(0)
        tex:Hide()
        table.insert(alertObj.textures, tex)
    elseif style == "RIGHT" then
        -- Single right-side vertical texture (same positioning as the RIGHT half of SIDES2, mirrored)
        alertObj.baseWidth  = 128
        alertObj.baseHeight = 256

        local tex = ProcDoc:CreateTexture(nil, "OVERLAY")
        local offsetX = sideOffset + 50 -- mimic SIDES2 right offset spacing
        tex:SetPoint("CENTER", UIParent, "CENTER", offsetX, topOffset - 150)
        tex:SetWidth(alertObj.baseWidth)
        tex:SetHeight(alertObj.baseHeight)
        tex:SetTexCoord(1, 0, 0, 1) -- mirror horizontally
        tex:SetAlpha(0)
        tex:Hide()
        table.insert(alertObj.textures, tex)
    end

    return alertObj
end


-- Acquire a frame for buff-based, action-based, or test preview usage
local function AcquireAlertFrame(style, isActionBased, isTest)
    local wantTest = isTest and true or false
    for _, alertObj in ipairs(alertFrames) do
        if (not alertObj.isActive)
           and (alertObj.style == style)
           and (alertObj.isActionBased == isActionBased)
           and ((alertObj.isTest and true or false) == wantTest)
        then
            return alertObj
        end
    end
    local newAlert = CreateAlertFrame(style)
    newAlert.isActionBased = isActionBased
    newAlert.isTest        = wantTest
    table.insert(alertFrames, newAlert)
    return newAlert
end

-- Re-anchor an alert object's textures according to its style and current saved offsets
local function ProcDoc_ReanchorAlert(alertObj)
    if not alertObj or not alertObj.textures then return end
    local style = alertObj.style
    if style == "TOP" or style == "TOP2" or style == "TOP_ROTATED" then
        local tex = alertObj.textures[1]
        if tex then
            tex:ClearAllPoints()
            local offsetY = (style == "TOP2") and (topOffset + 50) or topOffset
            tex:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
        end
    elseif style == "SIDES" or style == "SIDES2" then
        local left  = alertObj.textures[1]
        local right = alertObj.textures[2]
        local offsetX = (style == "SIDES2") and (sideOffset + 50) or sideOffset
        if left then
            left:ClearAllPoints()
            left:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)
        end
        if right then
            right:ClearAllPoints()
            right:SetPoint("CENTER", UIParent, "CENTER",  offsetX, topOffset - 150)
        end
    elseif style == "LEFT" then
        local tex = alertObj.textures[1]
        if tex then
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", UIParent, "CENTER", -(sideOffset + 50), topOffset - 150)
        end
    elseif style == "RIGHT" then
        local tex = alertObj.textures[1]
        if tex then
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", UIParent, "CENTER",  (sideOffset + 50), topOffset - 150)
        end
    end
end

--------------------------------------------
-- HELPER: Play proc sound with user volume
--   Buff procs   -> SpellAlert.ogg
--   Action procs -> SpellAlert2.ogg
--------------------------------------------
local BUFF_ALERT_SOUND   = "Interface\\AddOns\\ProcDoc\\img\\SpellAlert.ogg"
local ACTION_ALERT_SOUND = "Interface\\AddOns\\ProcDoc\\img\\SpellAlert2.ogg"

local procDocTrace = false
local function ProcDoc_Trace(msg)
    if procDocTrace then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[ProcDoc trace]|r " .. tostring(msg))
    end
end

local function ProcDoc_PlayAlertSound(isActionBased)
    if ProcDocDB.globalVars.isMuted then
        return
    end

    local desiredVolume = ProcDocDB.globalVars.soundVolume or 1.0
    if desiredVolume < 0 then desiredVolume = 0 end
    if desiredVolume > 1 then desiredVolume = 1 end

    local oldVolume = GetCVar("SoundVolume")
    local changedVolume = false
    if oldVolume ~= nil and tonumber(oldVolume) ~= desiredVolume then
        SetCVar("SoundVolume", tostring(desiredVolume))
        changedVolume = true
    end

    PlaySoundFile(isActionBased and ACTION_ALERT_SOUND or BUFF_ALERT_SOUND, "SFX")

    -- Immediately restore
    if changedVolume then
        SetCVar("SoundVolume", oldVolume)
    end
end


-- 5) OnUpdate pulse logic (handles alpha/scale pulsing and optional timer text)
-- NOTE: Frequent use of the live GameTooltip for buff scanning will instantly hide
-- any tooltip the player is viewing (items, NPCs, etc.). To avoid this we create
-- our own hidden tooltip and never call GameTooltip:Hide() during scans.
if not ProcDocScanTooltip then
    ProcDocScanTooltip = CreateFrame("GameTooltip","ProcDocScanTooltip",UIParent,"GameTooltipTemplate")
    ProcDocScanTooltip:Hide()
end

-- ---------------------------------------------------------------------------
-- Player buff reader
--   "nampower": Nampower's GetPlayerAuraDuration + BUFF_* / AURA_CAST_ON_SELF (buffcap-safe, 0 tooltips).
--   "aura":     ClassicAPI's C_UnitAuras.UnitAura, no tooltips; used automatically when present.
--   "tooltip":  the original method (stock 1.12 API + hidden tooltip), always available.
-- All return the same list of { tex, name, stack, api, tl } records.
-- ---------------------------------------------------------------------------
local procDocAuraFailed     = false
local procDocNampowerFailed = false
local procDocNampowerReady  = false

local npSpellMetaCache = {}   -- spellId -> { name = string, tex = string }
local npSlotStacks     = {}   -- raw 0..31 auraSlot -> stackCount (updated by BUFF_ADDED_SELF / BUFF_REMOVED_SELF)
local npCapBuffs       = {}   -- spellId -> { expire = number, stacks = number } (buffcap overflow via AURA_CAST_ON_SELF)

local function ProcDoc_NampowerPresent()
    return (type(GetNampowerVersion) == "function")
end

local function ProcDoc_NampowerBuffApiPresent()
    return ProcDoc_NampowerPresent()
        and (type(GetPlayerAuraDuration) == "function")
        and (type(GetSpellRecField) == "function")
        and (type(GetSpellIconTexture) == "function")
end

local function ProcDoc_AuraApiPresent()
    return (type(C_UnitAuras) == "table") and (type(C_UnitAuras.UnitAura) == "function")
end

local function ProcDoc_UsingNampowerApi()
    local gv = ProcDocDB and ProcDocDB.globalVars
    if gv and (gv.auraSource == "tooltip" or gv.auraSource == "aura") then return false end
    return ProcDoc_NampowerBuffApiPresent() and (not procDocNampowerFailed)
end

local function ProcDoc_UsingAuraApi()
    local gv = ProcDocDB and ProcDocDB.globalVars
    if gv and (gv.auraSource == "tooltip" or gv.auraSource == "nampower") then return false end
    if ProcDoc_UsingNampowerApi() then return false end
    return ProcDoc_AuraApiPresent() and (not procDocAuraFailed)
end

local function ProcDoc_GetNampowerSpellMeta(spellId)
    if not spellId or spellId <= 0 then return nil end
    local meta = npSpellMetaCache[spellId]
    if meta ~= nil then
        return meta or nil
    end
    local name = GetSpellRecField(spellId, "name")
    if not name or name == "" then
        npSpellMetaCache[spellId] = false
        return nil
    end
    local iconId = GetSpellRecField(spellId, "spellIconID")
    local tex = (iconId and GetSpellIconTexture(iconId)) or ""
    meta = { name = name, tex = tex }
    npSpellMetaCache[spellId] = meta
    return meta
end

local function ProcDoc_EnableNampowerCVars()
    if procDocNampowerReady or (not ProcDoc_NampowerPresent()) then return end
    procDocNampowerReady = true
    if SetCVar and GetCVar then
        if tostring(GetCVar("NP_EnableAuraCastEvents")) ~= "1" then
            SetCVar("NP_EnableAuraCastEvents", "1")
        end
        if tostring(GetCVar("NP_EnableSpellGoEvents")) ~= "1" then
            SetCVar("NP_EnableSpellGoEvents", "1")
        end
    end
end

local procDocTooltipBuffList  = {}
local procDocAuraBuffList     = {}
local procDocNampowerBuffList = {}

local function ProcDoc_GetBuffRecord(pool, n)
    local rec = pool[n]
    if not rec then
        rec = {}
        pool[n] = rec
    end
    return rec
end

local function ProcDoc_ReadBuffsNampower()
    local n = 0
    local now = GetTime()
    local seenSpellIds = {}
    for auraSlot = 0, 31 do
        local spellId, remainingMs = GetPlayerAuraDuration(auraSlot)
        if spellId and spellId > 0 then
            local meta = ProcDoc_GetNampowerSpellMeta(spellId)
            if meta then
                seenSpellIds[spellId] = true
                local tl
                if remainingMs and remainingMs > 0 then
                    tl = remainingMs / 1000
                end
                local stacks = npSlotStacks[auraSlot]
                if not stacks then
                    -- Pre-existing buff before login: fall back to ClassicAPI if available, else 1
                    if ProcDoc_AuraApiPresent() and C_UnitAuras.GetPlayerAuraBySpellID then
                        local ad = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
                        if ad and ad.applications then stacks = ad.applications end
                    end
                    if not stacks then stacks = 1 end
                end
                n = n + 1
                local rec = ProcDoc_GetBuffRecord(procDocNampowerBuffList, n)
                rec.tex   = meta.tex
                rec.name  = meta.name
                rec.stack = stacks
                rec.api   = stacks
                rec.tl    = tl
                rec.loose = true
            end
        end
    end
    -- Append any buffcap-overflow procs captured via AURA_CAST_ON_SELF
    for spellId, entry in pairs(npCapBuffs) do
        if entry.expire <= now then
            npCapBuffs[spellId] = nil
        elseif not seenSpellIds[spellId] then
            local meta = ProcDoc_GetNampowerSpellMeta(spellId)
            if meta then
                n = n + 1
                local rec = ProcDoc_GetBuffRecord(procDocNampowerBuffList, n)
                rec.tex   = meta.tex
                rec.name  = meta.name
                rec.stack = entry.stacks or 1
                rec.api   = entry.stacks or 1
                rec.tl    = entry.expire - now
                rec.loose = true
            end
        end
    end
    return procDocNampowerBuffList, n
end

local function ProcDoc_ReadBuffsTooltip()
    local n = 0
    for i = 0, 31 do
        local buffTexture = GetPlayerBuffTexture(i)
        if buffTexture then
            ProcDocScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            ProcDocScanTooltip:ClearLines()
            ProcDocScanTooltip:SetPlayerBuff(i)
            local buffName = (ProcDocScanTooltipTextLeft1 and ProcDocScanTooltipTextLeft1:GetText()) or ""
            local stackGuess = 0
            -- Vanilla 1.12: stacks often appear as right text or in second left line; attempt simple numeric parse
            if ProcDocScanTooltipTextRight1 and ProcDocScanTooltipTextRight1:GetText() then
                local rn = tonumber(ProcDocScanTooltipTextRight1:GetText())
                if rn then stackGuess = rn end
            end
            if stackGuess == 0 and ProcDocScanTooltipTextLeft2 and ProcDocScanTooltipTextLeft2:GetText() then
                local ln2 = ProcDocScanTooltipTextLeft2:GetText()
                local ln2n = tonumber(ln2)
                if ln2n then stackGuess = ln2n end
            end
            local apiStacks
            if GetPlayerBuffApplications then
                apiStacks = GetPlayerBuffApplications(i)
            end
            -- Prefer GetPlayerBuffApplications for Astral Boon / Natural Boon (reliable charges)
            if apiStacks and (buffName == "Astral Boon" or buffName == "Natural Boon") and apiStacks > 0 then
                stackGuess = apiStacks
            end
            ProcDocScanTooltip:Hide()
            local tl
            if GetPlayerBuffTimeLeft then tl = GetPlayerBuffTimeLeft(i) end
            n = n + 1
            local rec = ProcDoc_GetBuffRecord(procDocTooltipBuffList, n)
            rec.tex   = buffTexture
            rec.name  = buffName
            rec.stack = stackGuess
            rec.api   = apiStacks
            rec.tl    = tl
            rec.loose = nil
        end
    end
    return procDocTooltipBuffList, n
end

local function ProcDoc_ReadBuffsAura()
    local n = 0
    local now = GetTime()
    for i = 1, 40 do
        local name, icon, count, _, _, expirationTime = C_UnitAuras.UnitAura("player", i, "HELPFUL")
        if not name then break end
        local tl
        if expirationTime and expirationTime > 0 then
            tl = expirationTime - now
            if tl < 0 then tl = 0 end
        end
        n = n + 1
        -- count is the real stack count (>= 1); icon is compared loosely (see ProcDoc_TexEqual)
        local rec = ProcDoc_GetBuffRecord(procDocAuraBuffList, n)
        rec.tex   = icon or ""
        rec.name  = name
        rec.stack = count or 0
        rec.api   = count or 0
        rec.tl    = tl
        rec.loose = true
    end
    return procDocAuraBuffList, n
end

local function ProcDoc_ReadPlayerBuffs()
    if ProcDoc_UsingNampowerApi() then
        local ok, list, n = pcall(ProcDoc_ReadBuffsNampower)
        if ok then return list, n end
        procDocNampowerFailed = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800ProcDoc|r: the Nampower buff API failed, falling back.")
    end
    if ProcDoc_UsingAuraApi() then
        local ok, list, n = pcall(ProcDoc_ReadBuffsAura)
        if ok then return list, n end
        procDocAuraFailed = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800ProcDoc|r: the aura API failed, falling back to tooltip scanning.")
    end
    return ProcDoc_ReadBuffsTooltip()
end

-- Exact comparison for tooltip-sourced icons (as before); case/path-insensitive for aura-sourced ones.
local function ProcDoc_TexEqual(rec, wanted)
    if rec.tex == wanted then return true end
    if not rec.loose or not rec.tex or not wanted then return false end
    local a = string.lower(rec.tex); local b = string.lower(wanted)
    if a == b then return true end
    a = string.gsub(a, "^.*[\\/]", ""); b = string.gsub(b, "^.*[\\/]", "")
    return a == b
end

-- Pulse speed was applied per frame, so it ran faster at high FPS. It is now scaled by the elapsed
-- time and calibrated so that nothing changes at pulseReferenceFps (60 by default).
local PULSE_MAX_STEP = 6   -- never advance more than this many "reference frames" at once (lag spikes)

local onUpdateAttached = false
local OnUpdateHandler

local function ProcDoc_EnsureOnUpdate()
    if not onUpdateAttached then
        ProcDoc:SetScript("OnUpdate", OnUpdateHandler)
        onUpdateAttached = true
    end
end

OnUpdateHandler = function()
    -- True-zero idle exit: detach OnUpdate when no alert is active
    local anyActive = false
    local needSnapshot = false
    for _, ao in ipairs(alertFrames) do
        if ao.isActive then
            anyActive = true
            if ao.hasTimer and (not ao.isActionBased) and (not ao.isTest) and ao.buffName then
                needSnapshot = true
            end
        end
    end
    if not anyActive then
        ProcDoc:SetScript("OnUpdate", nil)
        onUpdateAttached = false
        return
    end

    if maxAlpha <= minAlpha then maxAlpha = minAlpha + 0.01 end
    if maxScale <= minScale then maxScale = minScale + 0.01 end

    local now = GetTime()
    local refFps = (ProcDocDB and ProcDocDB.globalVars and ProcDocDB.globalVars.pulseReferenceFps) or 60
    local frameStep = 1
    if arg1 and arg1 > 0 and refFps > 0 then
        frameStep = arg1 * refFps
        if frameStep > PULSE_MAX_STEP then frameStep = PULSE_MAX_STEP end
    end
    -- Periodic capture of current buff remaining times so we can detect mid-duration refreshes
    if not ProcDoc._lastBuffTimeScan then ProcDoc._lastBuffTimeScan = 0 end
    if not ProcDoc.currentBuffTimes then ProcDoc.currentBuffTimes = {} end
    if needSnapshot and (now - ProcDoc._lastBuffTimeScan) > 0.30 then -- throttle ~3 times per second
        local snapshot = ProcDoc.currentBuffTimes
        for k in pairs(snapshot) do snapshot[k] = nil end
        local list, n = ProcDoc_ReadPlayerBuffs()
        for bi = 1, n do
            local rec = list[bi]
            local bName = rec.name
            if bName ~= "" then
                local tl = rec.tl
                if tl and tl > 0 then
                    -- keep the largest remaining (some servers may duplicate icons)
                    if (not snapshot[bName]) or (tl > snapshot[bName]) then
                        snapshot[bName] = tl
                    end
                end
            end
        end
        ProcDoc._lastBuffTimeScan = now
    end
    for _, alertObj in ipairs(alertFrames) do
        if alertObj.isActive then
            -- Pulse update
            alertObj.pulseAlpha = alertObj.pulseAlpha + (alertObj.pulseDir * pulseSpeed * frameStep)
            if alertObj.pulseAlpha < minAlpha then
                alertObj.pulseAlpha = minAlpha
                alertObj.pulseDir   = alphaStep
            elseif alertObj.pulseAlpha > maxAlpha then
                alertObj.pulseAlpha = maxAlpha
                alertObj.pulseDir   = -alphaStep
            end

            local scale = 1.0
            local aRange = maxAlpha - minAlpha
            if aRange > 0 then
                local frac = (alertObj.pulseAlpha - minAlpha) / aRange
                scale = minScale + frac * (maxScale - minScale)
            end

            -- Apply pulse (and optional low-resource/wrong-stance dimming) to textures
            local wantDim = alertObj.isDimmed and true or false
            local dimChanged = (alertObj._appliedDim ~= wantDim)
            if dimChanged then
                alertObj._appliedDim = wantDim
            end
            local drawAlpha = wantDim and (alertObj.pulseAlpha * 0.55) or alertObj.pulseAlpha
            for _, tex in ipairs(alertObj.textures) do
                if dimChanged and tex.SetDesaturated then
                    -- ClassicAPI v1.23.1 requires nil (not 0) to turn off desaturation
                    tex:SetDesaturated(wantDim and 1 or nil)
                end
                tex:SetAlpha(drawAlpha)
                tex:SetWidth(alertObj.baseWidth * scale)
                tex:SetHeight(alertObj.baseHeight * scale)
                tex:Show()
            end

            -- Timer countdown text
            if alertObj.hasTimer and alertObj.procDuration and alertObj.procStartTime then
                -- Refresh detection: if the buff was re-applied (remaining time jumped up), reset timer
                if (not alertObj.isActionBased) and alertObj.buffName and ProcDoc.currentBuffTimes then
                    local observedTL = ProcDoc.currentBuffTimes[alertObj.buffName]
                    if observedTL and observedTL > 0 then
                        local elapsedSoFar = now - alertObj.procStartTime
                        local remainingPrev = alertObj.procDuration - elapsedSoFar
                        if remainingPrev < 0 then remainingPrev = 0 end
                        -- If the newly observed time left exceeds previous remaining by >0.5s treat as refresh
                        if (observedTL - remainingPrev) > 0.5 then
                            alertObj.procStartTime = now
                            alertObj.procDuration  = observedTL
                            alertObj.zeroShown     = false
                        end
                    end
                end
                local elapsed   = now - alertObj.procStartTime
                local remaining = alertObj.procDuration - elapsed
                local useDecimals = (not ProcDocDB) or (not ProcDocDB.globalVars) or (ProcDocDB.globalVars.decimalTimers ~= false)
                local secs
                if remaining <= 0 then
                    secs = 0
                    if alertObj.zeroShown then
                        -- Now hide after showing 0 previously
                        alertObj.isActive      = false
                        alertObj.isDimmed      = false
                        alertObj.hasTimer      = false
                        alertObj.procStartTime = nil
                        alertObj.procDuration  = nil
                        alertObj.forceHide     = true
                        for _, tex in ipairs(alertObj.textures) do tex:Hide() end
                        if alertObj.timerTexts then
                            for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
                        end
                        if alertObj.stackText then alertObj.stackText:Hide() end
                    else
                        alertObj.zeroShown = true
                    end
                elseif useDecimals and remaining < 5 then
                    secs = string.format("%.1f", remaining)
                else
                    -- Display remaining seconds (use floor so we reach 0)
                    secs = math.floor(remaining + 0.0001)
                    if secs < 0 then secs = 0 end
                end
                if alertObj.isActive and secs ~= nil then
                    local urgent = (remaining < 2)
                    for _, fs in ipairs(alertObj.timerTexts) do
                        if fs then
                            fs:SetText(secs)
                            if urgent then
                                fs:SetTextColor(1, 0.25, 0.15, 1)
                            else
                                fs:SetTextColor(1, 1, 0, 1)
                            end
                            if timerTextAlpha then fs:SetAlpha(timerTextAlpha) end
                            fs:Show()
                        end
                    end
                end
            else
                -- No timer -> hide any stray timer texts
                if alertObj.timerTexts then
                    for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
                end
            end
        end
        -- If frame is inactive but leftover timer/stack text somehow visible, hide it
        if (not alertObj.isActive) then
            if alertObj.timerTexts then
                for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
            end
            if alertObj.stackText then alertObj.stackText:Hide() end
        end
    end
end

ProcDoc:SetWidth(1)
ProcDoc:SetHeight(1)
ProcDoc:SetPoint("CENTER", UIParent, "CENTER")

-- 6) Merge buff & action proc definitions for the player's class
local _, playerClass = UnitClass("player")

local normalProcs  = PROC_DATA[playerClass] or {}
local actionProcs  = ACTION_PROCS[playerClass] or {}  -- e.g. Overpower

-- Merge them into one big â€œclassProcsâ€ table
local classProcs = {}
for _, p in ipairs(normalProcs) do
    table.insert(classProcs, p)
end
for _, q in ipairs(actionProcs) do
    table.insert(classProcs, q)
end

-- 7) Buff-based detection

-- Holds which buff names weâ€™ve already played a sound for.
local knownBuffProcs = {}
local buffStackCounts = {}

-- Fallback combat flag for clients without UnitAffectingCombat (declared early for Combat Only)
local inCombatFlag = false

local function ProcDoc_InCombat()
    return (UnitAffectingCombat and UnitAffectingCombat("player")) or inCombatFlag
end

local function CheckProcs()
    -- Ensure we are using the latest saved globals each time we show/update alerts
    if ProcDoc_LoadGlobalsFromDB then ProcDoc_LoadGlobalsFromDB() end
    -- Preserve pulse phase for buffs that remain active across unrelated PLAYER_AURAS_CHANGED events
    local prevPulse = {}
    -- 1) Hide any old live (non-action, non-test) buff frames first
    for _, alertObj in ipairs(alertFrames) do
        if (not alertObj.isActionBased) and (not alertObj.isTest) then
            if alertObj.isActive and alertObj.buffName then
                prevPulse[alertObj.buffName] = { alpha = alertObj.pulseAlpha, dir = alertObj.pulseDir }
            end
            alertObj.isActive = false
            for _, tex in ipairs(alertObj.textures) do tex:Hide() end
            if alertObj.timerTexts then
                for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
            end
            if alertObj.stackText then alertObj.stackText:Hide() end
            alertObj.hasTimer      = false
            alertObj.procStartTime = nil
            alertObj.procDuration  = nil
            alertObj.buffName      = nil
        end
    end

    -- Respect Combat Only mode for live buff procs
    if ProcDocDB and ProcDocDB.globalVars and ProcDocDB.globalVars.combatOnly and (not ProcDoc_InCombat()) then
        for bName in pairs(knownBuffProcs) do knownBuffProcs[bName] = nil end
        hotStreakLastTier = 0
        return
    end

    -- 2) Gather a list of all currently active buff-based procs
    local activeBuffProcs = {}
    local activeBuffNames = {}  -- just the names, for quick â€œdid it fall off?â€ checks

    local hotStreakStacks = 0
    buffStackCounts = {}
    local firstTimeLeft = {}   -- first slot carrying each name wins (false = present but no time left)
    local buffList, buffCount = ProcDoc_ReadPlayerBuffs()
    for bi = 1, buffCount do
        local rec = buffList[bi]
        local buffTexture = rec.tex
        local buffName    = rec.name
        local stackGuess  = rec.stack
        if firstTimeLeft[buffName] == nil then
            firstTimeLeft[buffName] = (rec.tl and rec.tl > 0) and rec.tl or false
        end

        for _, procInfo in ipairs(normalProcs) do
            -- the Hot Streak entry exists for the options list / test button only; its live alerts are the tier visuals below
            if procInfo.buffName ~= HOT_STREAK_BUFF_NAME and ProcDocDB.procsEnabled[procInfo.buffName] ~= false then
                if (procInfo.texture == nil or ProcDoc_TexEqual(rec, procInfo.texture)) and (buffName == procInfo.buffName) then
                    table.insert(activeBuffProcs, procInfo)
                    activeBuffNames[procInfo.buffName] = true
                    -- Store stack count if any (>=1 valid)
                    if stackGuess and stackGuess >= 1 then
                        buffStackCounts[buffName] = stackGuess
                    end
                end
            end
        end
        -- User-defined custom buff procs (/procdoc add <BuffName> [style])
        if ProcDocDB and ProcDocDB.customProcs and (not activeBuffNames[buffName]) then
            local customInfo = ProcDocDB.customProcs[buffName]
            if customInfo and ProcDocDB.procsEnabled[buffName] ~= false then
                table.insert(activeBuffProcs, customInfo)
                activeBuffNames[buffName] = true
                if stackGuess and stackGuess >= 1 then
                    buffStackCounts[buffName] = stackGuess
                end
            end
        end
        -- Hot Streak detection (fuzzy, allow lowercase compare, handle possible rank suffixes)
        if buffName ~= "" then
            local lowerName = string.lower(buffName)
            if lowerName == string.lower(HOT_STREAK_BUFF_NAME) or string.find(lowerName, "hot streak") then
                local stacks = rec.api or stackGuess
                if not stacks or stacks < 1 then stacks = 1 end
                if stacks > hotStreakStacks then hotStreakStacks = stacks end
            end
        end
    end

    -- 3) Show frames for each active buff
    for _, procInfo in ipairs(activeBuffProcs) do
        local style   = procInfo.alertStyle or "SIDES"
        local alertObj = AcquireAlertFrame(style, false, false)
        local savedPulse = prevPulse[procInfo.buffName]
        alertObj.isActive   = true
        alertObj.isDimmed   = false
        alertObj.pulseAlpha = (savedPulse and savedPulse.alpha) or minAlpha
        alertObj.pulseDir   = (savedPulse and savedPulse.dir)   or alphaStep
        alertObj.hasTimer      = false
        alertObj.procStartTime = nil
        alertObj.procDuration  = nil
        alertObj.buffName      = procInfo.buffName

        local initScale = minScale
        if maxAlpha > minAlpha then
            initScale = minScale + ((alertObj.pulseAlpha - minAlpha) / (maxAlpha - minAlpha)) * (maxScale - minScale)
        end
        local path = procInfo.alertTexturePath or DEFAULT_ALERT_TEXTURE
        for _, tex in ipairs(alertObj.textures) do
            tex:SetTexture(path)
            tex:SetAlpha(alertObj.pulseAlpha)
            tex:SetWidth(alertObj.baseWidth * initScale)
            tex:SetHeight(alertObj.baseHeight * initScale)
            tex:Show()
        end
        ProcDoc_ReanchorAlert(alertObj)

        -- Timer numeric countdown (replaces prior vertical wipe implementation)
        local timeLeft = firstTimeLeft[procInfo.buffName]
        if timeLeft == false then timeLeft = nil end
        if (not ProcDocDB.globalVars.disableTimers) and timeLeft and timeLeft > 0 then
            alertObj.hasTimer      = true
            alertObj.procStartTime = GetTime()
            alertObj.procDuration  = timeLeft
            alertObj.zeroShown     = false
            -- Create/ensure timer font strings (one per base texture)
            local xShift = 0
            if procInfo.buffName == "Astral Boon" then
                xShift = -45 -- left side
            elseif procInfo.buffName == "Natural Boon" then
                xShift = 45  -- right side
            end
            for idx, baseTex in ipairs(alertObj.textures) do
                if not alertObj.timerTexts[idx] then
                    local parentFrame = baseTex:GetParent() or ProcDoc or UIParent
                    local fs = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                    fs:SetPoint("CENTER", baseTex, "CENTER", xShift, 0)
                    fs:SetTextColor(1, 1, 0, 1)
                    if timerTextAlpha then fs:SetAlpha(timerTextAlpha) end
                    fs:SetText("")
                    alertObj.timerTexts[idx] = fs
                else
                    local fs = alertObj.timerTexts[idx]
                    fs:ClearAllPoints()
                    fs:SetPoint("CENTER", alertObj.textures[idx], "CENTER", xShift, 0)
                end
            end
            -- Stack displays (Astral Boon left, Natural Boon right; stacks above respective shifted timers)
            if procInfo.buffName == "Astral Boon" or procInfo.buffName == "Natural Boon" then
                local stacks = buffStackCounts[procInfo.buffName]
                if stacks and stacks >= 1 then
                    local anchorFS = alertObj.timerTexts[1]
                    if anchorFS then
                        if not alertObj.stackText then
                            local parentFrame = anchorFS:GetParent() or ProcDoc or UIParent
                            local sfs = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                            sfs:SetTextColor(1,1,1,1)
                            if timerTextAlpha then sfs:SetAlpha(timerTextAlpha) end
                            alertObj.stackText = sfs
                        end
                        alertObj.stackText:ClearAllPoints()
                        -- Center directly above the timer (no horizontal offset)
                        alertObj.stackText:SetPoint("BOTTOM", anchorFS, "TOP", 0, 2)
                        alertObj.stackText:SetText(stacks)
                        alertObj.stackText:Show()
                    end
                else
                    if alertObj.stackText then alertObj.stackText:Hide() end
                end
            elseif alertObj.stackText then
                alertObj.stackText:Hide()
            end
        else
            -- Ensure timer texts hidden if no duration
            if alertObj.timerTexts then
                for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
            end
            if alertObj.stackText then alertObj.stackText:Hide() end
        end

        -- 4) If this is a newly gained buff, play the buff sound (if not muted).
        local bName = procInfo.buffName
        if not knownBuffProcs[bName] then
            ProcDoc_Trace("Buff proc gained: " .. tostring(bName))
            if not ProcDocDB.globalVars.isMuted then
                ProcDoc_PlayAlertSound(false)
            end
            knownBuffProcs[bName] = true
        end
        ProcDoc_EnsureOnUpdate()
    end

    -- 5) Remove any old buff from knownBuffProcs that has fallen off
    for bName in pairs(knownBuffProcs) do
        if not activeBuffNames[bName] then
            knownBuffProcs[bName] = nil
        end
    end

    -- 6) Hot Streak tier visuals (3=LEFT, 4=LEFT+RIGHT, 5=LEFT+RIGHT+TOP)
    if playerClass == "MAGE" and ProcDocDB.procsEnabled[HOT_STREAK_BUFF_NAME] ~= false then
        local tier = 0
        if hotStreakStacks >= 5 then tier = 5 elseif hotStreakStacks == 4 then tier = 4 elseif hotStreakStacks == 3 then tier = 3 end

        -- Hide previous tier frames if tier dropped or returned to 0
        if tier == 0 and hotStreakLastTier ~= 0 then
            for _, alertObj in ipairs(alertFrames) do
                if alertObj.isActive and (alertObj.style == "LEFT" or alertObj.style == "RIGHT" or alertObj.style == "TOP" or alertObj.style == "TOP2") then
                    -- Only hide those using our Hot Streak textures
                    local hide = false
                    for _, tex in ipairs(alertObj.textures) do
                        local tPath = tex:GetTexture()
                        if tPath == HOT_STREAK_SIDE_TEXTURE or tPath == HOT_STREAK_TOP_TEXTURE then hide = true break end
                    end
                    if hide then
                        alertObj.isActive = false
                        for _, tex in ipairs(alertObj.textures) do tex:Hide() end
                    end
                end
            end
        end

        if tier >= 3 then
            -- LEFT
            local leftObj = AcquireAlertFrame("LEFT", false, false)
            local sp = prevPulse["__HotStreak_LEFT"]
            leftObj.isActive = true
            leftObj.buffName = "__HotStreak_LEFT"
            leftObj.pulseAlpha = (sp and sp.alpha) or minAlpha
            leftObj.pulseDir = (sp and sp.dir) or alphaStep
            for _, tex in ipairs(leftObj.textures) do
                tex:SetTexture(HOT_STREAK_SIDE_TEXTURE)
                tex:SetAlpha(leftObj.pulseAlpha)
                tex:SetWidth(leftObj.baseWidth * minScale)
                tex:SetHeight(leftObj.baseHeight * minScale)
                tex:Show()
            end
            ProcDoc_ReanchorAlert(leftObj)
        end
        if tier >= 4 then
            -- RIGHT
            local rightObj = AcquireAlertFrame("RIGHT", false, false)
            local sp = prevPulse["__HotStreak_RIGHT"]
            rightObj.isActive = true
            rightObj.buffName = "__HotStreak_RIGHT"
            rightObj.pulseAlpha = (sp and sp.alpha) or minAlpha
            rightObj.pulseDir = (sp and sp.dir) or alphaStep
            for _, tex in ipairs(rightObj.textures) do
                tex:SetTexture(HOT_STREAK_SIDE_TEXTURE)
                tex:SetAlpha(rightObj.pulseAlpha)
                tex:SetWidth(rightObj.baseWidth * minScale)
                tex:SetHeight(rightObj.baseHeight * minScale)
                tex:Show()
            end
            ProcDoc_ReanchorAlert(rightObj)
        end
        if tier >= 5 then
            -- TOP (use TOP2 for spacing consistency with existing top visuals)
            local topObj = AcquireAlertFrame("TOP2", false, false)
            local sp = prevPulse["__HotStreak_TOP2"]
            topObj.isActive = true
            topObj.buffName = "__HotStreak_TOP2"
            topObj.pulseAlpha = (sp and sp.alpha) or minAlpha
            topObj.pulseDir = (sp and sp.dir) or alphaStep
            for _, tex in ipairs(topObj.textures) do
                tex:SetTexture(HOT_STREAK_TOP_TEXTURE)
                tex:SetAlpha(topObj.pulseAlpha)
                tex:SetWidth(topObj.baseWidth * minScale)
                tex:SetHeight(topObj.baseHeight * minScale)
                tex:Show()
            end
            ProcDoc_ReanchorAlert(topObj)
        end

        -- Play sound only on entering a new tier (avoid spam every scan)
        if tier ~= 0 then
            ProcDoc_EnsureOnUpdate()
            if tier ~= hotStreakLastTier then
                ProcDoc_Trace("Hot Streak tier -> " .. tostring(tier))
                if not ProcDocDB.globalVars.isMuted then ProcDoc_PlayAlertSound(false) end
            end
        end
        hotStreakLastTier = tier
    end
end




-- 8) Action-based detection (per-ability usability + combat-log/SPELL_ACTIVE reactive triggers)
--    Track states per ability
local actionProcStates = {}

-- Lookup table: spellName -> actionProc entry for the player's class
local actionProcByName = {}
for _, ap in ipairs(actionProcs) do
    local sName = ap.spellName or ap.buffName
    if sName then actionProcByName[sName] = ap end
end

local function ShowActionProcAlert(actionProc, isDimmed, customDuration, forceResetTimer)
    -- Sync from DB so we don't rely on options frame being opened first
    if ProcDoc_LoadGlobalsFromDB then ProcDoc_LoadGlobalsFromDB() end
    local spellName  = actionProc.spellName or "UnknownSpell"
    local state      = actionProcStates[spellName] or {}
    actionProcStates[spellName] = state

    local wantDim    = isDimmed and true or false
    local alertObj   = state.alertObj
    if alertObj and alertObj.isActive then
        -- Already showing: update dimmed state without restarting pulse animation
        alertObj.isDimmed = wantDim
        if forceResetTimer and (not ProcDocDB.globalVars.disableTimers) then
            local duration = customDuration or GetActionProcDuration(spellName)
            if duration and duration > 0 then
                alertObj.hasTimer      = true
                alertObj.procStartTime = GetTime()
                alertObj.procDuration  = duration
                alertObj.zeroShown     = false
                for idx, baseTex in ipairs(alertObj.textures) do
                    if not alertObj.timerTexts[idx] then
                        local parentFrame = baseTex:GetParent() or ProcDoc or UIParent
                        local fs = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                        fs:SetPoint("CENTER", baseTex, "CENTER", 0, 0)
                        fs:SetTextColor(1,1,0,1)
                        fs:SetText("")
                        alertObj.timerTexts[idx] = fs
                    end
                end
            end
        end
    else
        -- Acquire a new alert frame for isActionBased = true
        alertObj = AcquireAlertFrame(actionProc.alertStyle or "SIDES", true, false)
        alertObj.isActive    = true
        alertObj.isDimmed    = wantDim
        alertObj._appliedDim = nil
        alertObj.pulseAlpha  = minAlpha
        alertObj.pulseDir    = alphaStep

        local path = actionProc.alertTexturePath or actionProc.texture or DEFAULT_ALERT_TEXTURE
        local initAlpha = wantDim and (minAlpha * 0.55) or minAlpha
        for _, tex in ipairs(alertObj.textures) do
            tex:SetTexture(path)
            if tex.SetDesaturated then
                tex:SetDesaturated(wantDim and 1 or nil)
            end
            tex:SetAlpha(initAlpha)
            tex:SetWidth(alertObj.baseWidth * minScale)
            tex:SetHeight(alertObj.baseHeight * minScale)
            tex:Show()
        end
        alertObj._appliedDim = wantDim
        ProcDoc_ReanchorAlert(alertObj)

        if not ProcDocDB.globalVars.isMuted then
            ProcDoc_PlayAlertSound(true)
        end
        ProcDoc_Trace("Action proc shown: " .. tostring(spellName) .. (wantDim and " (dimmed)" or " (ready)"))

        -- Initialize timer if duration configured and timers enabled
        alertObj.hasTimer      = false
        alertObj.procStartTime = nil
        alertObj.procDuration  = nil
        if (not ProcDocDB.globalVars.disableTimers) then
            local duration = customDuration or GetActionProcDuration(spellName)
            if duration and duration > 0 then
                alertObj.hasTimer      = true
                alertObj.procStartTime = GetTime()
                alertObj.procDuration  = duration
                alertObj.zeroShown     = false
                for idx, baseTex in ipairs(alertObj.textures) do
                    if not alertObj.timerTexts[idx] then
                        local parentFrame = baseTex:GetParent() or ProcDoc or UIParent
                        local fs = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                        fs:SetPoint("CENTER", baseTex, "CENTER", 0, 0)
                        fs:SetTextColor(1,1,0,1)
                        fs:SetText("")
                        alertObj.timerTexts[idx] = fs
                    end
                end
            end
        end

        state.alertObj = alertObj
    end

    state.isActive = true
    ProcDoc_EnsureOnUpdate()
end

local function HideActionProcAlert(actionProc)
    local spellName = actionProc.spellName or "UnknownSpell"
    local state     = actionProcStates[spellName]
    if not state or not state.isActive then
        return
    end

    local alertObj = state.alertObj
    if alertObj and alertObj.isActive then
        alertObj.isActive = false
        alertObj.isDimmed = false
        for _, tex in ipairs(alertObj.textures) do tex:Hide() end
        if alertObj.timerTexts then
            for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
        end
    end
    state.isActive = false
end

-- Helper: find a spellbook index by exact name (vanilla 1.12 compatible)
local function FindSpellBookIndexByName(spellName)
    if not spellName then return nil end
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for t = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(t)
        if offset and numSpells then
            for i = offset + 1, offset + numSpells do
                local sName = GetSpellName(i, BOOKTYPE_SPELL or "spell")
                if sName == spellName then
                    return i
                end
            end
        end
    end
    return nil
end

-- Helper: remaining cooldown seconds for a spellbook spell (0 if ready or unknown)
local function GetSpellCooldownRemaining(spellName)
    local idx = FindSpellBookIndexByName(spellName)
    if not idx then return 0, false end
    local start, duration, enable = GetSpellCooldown(idx, BOOKTYPE_SPELL or "spell")
    if start and duration and start > 0 and duration > 0 then
        local rem = (start + duration) - GetTime()
        if rem > 0 then return rem, true end
    end
    return 0, true
end

-- Spellbook-driven action proc checks (for abilities that should show when off cooldown while in combat)
local function UpdateSpellbookActionProcs()
    if playerClass ~= "PALADIN" then return end
    for _, actionProc in ipairs(actionProcs) do
        if actionProc.useSpellbook and ProcDocDB.procsEnabled[actionProc.buffName] ~= false then
            local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or inCombatFlag
            if not inCombat then
                HideActionProcAlert(actionProc)
            else
                local idx = FindSpellBookIndexByName(actionProc.spellName)
                if idx then
                    local start, duration, enable = GetSpellCooldown(idx, BOOKTYPE_SPELL or "spell")
                    -- Ready if duration == 0 (ignore GCD as a cooldown requirement)
                    local ready = (duration == 0)
                    if ready then
                        ShowActionProcAlert(actionProc)
                    else
                        HideActionProcAlert(actionProc)
                    end
                else
                    -- Spell not found, ensure hidden
                    HideActionProcAlert(actionProc)
                end
            end
        elseif actionProc.useSpellbook == true and ProcDocDB.procsEnabled[actionProc.buffName] == false then
            -- Explicitly hidden by user
            HideActionProcAlert(actionProc)
        end
    end
end

-- Where each action proc's icon was last found. ACTIONBAR_UPDATE_USABLE fires many times a second in
-- combat, so scanning all 120 slots every time was the main cost. A cached slot is re-checked with a
-- single GetActionTexture call; the cache is dropped when the bars change and expires on its own.
local actionSlotCache = {}
local ACTION_CACHE_FOUND_TTL = 10
local ACTION_CACHE_MISSING_TTL = 2

local function ProcDoc_InvalidateActionSlots()
    actionSlotCache = {}
end

local function FindActionSlotAndCheck(actionProc)
    local spellName = actionProc.spellName or "UnknownSpell"
    local texPath   = actionProc.texture or ""
    if texPath == "" then
        return
    end

    -- find slot
    local lowerWanted = actionProc._lowerTex
    if not lowerWanted then
        lowerWanted = string.lower(texPath)
        actionProc._lowerTex = lowerWanted
    end
    local foundSlot = nil
    local now = GetTime()
    local cached = actionSlotCache[spellName]
    local needScan = true
    if cached then
        if cached.slot then
            if (now - cached.t) < ACTION_CACHE_FOUND_TTL then
                local ct = GetActionTexture(cached.slot)
                if ct and string.lower(ct) == lowerWanted then
                    foundSlot = cached.slot
                    needScan = false
                end
            end
        elseif (now - cached.t) < ACTION_CACHE_MISSING_TTL then
            needScan = false
        end
    end
    if needScan then
        for slot = 1, 120 do
            local actionTex = GetActionTexture(slot)
            if actionTex then
                if string.lower(actionTex) == lowerWanted then
                    foundSlot = slot
                    break
                end
            end
        end
        actionSlotCache[spellName] = { slot = foundSlot, t = now }
    end

    local state = actionProcStates[spellName] or {}
    actionProcStates[spellName] = state

    state.slot = foundSlot

    local dimOnLowResource = (not ProcDocDB) or (not ProcDocDB.globalVars) or (ProcDocDB.globalVars.dimOnLowResource ~= false)
    local combatRem = (state.combatExpire and (state.combatExpire - now)) or 0
    if combatRem <= 0 then
        state.combatExpire = nil
        combatRem = 0
    end

    local usable, notEnoughMana = nil, nil
    if foundSlot then
        usable, notEnoughMana = IsUsableAction(foundSlot)
        if (usable or notEnoughMana) and actionProc.useSpellbookForCooldown then
            local idx = FindSpellBookIndexByName(actionProc.spellName)
            if idx then
                local _, duration = GetSpellCooldown(idx, BOOKTYPE_SPELL or "spell")
                if duration and duration > 1.5 then
                    usable = nil
                    notEnoughMana = nil
                end
            end
        end
    end

    if usable then
        if not state.timedOut then
            ShowActionProcAlert(actionProc, false, (combatRem > 0) and combatRem or nil, false)
        end
    elseif notEnoughMana and dimOnLowResource then
        if not state.timedOut then
            ShowActionProcAlert(actionProc, true, (combatRem > 0) and combatRem or nil, false)
        end
    elseif combatRem > 0 and dimOnLowResource then
        -- Combat-triggered reactive window (e.g. Overpower/Revenge in another stance or Arcane Surge on resist)
        local cdRem, known = GetSpellCooldownRemaining(spellName)
        if (not known) or cdRem < combatRem then
            ShowActionProcAlert(actionProc, true, combatRem, false)
        elseif state.isActive then
            HideActionProcAlert(actionProc)
        end
    else
        state.timedOut = nil
        if state.isActive then
            HideActionProcAlert(actionProc)
        end
    end
end

-- Trigger a reactive action proc from combat log or COMBAT_TEXT_UPDATE (SPELL_ACTIVE).
-- Works even when in another stance or when the ability is not on the current action bar.
local function TriggerCombatActionProc(actionProc)
    if not actionProc then return end
    if ProcDocDB and ProcDocDB.procsEnabled and ProcDocDB.procsEnabled[actionProc.buffName] == false then
        return
    end
    local spellName = actionProc.spellName or actionProc.buffName
    local window = GetActionProcDuration(spellName) or 5
    local cdRem, known = GetSpellCooldownRemaining(spellName)
    -- Only ignore if we know the spell is on a cooldown longer than the entire proc window
    if known and cdRem >= window then
        return
    end
    local now = GetTime()
    local state = actionProcStates[spellName] or {}
    actionProcStates[spellName] = state
    state.combatExpire = now + window
    state.timedOut     = nil

    -- Determine whether it is immediately pressable or should start dimmed
    local dimOnLowResource = (not ProcDocDB) or (not ProcDocDB.globalVars) or (ProcDocDB.globalVars.dimOnLowResource ~= false)
    local usable, notEnoughMana = nil, nil
    if state.slot then
        usable, notEnoughMana = IsUsableAction(state.slot)
    end
    if usable then
        ShowActionProcAlert(actionProc, false, window, true)
    elseif dimOnLowResource then
        ShowActionProcAlert(actionProc, true, window, true)
    end
end

local function ClearCombatActionProc(spellName)
    local actionProc = actionProcByName[spellName]
    if not actionProc then return end
    local st = actionProcStates[spellName]
    if st then
        st.combatExpire = nil
        st.timedOut     = nil
    end
    HideActionProcAlert(actionProc)
end

local function CheckAllActionProcs()
    if ProcDocDB and ProcDocDB.globalVars and ProcDocDB.globalVars.combatOnly and (not ProcDoc_InCombat()) then
        for _, actionProc in ipairs(actionProcs) do
            HideActionProcAlert(actionProc)
        end
        return
    end
    for _, actionProc in ipairs(actionProcs) do
        -- skip if disabled
        if ProcDocDB.procsEnabled[actionProc.buffName] ~= false then
            -- If the underlying alertObj was force hidden (timer expiry), mark timedOut until usable clears
            local st = actionProcStates[actionProc.spellName or actionProc.buffName]
            if st and st.alertObj and st.alertObj.forceHide then
                st.isActive = false
                st.timedOut = true
                st.alertObj.forceHide = nil
            end
            FindActionSlotAndCheck(actionProc)
        else
            -- if it's currently active, hide it
            local st = actionProcStates[actionProc.spellName or actionProc.buffName]
            if st then st.timedOut = nil end
            HideActionProcAlert(actionProc)
        end
    end
end



-- 9) Event frame for action-based procs

-- Periodic timer for spellbook cooldown checking (Paladin only)
local spellbookCheckFrame = CreateFrame("Frame", "ProcDocSpellbookFrame", UIParent)
local lastSpellbookCheck = 0
local SPELLBOOK_CHECK_INTERVAL = 0.1  -- Check every 0.1 seconds while in combat & on cooldown

if playerClass == "PALADIN" then
    spellbookCheckFrame:SetScript("OnUpdate", function()
        local now = GetTime()
        if (now - lastSpellbookCheck) >= SPELLBOOK_CHECK_INTERVAL then
            -- Only check if in combat AND we have spellbook procs that are currently down
            local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or inCombatFlag
            if inCombat then
                local needsCheck = false
                -- Check if any spellbook-based procs are currently down but enabled
                for _, actionProc in ipairs(actionProcs) do
                    if actionProc.useSpellbook and ProcDocDB.procsEnabled[actionProc.buffName] ~= false then
                        local state = actionProcStates[actionProc.spellName or actionProc.buffName]
                        if not state or not state.isActive then
                            needsCheck = true
                            break
                        end
                    end
                end
                
                if needsCheck then
                    UpdateSpellbookActionProcs()
                end
            end
            lastSpellbookCheck = now
        end
    end)
end

-- If your older client needs the old style event usage, do the "global event" trick:
local actionFrame = CreateFrame("Frame", "ProcDocActionFrame", UIParent)
actionFrame:RegisterEvent("PLAYER_LOGIN")
actionFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
actionFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
actionFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
actionFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
actionFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
actionFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
actionFrame:RegisterEvent("SPELLS_CHANGED")
actionFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
actionFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
actionFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
actionFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

if table.getn(actionProcs) > 0 then
    actionFrame:RegisterEvent("COMBAT_TEXT_UPDATE")
    actionFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    actionFrame:RegisterEvent("UNIT_MANA")
    actionFrame:RegisterEvent("UNIT_RAGE")
    actionFrame:RegisterEvent("UNIT_ENERGY")
end
if playerClass == "WARRIOR" then
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
    actionFrame:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF")
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES")
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
elseif playerClass == "ROGUE" then
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
    actionFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES")
end

actionFrame:SetScript("OnEvent", function()
    local e   = event
    local a1  = arg1
    local a2  = arg2
    local a3  = arg3

    if e == "ACTIONBAR_SLOT_CHANGED" or e == "SPELLS_CHANGED" then
        -- only forget where the icons were; the next usable/cooldown update re-evaluates as before
        ProcDoc_InvalidateActionSlots()
    elseif e == "PLAYER_LOGIN" then
        ProcDoc_EnableNampowerCVars()
        if ProcDoc_NampowerPresent() and table.getn(actionProcs) > 0 then
            actionFrame:RegisterEvent("SPELL_GO_SELF")
        end
        ProcDoc_InvalidateActionSlots()
        CheckAllActionProcs()
        CheckProcs()  -- run buff-based as well
        UpdateSpellbookActionProcs()
    elseif e == "UNIT_MANA" or e == "UNIT_RAGE" or e == "UNIT_ENERGY" then
        if a1 == "player" then
            CheckAllActionProcs()
        end
    elseif e == "COMBAT_TEXT_UPDATE" then
        if a1 == "SPELL_ACTIVE" and a2 and actionProcByName[a2] then
            TriggerCombatActionProc(actionProcByName[a2])
        end
    elseif e == "SPELL_GO_SELF" then
        -- Nampower instant cast completion: arg2 = spellId
        if a2 and type(GetSpellRecField) == "function" then
            local sName = GetSpellRecField(a2, "name")
            if sName and actionProcByName[sName] then
                ClearCombatActionProc(sName)
                CheckAllActionProcs()
                UpdateSpellbookActionProcs()
            end
        end
    elseif e == "CHAT_MSG_COMBAT_SELF_MISSES" then
        if a1 and string.find(a1, "dodges", 1, true) then
            if actionProcByName["Overpower"] then
                TriggerCombatActionProc(actionProcByName["Overpower"])
            end
            if actionProcByName["Surprise Attack"] then
                TriggerCombatActionProc(actionProcByName["Surprise Attack"])
            end
        end
    elseif e == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or e == "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES" then
        if a1 then
            local dodged = string.find(a1, "You dodge", 1, true)
            local parried = string.find(a1, "You parry", 1, true)
            if (dodged or parried) and actionProcByName["Revenge"] then
                TriggerCombatActionProc(actionProcByName["Revenge"])
            end
            if parried then
                if actionProcByName["Counterattack"] then
                    TriggerCombatActionProc(actionProcByName["Counterattack"])
                end
                if actionProcByName["Riposte"] then
                    TriggerCombatActionProc(actionProcByName["Riposte"])
                end
            end
        end
    elseif e == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" or e == "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS" then
        if a1 and string.find(a1, "blocked", 1, true) and actionProcByName["Revenge"] then
            TriggerCombatActionProc(actionProcByName["Revenge"])
        end
    elseif e == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" then
        if a1 and string.find(a1, "was dodged by", 1, true) and actionProcByName["Overpower"] then
            TriggerCombatActionProc(actionProcByName["Overpower"])
        end
    elseif e == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        if a1 then
            if string.find(a1, "was dodged by", 1, true) then
                if playerClass == "WARRIOR" and actionProcByName["Overpower"] then
                    TriggerCombatActionProc(actionProcByName["Overpower"])
                elseif playerClass == "ROGUE" and actionProcByName["Surprise Attack"] then
                    TriggerCombatActionProc(actionProcByName["Surprise Attack"])
                end
            end
            if playerClass == "MAGE" and (string.find(a1, "resist", 1, true) or string.find(a1, "Resist", 1, true)) and actionProcByName["Arcane Surge"] then
                TriggerCombatActionProc(actionProcByName["Arcane Surge"])
            end
            -- Hide reactive proc immediately on stock 1.12 when cast lands/misses
            for spellName in pairs(actionProcByName) do
                if string.find(a1, "Your " .. spellName .. " ", 1, true) then
                    ClearCombatActionProc(spellName)
                    break
                end
            end
        end
    elseif e == "ACTIONBAR_PAGE_CHANGED"
        or e == "UPDATE_BONUS_ACTIONBAR"
        or e == "UPDATE_SHAPESHIFT_FORM"
        or e == "PLAYER_TARGET_CHANGED"
        or e == "ACTIONBAR_UPDATE_USABLE"
        or e == "ACTIONBAR_UPDATE_COOLDOWN"
        or e == "PLAYER_REGEN_DISABLED"
        or e == "PLAYER_REGEN_ENABLED"
    then
        if e == "ACTIONBAR_PAGE_CHANGED" or e == "UPDATE_BONUS_ACTIONBAR" or e == "UPDATE_SHAPESHIFT_FORM" then
            ProcDoc_InvalidateActionSlots()
        end
        if e == "PLAYER_REGEN_DISABLED" then inCombatFlag = true end
        if e == "PLAYER_REGEN_ENABLED"  then inCombatFlag = false end
        CheckAllActionProcs()
        UpdateSpellbookActionProcs()
        if (e == "PLAYER_REGEN_DISABLED" or e == "PLAYER_REGEN_ENABLED")
            and ProcDocDB and ProcDocDB.globalVars and ProcDocDB.globalVars.combatOnly
        then
            CheckProcs()
        end
    elseif e == "UNIT_SPELLCAST_SUCCEEDED" then
        -- if we just cast Overpower / Riposte / Arcane Surge, hide them
        if a1 == "player" and a2 and actionProcByName[a2] then
            ClearCombatActionProc(a2)
        end
        CheckAllActionProcs()
        UpdateSpellbookActionProcs()
    end
end)


-- 10) Aura change event (buff-based proc refresh + Nampower event-driven buffcap tracking)
local auraFrame = CreateFrame("Frame", "ProcDocAuraFrame", UIParent)
auraFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
auraFrame:RegisterEvent("PLAYER_LOGIN")
auraFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        if ProcDoc_NampowerBuffApiPresent() then
            ProcDoc_EnableNampowerCVars()
            auraFrame:RegisterEvent("BUFF_ADDED_SELF")
            auraFrame:RegisterEvent("BUFF_REMOVED_SELF")
            auraFrame:RegisterEvent("BUFF_UPDATE_DURATION_SELF")
            auraFrame:RegisterEvent("AURA_CAST_ON_SELF")
        end
        return
    elseif event == "BUFF_ADDED_SELF" then
        -- args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
        local spellId, stackCount, auraSlot = arg3, arg4, arg6
        if auraSlot ~= nil then
            npSlotStacks[auraSlot] = stackCount or 1
        end
        if spellId then
            npCapBuffs[spellId] = nil
        end
    elseif event == "BUFF_REMOVED_SELF" then
        -- args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
        local spellId, stackCount, auraSlot, state = arg3, arg4, arg6, arg7
        if auraSlot ~= nil then
            if state == 2 and stackCount and stackCount > 0 then
                npSlotStacks[auraSlot] = stackCount
            else
                npSlotStacks[auraSlot] = nil
            end
        end
        if spellId and state ~= 2 then
            npCapBuffs[spellId] = nil
        end
    elseif event == "BUFF_UPDATE_DURATION_SELF" then
        -- args: auraSlot, durationMs, expirationTimeMs, spellId
        local durationMs, spellId = arg2, arg4
        if (not spellId) or spellId <= 0 then
            return -- newly added buff; BUFF_ADDED_SELF handles it immediately
        end
        if durationMs and durationMs > 0 then
            local meta = ProcDoc_GetNampowerSpellMeta(spellId)
            if meta and ProcDoc.currentBuffTimes then
                ProcDoc.currentBuffTimes[meta.name] = durationMs / 1000
            end
        end
    elseif event == "AURA_CAST_ON_SELF" then
        -- args: spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus
        local spellId, durationMs, auraCapStatus = arg1, arg8, arg9
        -- Bit 1 of auraCapStatus means the 32-buff bar is full (buffcap)
        if spellId and durationMs and durationMs > 0 and (auraCapStatus == 1 or auraCapStatus == 3) then
            npCapBuffs[spellId] = { expire = GetTime() + (durationMs / 1000), stacks = 1 }
        else
            return
        end
    end
    CheckProcs()
end)

-- Class colors for chat messages
local CLASS_COLORS = {
    ["WARRIOR"]     = "ffc79c6e",  -- Tan
    ["PALADIN"]     = "fff58cba",  -- Pink
    ["HUNTER"]      = "ffabd473",  -- Green
    ["ROGUE"]       = "fffff569",  -- Yellow
    ["PRIEST"]      = "ffffffff",  -- White
    ["SHAMAN"]      = "ff0070de",  -- Blue
    ["MAGE"]        = "ff69ccf0",  -- Light Blue
    ["WARLOCK"]     = "ff9482c9",  -- Purple
    ["DRUID"]       = "ffff7d0a",  -- Orange
}

local classColor = CLASS_COLORS[playerClass] or "ffffffff"
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ProcDoc|r Loaded. Tracking procs for |c"..classColor..(UnitClass("player")).."|r. Type |cff00ffff/procdoc|r for options.")
-- 11) Test proc + options frame helpers
local testProcActive = false
local testProcAlertObj = nil
local testProcAlerts = {}  

local function RefreshTestProc()
    for buffName, alertObj in pairs(testProcAlerts) do
        if alertObj.isActive then
            if alertObj.style == "TOP" or alertObj.style == "TOP2" or alertObj.style == "TOP_ROTATED" then
                local tex = alertObj.textures[1]
                tex:ClearAllPoints()
                local offsetY = (alertObj.style == "TOP2") and (topOffset + 50) or topOffset
                tex:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
            elseif alertObj.style == "SIDES" or alertObj.style == "SIDES2" then
                local left = alertObj.textures[1]
                local right = alertObj.textures[2]

                local offsetX = (alertObj.style == "SIDES2") and (sideOffset + 50) or sideOffset
                left:ClearAllPoints()
                left:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)

                right:ClearAllPoints()
                right:SetPoint("CENTER", UIParent, "CENTER", offsetX, topOffset - 150)
            elseif alertObj.style == "LEFT" then
                local tex = alertObj.textures[1]
                tex:ClearAllPoints()
                local offsetX = sideOffset + 50
                tex:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)
            elseif alertObj.style == "RIGHT" then
                local tex = alertObj.textures[1]
                tex:ClearAllPoints()
                local offsetX = sideOffset + 50
                tex:SetPoint("CENTER", UIParent, "CENTER", offsetX, topOffset - 150)
            end
        end
    end

    if testProcActive and testProcAlertObj then
        -- Update base alpha/scale
        if not minAlpha then minAlpha = 0.6 end
        if not maxAlpha then maxAlpha = 1.0 end
        if not minScale then minScale = 0.8 end
        if not maxScale then maxScale = 1.0 end

        -- Re-anchor the test proc based on its style
        if testProcAlertObj.style == "TOP" or testProcAlertObj.style == "TOP2" or testProcAlertObj.style == "TOP_ROTATED" then
            local tex = testProcAlertObj.textures[1]
            tex:ClearAllPoints()
            local offsetY = (testProcAlertObj.style == "TOP2") and (topOffset + 50) or topOffset
            tex:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
        elseif testProcAlertObj.style == "SIDES" or testProcAlertObj.style == "SIDES2" then
            local left = testProcAlertObj.textures[1]
            local right = testProcAlertObj.textures[2]

            local offsetX = (testProcAlertObj.style == "SIDES2") and (sideOffset + 50) or sideOffset
            left:ClearAllPoints()
            left:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)

            right:ClearAllPoints()
            right:SetPoint("CENTER", UIParent, "CENTER", offsetX, topOffset - 150)
        elseif testProcAlertObj.style == "LEFT" then
            local tex = testProcAlertObj.textures[1]
            tex:ClearAllPoints()
            local offsetX = sideOffset + 50
            tex:SetPoint("CENTER", UIParent, "CENTER", -offsetX, topOffset - 150)
        elseif testProcAlertObj.style == "RIGHT" then
            local tex = testProcAlertObj.textures[1]
            tex:ClearAllPoints()
            local offsetX = sideOffset + 50
            tex:SetPoint("CENTER", UIParent, "CENTER", offsetX, topOffset - 150)
        end

        -- Apply alpha & size
        for _, tex in ipairs(testProcAlertObj.textures) do
            tex:SetAlpha(minAlpha)
            tex:SetWidth(testProcAlertObj.baseWidth * minScale)
            tex:SetHeight(testProcAlertObj.baseHeight * minScale)
            tex:Show()
        end

        -- Reset the pulse animation
        testProcAlertObj.pulseAlpha = minAlpha
        testProcAlertObj.pulseDir = alphaStep

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ProcDoc]|r Test proc refreshed with updated offsets.")
    end
end



-- 12) Multi-test alerts (for previewing multiple proc visuals)

local function ShowTestBuffAlert(procInfo)
    local style = procInfo.alertStyle or "SIDES"

    -- Sync current globals from saved DB so test uses persisted values
    if ProcDocDB and ProcDocDB.globalVars then
        local gv = ProcDocDB.globalVars
        if gv.minAlpha then minAlpha = gv.minAlpha end
        if gv.maxAlpha then maxAlpha = gv.maxAlpha end
        if gv.minScale then minScale = gv.minScale end
        if gv.maxScale then maxScale = gv.maxScale end
        if gv.pulseSpeed then pulseSpeed = gv.pulseSpeed end
        if gv.topOffset then topOffset = gv.topOffset end
        if gv.sideOffset then sideOffset = gv.sideOffset end
    end

    -- If this buff's alert is already active, reuse it:
    local alertObj = testProcAlerts[procInfo.buffName]
    if alertObj and alertObj.isActive then
        alertObj.pulseAlpha = minAlpha
        alertObj.pulseDir   = alphaStep
    else
        -- Otherwise, acquire a dedicated test alert frame (isolated from CheckProcs)
        alertObj = AcquireAlertFrame(style, false, true)
        alertObj.isActive    = true
        alertObj.isTest      = true
        alertObj.isDimmed    = false
        alertObj._appliedDim = nil
        alertObj.pulseAlpha  = minAlpha
        alertObj.pulseDir    = alphaStep

        -- Assign textures
        local alertPath = procInfo.alertTexturePath or DEFAULT_ALERT_TEXTURE
        for _, tex in ipairs(alertObj.textures) do
            tex:SetTexture(alertPath)
            if tex.SetDesaturated then tex:SetDesaturated(nil) end
            tex:SetAlpha(minAlpha)
            tex:SetWidth(alertObj.baseWidth * minScale)
            tex:SetHeight(alertObj.baseHeight * minScale)
            tex:Show()
        end
        alertObj._appliedDim = false

        -- Store it so we can hide/update later
        testProcAlerts[procInfo.buffName] = alertObj
    end

    -- Now re-anchor based on style (handles TOP, TOP2, TOP_ROTATED, SIDES, SIDES2, LEFT, RIGHT)
    ProcDoc_ReanchorAlert(alertObj)

    -- Apply final sizing to ensure any reused frame updates (important after reload)
    for _, tex in ipairs(alertObj.textures) do
        tex:SetAlpha(minAlpha)
        tex:SetWidth(alertObj.baseWidth * minScale)
        tex:SetHeight(alertObj.baseHeight * minScale)
    end
    ProcDoc_EnsureOnUpdate()
end



local function HideTestBuffAlert(procInfo)
    local alertObj = testProcAlerts[procInfo.buffName]
    if alertObj then
        alertObj.isActive = false
        for _, tex in ipairs(alertObj.textures) do tex:Hide() end
        if alertObj.timerTexts then
            for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
        end
        if alertObj.stackText then alertObj.stackText:Hide() end
        testProcAlerts[procInfo.buffName] = nil
    end
end

local function HideAllTestAlerts()
    for buffName, alertObj in pairs(testProcAlerts) do
        if alertObj then
            alertObj.isActive = false
            for _, tex in ipairs(alertObj.textures) do tex:Hide() end
            if alertObj.timerTexts then
                for _, fs in ipairs(alertObj.timerTexts) do if fs then fs:Hide() end end
            end
            if alertObj.stackText then alertObj.stackText:Hide() end
        end
        testProcAlerts[buffName] = nil
    end

    if testProcAlertObj and testProcAlertObj.isActive then
        testProcAlertObj.isActive = false
        for _, t in ipairs(testProcAlertObj.textures) do
            t:Hide()
        end
        testProcAlertObj = nil
        testProcActive   = false
    end
end

-- 13) Options UI
local function CreateProcDocOptionsFrame()


    -- Safety: Make sure we have procsEnabled
    if not ProcDocDB then
        ProcDocDB = {}
    end
    if not ProcDocDB.procsEnabled then
        ProcDocDB.procsEnabled = {}
    end
    if not ProcDocDB.globalVars then
        ProcDocDB.globalVars = {}
    end

    -- Sync current tuning globals from saved DB BEFORE first-time slider creation
    do
        local gv = ProcDocDB.globalVars
        if gv.minAlpha      ~= nil then minAlpha    = gv.minAlpha end
        if gv.maxAlpha      ~= nil then maxAlpha    = gv.maxAlpha end
        if gv.minScale      ~= nil then minScale    = gv.minScale end
        if gv.maxScale      ~= nil then maxScale    = gv.maxScale end
        if gv.pulseSpeed    ~= nil then pulseSpeed  = gv.pulseSpeed end
        if gv.topOffset     ~= nil then topOffset   = gv.topOffset end
        if gv.sideOffset    ~= nil then sideOffset  = gv.sideOffset end
        -- Backwards compatibility: if old field names existed, migrate (example: maxSize->maxScale)
        if gv.maxSize and not gv.maxScale then
            maxScale = gv.maxSize
            gv.maxScale = gv.maxSize
            gv.maxSize = nil
        end
    end
    
    if not ProcDocOptionsFrame then
        local f = CreateFrame("Frame", "ProcDocOptionsFrame", UIParent)
        f:SetWidth(340)
        -- Height will be set dynamically later once we know proc count
        f:SetHeight(600)
        f:SetPoint("CENTER", UIParent, "CENTER", -360, 0)
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true,
            tileSize = 16,
            edgeSize = 16,
            insets   = { left=4, right=4, top=4, bottom=4 },
        })
        f:SetBackdropColor(0, 0, 0, 0.8)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        f:SetScript("OnHide", function() HideAllTestAlerts() end)
        
    -- Top (static) settings section (sliders / primary checkboxes)
        local TOP_SECTION_HEIGHT = 505  -- space for all sliders & two rows of checkboxes
        local sectionFrame = CreateFrame("Frame", nil, f)
        sectionFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -30)
        sectionFrame:SetWidth(f:GetWidth() - 30)
        sectionFrame:SetHeight(TOP_SECTION_HEIGHT)
        sectionFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        sectionFrame:SetBackdropColor(0.2, 0.2, 0.2, 1)
        sectionFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        table.insert(UISpecialFrames, "ProcDocOptionsFrame")



    -- Title
        local titleFrame = CreateFrame("Frame", nil, f)
        titleFrame:SetPoint("TOP", f, "TOP", 0, 12)
        titleFrame:SetWidth(256)
        titleFrame:SetHeight(64)

        local titleTex = titleFrame:CreateTexture(nil, "OVERLAY")
        titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        titleTex:SetAllPoints()

        local title = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetText("|cff00ff00[ProcDoc]|r Options")
        title:SetPoint("TOP", 0, -14)

        -- Update live active proc frames (non-test) with new sizing/alpha values
        local function UpdateLiveProcs()
            for _, alertObj in ipairs(alertFrames) do
                if alertObj.isActive then
                    alertObj.pulseAlpha = minAlpha
                    alertObj.pulseDir = alphaStep
        
                    for _, tex in ipairs(alertObj.textures) do
                        tex:SetAlpha(minAlpha)
                        tex:SetWidth(alertObj.baseWidth * minScale)
                        tex:SetHeight(alertObj.baseHeight * minScale)
                    end
                end
            end
        end

        -- Update any active test proc preview frames immediately as sliders move
        local function UpdateTestAlertsPositions()
            for _, alertObj in pairs(testProcAlerts) do
                if alertObj.isActive then
                    ProcDoc_ReanchorAlert(alertObj)
                    -- Apply size/alpha baseline
                    for _, tex in ipairs(alertObj.textures) do
                        tex:SetAlpha(minAlpha)
                        tex:SetWidth(alertObj.baseWidth * minScale)
                        tex:SetHeight(alertObj.baseHeight * minScale)
                    end
                end
            end
        end
        

    -- Min transparency slider
        local sliderLabel1 = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sliderLabel1:SetPoint("TOPLEFT", 10, -10)
        sliderLabel1:SetText("Min Transparency:")
        
        local minTransSlider = CreateFrame("Slider", "ProcDocMinTransSlider", f, "OptionsSliderTemplate")
        minTransSlider:SetPoint("TOPLEFT", 20, -60)
        minTransSlider:SetWidth(300)
        minTransSlider:SetMinMaxValues(0, 1)
        minTransSlider:SetValueStep(0.05)
    minTransSlider:SetValue(minAlpha)

        local low1  = getglobal(minTransSlider:GetName().."Low")
        local high1 = getglobal(minTransSlider:GetName().."High")
        local txt1  = getglobal(minTransSlider:GetName().."Text")

        if low1  then low1:SetText("0") end
        if high1 then high1:SetText("1") end
        if txt1  then txt1:SetText(string.format("%.2f", minAlpha)) end

        -- Using older style: no arguments, use `this`
        minTransSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()

            if not minAlpha then minAlpha = 0.6 end
            if not maxAlpha then maxAlpha = 1.0 end

            if value >= maxAlpha then
                value = maxAlpha - 0.01
                if value < 0 then value = 0 end
            end
            minAlpha = value

            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.minAlpha = minAlpha
            end

            local localText = getglobal(slider:GetName().."Text")
            if localText then
                localText:SetText(string.format("%.2f", value))
            end

            UpdateLiveProcs(); UpdateTestAlertsPositions()
        end)

    -- Max transparency slider
        local sliderLabel2 = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sliderLabel2:SetPoint("TOPLEFT", 10, -70)
        sliderLabel2:SetText("Max Transparency:")

        local maxTransSlider = CreateFrame("Slider", "ProcDocMaxTransSlider", f, "OptionsSliderTemplate")
        maxTransSlider:SetPoint("TOPLEFT", 20, -120)
        maxTransSlider:SetWidth(300)
        maxTransSlider:SetMinMaxValues(0, 1)
        maxTransSlider:SetValueStep(0.05)
    maxTransSlider:SetValue(maxAlpha)

        local low2  = getglobal(maxTransSlider:GetName().."Low")
        local high2 = getglobal(maxTransSlider:GetName().."High")
        local txt2  = getglobal(maxTransSlider:GetName().."Text")

        if low2  then low2:SetText("0") end
        if high2 then high2:SetText("1") end
        if txt2  then txt2:SetText(string.format("%.2f", maxAlpha)) end

        maxTransSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()

            if not minAlpha then minAlpha = 0.6 end

            if value <= minAlpha then
                value = minAlpha + 0.01
                if value > 1 then value = 1 end
            end
            maxAlpha = value
            
            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.maxAlpha = maxAlpha
            end

            local localText = getglobal(slider:GetName().."Text")
            if localText then
                localText:SetText(string.format("%.2f", value))
            end

            UpdateLiveProcs(); UpdateTestAlertsPositions()
        end)

    -- Min size slider
        local sizeLabel1 = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sizeLabel1:SetPoint("TOPLEFT", 10, -130)
        sizeLabel1:SetText("Min Size:")

        local minSizeSlider = CreateFrame("Slider", "ProcDocMinSizeSlider", f, "OptionsSliderTemplate")
        minSizeSlider:SetPoint("TOPLEFT", 20, -180)
        minSizeSlider:SetWidth(300)
        minSizeSlider:SetMinMaxValues(0.5, 2)
        minSizeSlider:SetValueStep(0.05)
    minSizeSlider:SetValue(minScale)

        local low3  = getglobal(minSizeSlider:GetName().."Low")
        local high3 = getglobal(minSizeSlider:GetName().."High")
        local txt3  = getglobal(minSizeSlider:GetName().."Text")

        if low3  then low3:SetText("0.5") end
        if high3 then high3:SetText("2.0") end
        if txt3  then txt3:SetText(string.format("%.2f", minScale)) end

        minSizeSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()

            if not maxScale then maxScale = 1.0 end

            if value >= maxScale then
                value = maxScale - 0.01
                if value < 0.5 then value = 0.5 end
            end
            minScale = value

            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.minScale = minScale
            end

            local localText = getglobal(slider:GetName().."Text")
            if localText then
                localText:SetText(string.format("%.2f", value))
            end

            UpdateLiveProcs(); UpdateTestAlertsPositions()
        end)

    -- Max size slider
        local sizeLabel2 = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sizeLabel2:SetPoint("TOPLEFT", 10, -190)
        sizeLabel2:SetText("Max Size:")

        local maxSizeSlider = CreateFrame("Slider", "ProcDocMaxSizeSlider", f, "OptionsSliderTemplate")
        maxSizeSlider:SetPoint("TOPLEFT", 20, -240)
        maxSizeSlider:SetWidth(300)
        maxSizeSlider:SetMinMaxValues(0.5, 2)
        maxSizeSlider:SetValueStep(0.05)
    maxSizeSlider:SetValue(maxScale)

        local low4  = getglobal(maxSizeSlider:GetName().."Low")
        local high4 = getglobal(maxSizeSlider:GetName().."High")
        local txt4  = getglobal(maxSizeSlider:GetName().."Text")

        if low4  then low4:SetText("0.5") end
        if high4 then high4:SetText("2.0") end
        if txt4  then txt4:SetText(string.format("%.2f", maxScale)) end

        maxSizeSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()

            if not minScale then minScale = 0.8 end

            if value <= minScale then
                value = minScale + 0.01
                if value > 2 then value = 2 end
            end
            maxScale = value

            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.maxScale = maxScale
            end

            local localText = getglobal(slider:GetName().."Text")
            if localText then
                localText:SetText(string.format("%.2f", value))
            end

            UpdateLiveProcs(); UpdateTestAlertsPositions()
        end)

    -- Pulse speed slider

        local speedLabel = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        speedLabel:SetPoint("TOPLEFT", 10, -250)
        speedLabel:SetText("Pulse Speed:")

        local pulseSpeedSlider = CreateFrame("Slider", "ProcDocPulseSpeedSlider", f, "OptionsSliderTemplate")
        pulseSpeedSlider:SetPoint("TOPLEFT", 20, -300)
        pulseSpeedSlider:SetWidth(300)
        pulseSpeedSlider:SetMinMaxValues(0.1, 5.0)
        pulseSpeedSlider:SetValueStep(0.1)
    pulseSpeedSlider:SetValue(pulseSpeed)

        local lowSpeed  = getglobal(pulseSpeedSlider:GetName().."Low")
        local highSpeed = getglobal(pulseSpeedSlider:GetName().."High")
        local txtSpeed  = getglobal(pulseSpeedSlider:GetName().."Text")
        if lowSpeed  then lowSpeed:SetText("0.1") end
        if highSpeed then highSpeed:SetText("5.0") end
        if txtSpeed  then txtSpeed:SetText(string.format("%.2f", pulseSpeed)) end

        pulseSpeedSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()

            pulseSpeed = value  -- store globally

            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.pulseSpeed = pulseSpeed
            end
        
            -- Update label
            local labelObj = getglobal(slider:GetName().."Text")
            if labelObj then
                labelObj:SetText(string.format("%.2f", value))
            end
    end)

        local function ReanchorAllLiveProcs()
            for _, alertObj in ipairs(alertFrames) do
                if alertObj.isActive then
                    ProcDoc_ReanchorAlert(alertObj)
                end
            end
        end

    -- Top offset slider
        local topLabel = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        topLabel:SetPoint("TOPLEFT", 10, -310)
        topLabel:SetText("Top Offset:")

        local topOffsetSlider = CreateFrame("Slider", "ProcDocTopOffsetSlider", f, "OptionsSliderTemplate")
        topOffsetSlider:SetPoint("TOPLEFT", 20, -360)
        topOffsetSlider:SetWidth(300)
        topOffsetSlider:SetMinMaxValues(0, 300)    -- e.g. range 0 -> 300
        topOffsetSlider:SetValueStep(10)
    topOffsetSlider:SetValue(topOffset)        -- current global

        local lowT  = getglobal(topOffsetSlider:GetName().."Low")
        local highT = getglobal(topOffsetSlider:GetName().."High")
        local txtT  = getglobal(topOffsetSlider:GetName().."Text")
        if lowT  then lowT:SetText("0")   end
        if highT then highT:SetText("300") end
        if txtT  then txtT:SetText(tostring(topOffset)) end

        topOffsetSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()
            topOffset = value
            if txtT then
                txtT:SetText(tostring(value))
            end

            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.topOffset = topOffset
            end

            ReanchorAllLiveProcs(); UpdateTestAlertsPositions()
        end)

    -- Side offset slider
        local sideLabel = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sideLabel:SetPoint("TOPLEFT", 10, -370)
        sideLabel:SetText("Side Offset:")

        local sideOffsetSlider = CreateFrame("Slider", "ProcDocSideOffsetSlider", f, "OptionsSliderTemplate")
        sideOffsetSlider:SetPoint("TOPLEFT", 20, -420)
        sideOffsetSlider:SetWidth(300)
        sideOffsetSlider:SetMinMaxValues(0, 300)    -- e.g. range 0 -> 300
        sideOffsetSlider:SetValueStep(10)
    sideOffsetSlider:SetValue(sideOffset)

        local lowS  = getglobal(sideOffsetSlider:GetName().."Low")
        local highS = getglobal(sideOffsetSlider:GetName().."High")
        local txtS  = getglobal(sideOffsetSlider:GetName().."Text")
        if lowS  then lowS:SetText("0")   end
        if highS then highS:SetText("300") end
        if txtS  then txtS:SetText(tostring(sideOffset)) end

        sideOffsetSlider:SetScript("OnValueChanged", function()
            local slider = this
            local value  = slider:GetValue()
            sideOffset = value
            if txtS then
                txtS:SetText(tostring(value))
            end
            
            -- SAVE to DB:
            if ProcDocDB and ProcDocDB.globalVars then
                ProcDocDB.globalVars.sideOffset = sideOffset
            end


            ReanchorAllLiveProcs(); UpdateTestAlertsPositions()
        end)

    -- Mute checkbox
    local muteCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    muteCheck:SetPoint("TOPLEFT", sectionFrame, "TOPLEFT", 5, -420)
        muteCheck:SetWidth(24)
        muteCheck:SetHeight(24)

        local muteLabel = muteCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        muteLabel:SetPoint("LEFT", muteCheck, "RIGHT", 4, 0)
        muteLabel:SetText("Mute All Proc Sounds")

        -- Initialize check mark based on DB:
        muteCheck:SetChecked(ProcDocDB.globalVars.isMuted)

        muteCheck:SetScript("OnClick", function()
            if muteCheck:GetChecked() then
                ProcDocDB.globalVars.isMuted = true
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFProcDoc|r: Sounds are now muted.")
            else
                ProcDocDB.globalVars.isMuted = false
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFProcDoc|r: Sounds are now unmuted.")
            end
        end)

    -- Disable timers checkbox
    local timerCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    timerCheck:SetPoint("LEFT", muteCheck, "RIGHT", 140, 0) -- place to the right of mute
        timerCheck:SetWidth(24)
        timerCheck:SetHeight(24)
        local timerLabel = timerCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timerLabel:SetPoint("LEFT", timerCheck, "RIGHT", 4, 0)
        timerLabel:SetText("Disable Timers")
        timerCheck:SetChecked(ProcDocDB.globalVars.disableTimers)
        timerCheck:SetScript("OnClick", function()
            if timerCheck:GetChecked() then
                ProcDocDB.globalVars.disableTimers = true
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFProcDoc|r: Timers disabled.")
                -- Hide any current timer/stack texts immediately
                for _, aObj in ipairs(alertFrames) do
                    if aObj.timerTexts then
                        for _, fs in ipairs(aObj.timerTexts) do if fs then fs:Hide() end end
                    end
                    if aObj.stackText then aObj.stackText:Hide() end
                    aObj.hasTimer = false
                end
            else
                ProcDocDB.globalVars.disableTimers = false
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFProcDoc|r: Timers enabled.")
            end
        end)

    -- Dim low-resource / wrong-stance checkbox (Option A)
    local dimCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    dimCheck:SetPoint("TOPLEFT", muteCheck, "BOTTOMLEFT", 0, -2)
        dimCheck:SetWidth(24)
        dimCheck:SetHeight(24)
        local dimLabel = dimCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dimLabel:SetPoint("LEFT", dimCheck, "RIGHT", 4, 0)
        dimLabel:SetText("Dim Low Resource")
        dimCheck:SetChecked(ProcDocDB.globalVars.dimOnLowResource ~= false)
        dimCheck:SetScript("OnClick", function()
            ProcDocDB.globalVars.dimOnLowResource = dimCheck:GetChecked() and true or false
            CheckAllActionProcs()
        end)

    -- Decimal timers (< 5s) checkbox
    local decCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    decCheck:SetPoint("LEFT", dimCheck, "RIGHT", 140, 0)
        decCheck:SetWidth(24)
        decCheck:SetHeight(24)
        local decLabel = decCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        decLabel:SetPoint("LEFT", decCheck, "RIGHT", 4, 0)
        decLabel:SetText("Decimal Timers")
        decCheck:SetChecked(ProcDocDB.globalVars.decimalTimers ~= false)
        decCheck:SetScript("OnClick", function()
            ProcDocDB.globalVars.decimalTimers = decCheck:GetChecked() and true or false
        end)

    -- Combat Only checkbox
    local combatCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    combatCheck:SetPoint("TOPLEFT", dimCheck, "BOTTOMLEFT", 0, -2)
        combatCheck:SetWidth(24)
        combatCheck:SetHeight(24)
        local combatLabel = combatCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        combatLabel:SetPoint("LEFT", combatCheck, "RIGHT", 4, 0)
        combatLabel:SetText("Combat Only")
        combatCheck:SetChecked(ProcDocDB.globalVars.combatOnly and true or false)
        combatCheck:SetScript("OnClick", function()
            ProcDocDB.globalVars.combatOnly = combatCheck:GetChecked() and true or false
            CheckProcs()
            CheckAllActionProcs()
            UpdateSpellbookActionProcs()
        end)

    -- Dynamic proc list section
        local testLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        testLabel:SetText("|cffffffffProc Animations to Show for " .. (UnitClass("player")) .. "|r")

        local sectionFrame2 = CreateFrame("Frame", nil, f)
        sectionFrame2:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        sectionFrame2:SetBackdropColor(0.2, 0.2, 0.2, 1)
        sectionFrame2:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        local numProcs = 0
        for _ in ipairs(classProcs) do numProcs = numProcs + 1 end
        local ROW_HEIGHT = 28
        local LIST_EXTRA_PADDING = 10 -- padding inside frame
        local listHeight = (numProcs * ROW_HEIGHT) + LIST_EXTRA_PADDING
        if listHeight < 36 then listHeight = 36 end

        -- Anchor the dynamic list directly below the top section
        sectionFrame2:ClearAllPoints()
        sectionFrame2:SetPoint("TOPLEFT", sectionFrame, "BOTTOMLEFT", 0, -20)
        sectionFrame2:SetWidth(sectionFrame:GetWidth())
        sectionFrame2:SetHeight(listHeight)

        -- Position label inside sectionFrame2
        testLabel:ClearAllPoints()
        testLabel:SetPoint("TOPLEFT", sectionFrame2, "TOPLEFT", 5, 13)

        local firstCheckY = -25  -- relative to sectionFrame2 top
    -- Table to hold references to each buff's checkbox
    local checkBoxes = {}

    -- Build checkbox list
        local idx = 0
        for _, procInfo in ipairs(classProcs) do
            idx = idx + 1
            local check = CreateFrame("CheckButton", nil, sectionFrame2, "UICheckButtonTemplate")
            check:SetHeight(24)
            check:SetWidth(24)
            check:ClearAllPoints()
            local yOff = firstCheckY - ((idx - 1) * ROW_HEIGHT - 19)
            check:SetPoint("TOPLEFT", sectionFrame2, "TOPLEFT", 5, yOff)

            local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", check, "RIGHT", 4, 0)
            label:SetText(procInfo.buffName)

            local localProcInfo = procInfo
            checkBoxes[localProcInfo.buffName] = check
            check:SetScript("OnClick", function()
                local bName = localProcInfo.buffName
                local isChecked = check:GetChecked()
                if not bName then return end
                if isChecked then
                    ProcDocDB.procsEnabled[bName] = true
                else
                    ProcDocDB.procsEnabled[bName] = false
                end
                CheckProcs()
                CheckAllActionProcs()
                UpdateSpellbookActionProcs()
            end)
            local isEnabled = (ProcDocDB.procsEnabled[procInfo.buffName] ~= false)
            check:SetChecked(isEnabled)
        end

    -- Recompute full frame height now that we know list height
        local BUTTON_BLOCK_HEIGHT = 70 -- space for buttons + padding
        local totalHeight = 30 + TOP_SECTION_HEIGHT + 10 + listHeight + BUTTON_BLOCK_HEIGHT + 20
        if totalHeight < 520 then totalHeight = 520 end -- minimum so sliders area not cramped
        f:SetHeight(totalHeight)

    -- Test proc button (shows alerts for all checked procs)
    local testButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    testButton:ClearAllPoints()
    testButton:SetPoint("TOPLEFT", sectionFrame2, "BOTTOMLEFT", 5, -45)
        testButton:SetWidth(120)
        testButton:SetHeight(25)
        testButton:SetText("Test Proc")

        -- Replace old logic with:
        testButton:SetScript("OnClick", function()
            for _, procInfo in ipairs(classProcs) do
                local c = checkBoxes[procInfo.buffName]
                if c and c:GetChecked() then
                    ShowTestBuffAlert(procInfo)
                else
                    HideTestBuffAlert(procInfo)
                end
            end
        end)

    -- Reset defaults button
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("TOPRIGHT", sectionFrame2, "BOTTOMRIGHT", -5, -45)
        resetBtn:SetWidth(120)
        resetBtn:SetHeight(25)
        resetBtn:SetText("Reset Defaults")
        resetBtn:SetScript("OnClick", function()
            ProcDoc_EnsureDB()
            local gv = ProcDocDB.globalVars
            gv.minAlpha         = 0.8
            gv.maxAlpha         = 1.0
            gv.minScale         = 0.9
            gv.maxScale         = 1.0
            gv.pulseSpeed       = 0.4
            gv.topOffset        = 70
            gv.sideOffset       = 60
            gv.isMuted          = false
            gv.disableTimers    = false
            gv.dimOnLowResource = true
            gv.decimalTimers    = true
            gv.combatOnly       = false
            ProcDoc_LoadGlobalsFromDB()
            minTransSlider:SetValue(minAlpha)
            maxTransSlider:SetValue(maxAlpha)
            minSizeSlider:SetValue(minScale)
            maxSizeSlider:SetValue(maxScale)
            pulseSpeedSlider:SetValue(pulseSpeed)
            topOffsetSlider:SetValue(topOffset)
            sideOffsetSlider:SetValue(sideOffset)
            muteCheck:SetChecked(false)
            timerCheck:SetChecked(false)
            dimCheck:SetChecked(true)
            decCheck:SetChecked(true)
            combatCheck:SetChecked(false)
            ReanchorAllLiveProcs(); UpdateTestAlertsPositions()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ProcDoc]|r Settings reset to defaults.")
        end)

    -- Hide all test alerts button
    local hideAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    hideAllBtn:ClearAllPoints()
    hideAllBtn:SetPoint("TOPLEFT", sectionFrame2, "BOTTOMLEFT", 5, -15)
        hideAllBtn:SetWidth(120)
        hideAllBtn:SetHeight(25)
        hideAllBtn:SetText("Hide All")
        hideAllBtn:SetScript("OnClick", function()
            HideAllTestAlerts()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ProcDoc]|r All test buff alerts hidden.")
        end)

    -- Close button
    local closeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPRIGHT", sectionFrame2, "BOTTOMRIGHT", -5, -15)
        closeButton:SetWidth(120)
        closeButton:SetHeight(25)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            HideAllTestAlerts()
            f:Hide()
        end)
        
    end

    ProcDocOptionsFrame:Show()
    
end


-- 14) Slash command
local function ProcDoc_Say(m)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffProcDoc|r "..m)
end

local function ProcDoc_SourceName()
    if ProcDoc_UsingNampowerApi() then return "Nampower (buffcap-safe)" end
    if ProcDoc_UsingAuraApi() then return "aura API (ClassicAPI)" end
    return "tooltip scan"
end

local function ProcDoc_Status()
    ProcDoc_EnsureDB()
    local gv = ProcDocDB.globalVars
    local why = ""
    if gv.auraSource == "tooltip" then
        why = " (forced by /procdoc source tooltip)"
    elseif gv.auraSource == "aura" then
        why = " (forced by /procdoc source aura)"
    elseif gv.auraSource == "nampower" then
        why = " (forced by /procdoc source nampower)"
    elseif procDocNampowerFailed then
        why = " (Nampower buff API failed earlier this session)"
    elseif procDocAuraFailed then
        why = " (aura API failed earlier this session)"
    elseif (not ProcDoc_NampowerBuffApiPresent()) and (not ProcDoc_AuraApiPresent()) then
        why = " (Nampower / ClassicAPI aura API not found)"
    end
    ProcDoc_Say("buff source: "..ProcDoc_SourceName()..why)
    ProcDoc_Say("pulse reference frame rate: "..tostring(gv.pulseReferenceFps or 60).." FPS; sound "
        ..(gv.isMuted and "muted" or "on")..", timers "..(gv.disableTimers and "off" or "on")
        ..", decimals "..((gv.decimalTimers ~= false) and "on" or "off")
        ..", low-resource "..((gv.dimOnLowResource ~= false) and "dim" or "hide")
        ..", combat-only "..(gv.combatOnly and "on" or "off"))
end

-- Reads the player's buffs with both methods and reports whether they agree, so the aura API can be
-- verified on a real client with one command.
local function ProcDoc_Scan()
    local tList, tN = ProcDoc_ReadBuffsTooltip()
    local aList, aN
    if ProcDoc_AuraApiPresent() then
        local ok, l, n = pcall(ProcDoc_ReadBuffsAura)
        if ok then aList, aN = l, n end
    end
    ProcDoc_Say("buffs by tooltip: "..tN..(aList and ("   by aura API: "..aN) or "   (aura API not available)"))
    for i = 1, tN do
        local r = tList[i]
        local tl = (r.tl and r.tl > 0) and string.format("%.1fs", r.tl) or "-"
        local stk = ((r.api or r.stack or 0) > 0) and (" x"..(r.api or r.stack)) or ""
        DEFAULT_CHAT_FRAME:AddMessage("   "..tostring(r.name).." | "..tostring(string.gsub(r.tex or "", "^.*\\", "")).." | "..tl..stk)
    end
    if not aList then return end
    local byName = {}
    for i = 1, aN do
        if byName[aList[i].name] == nil then byName[aList[i].name] = aList[i] end
    end
    local diffs = 0
    for i = 1, tN do
        local r = tList[i]
        local a = byName[r.name]
        if not a then
            diffs = diffs + 1
            DEFAULT_CHAT_FRAME:AddMessage("   |cffff8800only in tooltip scan:|r "..tostring(r.name))
        else
            if not ProcDoc_TexEqual(a, r.tex) then
                diffs = diffs + 1
                DEFAULT_CHAT_FRAME:AddMessage("   |cffff8800icon differs for|r "..tostring(r.name)..": "..tostring(r.tex).." vs "..tostring(a.tex))
            end
            local tt, at = (r.tl or 0), (a.tl or 0)
            if (tt > 0 or at > 0) and math.abs(tt - at) > 1.5 then
                diffs = diffs + 1
                DEFAULT_CHAT_FRAME:AddMessage("   |cffff8800time left differs for|r "..tostring(r.name)..": "..string.format("%.1f vs %.1f", tt, at))
            end
            byName[r.name] = nil
        end
    end
    for name in pairs(byName) do
        diffs = diffs + 1
        DEFAULT_CHAT_FRAME:AddMessage("   |cffff8800only in aura API:|r "..tostring(name))
    end
    if diffs == 0 then
        ProcDoc_Say("both methods agree.")
    else
        ProcDoc_Say(diffs.." difference(s). If procs misbehave, use /procdoc source tooltip.")
    end
end

local VALID_CUSTOM_STYLES = {
    ["TOP"] = true, ["TOP2"] = true, ["TOP_ROTATED"] = true,
    ["SIDES"] = true, ["SIDES2"] = true, ["LEFT"] = true, ["RIGHT"] = true,
}

SLASH_PROCDOC1 = "/procdoc"
SlashCmdList["PROCDOC"] = function(msg)
    local raw = msg or ""
    local _, _, rawCmd, rawRest = string.find(raw, "^%s*(%S+)%s*(.-)%s*$")
    local cmd  = rawCmd and string.lower(rawCmd) or nil
    local rest = rawRest and string.lower(rawRest) or ""
    if cmd == "scan" then
        ProcDoc_Scan()
    elseif cmd == "status" then
        ProcDoc_Status()
    elseif cmd == "trace" then
        procDocTrace = not procDocTrace
        ProcDoc_Say("debug trace " .. (procDocTrace and "ON" or "OFF"))
    elseif cmd == "add" then
        ProcDoc_EnsureDB()
        if not rawRest or rawRest == "" then
            ProcDoc_Say("usage: /procdoc add <Exact Buff Name> [TOP|TOP2|SIDES|SIDES2|LEFT|RIGHT]")
            return
        end
        local bName = rawRest
        local style = "SIDES"
        local _, _, head, tail = string.find(rawRest, "^(.-)%s+(%S+)$")
        if head and head ~= "" and tail and VALID_CUSTOM_STYLES[string.upper(tail)] then
            bName = head
            style = string.upper(tail)
        end
        ProcDocDB.customProcs[bName] = {
            buffName         = bName,
            texture          = nil,
            alertTexturePath = DEFAULT_ALERT_TEXTURE,
            alertStyle       = style,
        }
        ProcDocDB.procsEnabled[bName] = true
        ProcDoc_Say("added custom buff proc '"..bName.."' (style: "..style..").")
        CheckProcs()
    elseif cmd == "remove" then
        ProcDoc_EnsureDB()
        if not rawRest or rawRest == "" then
            ProcDoc_Say("usage: /procdoc remove <Exact Buff Name>")
            return
        end
        local foundKey = nil
        if ProcDocDB.customProcs[rawRest] then
            foundKey = rawRest
        else
            local targetLower = string.lower(rawRest)
            for k in pairs(ProcDocDB.customProcs) do
                if string.lower(k) == targetLower then foundKey = k break end
            end
        end
        if foundKey then
            ProcDocDB.customProcs[foundKey] = nil
            ProcDoc_Say("removed custom buff proc '"..foundKey.."'.")
            CheckProcs()
        else
            ProcDoc_Say("custom proc not found: '"..rawRest.."'.")
        end
    elseif cmd == "list" then
        ProcDoc_EnsureDB()
        local count = 0
        for k, v in pairs(ProcDocDB.customProcs) do
            count = count + 1
            DEFAULT_CHAT_FRAME:AddMessage("   "..k.." ("..tostring(v.alertStyle or "SIDES")..")")
        end
        if count == 0 then
            ProcDoc_Say("no custom procs added. Use /procdoc add <Buff Name> [style].")
        else
            ProcDoc_Say(count.." custom proc(s) tracked.")
        end
    elseif cmd == "combat" then
        ProcDoc_EnsureDB()
        if rest == "on" then
            ProcDocDB.globalVars.combatOnly = true
            ProcDoc_Say("combat-only mode enabled.")
            CheckProcs(); CheckAllActionProcs(); UpdateSpellbookActionProcs()
        elseif rest == "off" then
            ProcDocDB.globalVars.combatOnly = false
            ProcDoc_Say("combat-only mode disabled.")
            CheckProcs(); CheckAllActionProcs(); UpdateSpellbookActionProcs()
        else
            ProcDoc_Say("usage: /procdoc combat on | off   (now "..(ProcDocDB.globalVars.combatOnly and "on" or "off")..")")
        end
    elseif cmd == "source" then
        ProcDoc_EnsureDB()
        if rest == "auto" or rest == "nampower" or rest == "aura" or rest == "tooltip" then
            ProcDocDB.globalVars.auraSource = rest
            ProcDoc_Say("buff source set to "..rest..". Now using: "..ProcDoc_SourceName())
            CheckProcs()
        else
            ProcDoc_Say("usage: /procdoc source auto | nampower | aura | tooltip   (now using: "..ProcDoc_SourceName()..")")
        end
    elseif cmd == "resource" then
        ProcDoc_EnsureDB()
        if rest == "dim" then
            ProcDocDB.globalVars.dimOnLowResource = true
            ProcDoc_Say("low-resource / wrong-stance reactive procs will show dimmed.")
            CheckAllActionProcs()
        elseif rest == "hide" then
            ProcDocDB.globalVars.dimOnLowResource = false
            ProcDoc_Say("low-resource / wrong-stance reactive procs will be hidden.")
            CheckAllActionProcs()
        else
            ProcDoc_Say("usage: /procdoc resource dim | hide   (now "..((ProcDocDB.globalVars.dimOnLowResource ~= false) and "dim" or "hide")..")")
        end
    elseif cmd == "decimals" then
        ProcDoc_EnsureDB()
        if rest == "on" then
            ProcDocDB.globalVars.decimalTimers = true
            ProcDoc_Say("decimal timers (< 5s) enabled.")
        elseif rest == "off" then
            ProcDocDB.globalVars.decimalTimers = false
            ProcDoc_Say("decimal timers disabled (whole seconds only).")
        else
            ProcDoc_Say("usage: /procdoc decimals on | off   (now "..((ProcDocDB.globalVars.decimalTimers ~= false) and "on" or "off")..")")
        end
    elseif cmd == "pulsefps" then
        ProcDoc_EnsureDB()
        local n = tonumber(rest)
        if n and n >= 10 and n <= 500 then
            ProcDocDB.globalVars.pulseReferenceFps = n
            ProcDoc_Say("pulse speed is now calibrated to "..n.." FPS (a lower number makes pulsing slower).")
        else
            ProcDoc_Say("usage: /procdoc pulsefps <10-500>   (now "..tostring(ProcDocDB.globalVars.pulseReferenceFps or 60)..")")
        end
    elseif cmd == "help" or cmd == "?" then
        ProcDoc_Say("/procdoc - options | add/remove/list | combat on|off | resource dim|hide | decimals on|off | source | scan | status | trace | pulsefps <n>")
    else
        CreateProcDocOptionsFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffProcDoc|r Options opened")
    end
end
