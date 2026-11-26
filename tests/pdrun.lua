-- usage: texlua pdrun.lua <addon_dir> <scenario>   ->  RESULT|name|PASS/FAIL|detail   and  SIG|name|<visible state>
PD_DIR = arg[1]; local want = arg[2]
local SD = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
dofile(SD .. "/pdenv.lua")
local CLASSNAME = { WARRIOR = "Warrior", MAGE = "Mage", DRUID = "Druid", PALADIN = "Paladin", ROGUE = "Rogue", HUNTER = "Hunter", PRIEST = "Priest", SHAMAN = "Shaman", WARLOCK = "Warlock" }
function boot(class)
  W.class = class; W.className = CLASSNAME[class]
  LoadAddon(); FireEvent("VARIABLES_LOADED"); FireEvent("PLAYER_LOGIN"); Tick(1 / 60, 3)
end
local function noerr(m) if #ERRORS > 0 then error((m or "errors") .. ": " .. ERRORS[1].where .. " -> " .. ERRORS[1].msg:sub(1, 300), 0) end end
local function check(c, m) if not c then error(m or "check failed", 0) end end
local function vis() return Visible() end
local function count(prefix) local n = 0 for _, l in ipairs(vis()) do if l:sub(1, #prefix) == prefix then n = n + 1 end end return n end
local function has(sub) for _, l in ipairs(vis()) do if l:find(sub, 1, true) then return true end end return false end
local function timerText() for _, l in ipairs(vis()) do if l:sub(1, 2) == "F " then return tonumber(l:sub(3)) end end end
local CC = "Interface\\Icons\\Spell_Shadow_ManaBurn"
local function frames60(sec) Tick(1 / 60, math.floor(sec * 60 + 0.5)) end
local function ev(e, a, b) FireEvent(e, a, b) end
local function putAction(slot, tex, usable) W.actions[slot] = tex; W.usable[slot] = usable; FireEvent("ACTIONBAR_SLOT_CHANGED", slot) end
local function auras() ev("PLAYER_AURAS_CHANGED") end
local S = {}

S.load_each_class = function()
  boot("MAGE"); noerr("load"); check(CHAT[1] and CHAT[1]:find("Tracking procs for"), "greeting printed")
  return "loads, greeting ok"
end
S.mage_proc = function()
  boot("MAGE"); Buff(2, "Clearcasting", CC, 15); auras(); frames60(0.5); noerr("proc")
  check(has("DruidClearcasting.tga"), "alert texture shown"); check(STATS.sound == 1, "one sound")
  check(timerText() == 14, "timer shows 14, got " .. tostring(timerText()))
  W.buffs[2] = nil; auras(); frames60(0.1); check(#vis() == 0, "alert hidden after buff ends: " .. table.concat(vis(), ";"))
  return "show, timer, hide"
end
S.proc_disabled = function()
  boot("MAGE"); ProcDocDB.procsEnabled["Clearcasting"] = false; Buff(2, "Clearcasting", CC, 15); auras(); frames60(0.3); noerr("x")
  check(#vis() == 0, "disabled proc shows nothing"); check(STATS.sound == 0, "no sound")
  return "disabled proc silent"
end
S.wrong_texture_ignored = function()
  boot("MAGE"); Buff(2, "Clearcasting", "Interface\\Icons\\Some_Other_Icon", 15); auras(); frames60(0.3); noerr("x")
  check(#vis() == 0, "same name, different icon: no alert")
  return "texture mismatch ignored"
end
S.sound_once = function()
  boot("MAGE"); Buff(2, "Clearcasting", CC, 15)
  for i = 1, 4 do auras(); frames60(0.1) end
  check(STATS.sound == 1, "sound once, got " .. STATS.sound)
  W.buffs[2] = nil; auras(); frames60(0.1); Buff(2, "Clearcasting", CC, 15); auras(); frames60(0.1)
  check(STATS.sound == 2, "replays after it really fell off, got " .. STATS.sound)
  for i = 1, 3 do auras() end
  check(STATS.sound == 2, "and again not on repeated events, got " .. STATS.sound)
  return "sound once per proc"
end
S.sound_muted = function()
  boot("MAGE"); ProcDocDB.globalVars.isMuted = true; Buff(2, "Clearcasting", CC, 15); auras(); frames60(0.1)
  check(STATS.sound == 0, "muted"); return "mute works"
end
S.sound_volume_restored = function()
  boot("MAGE"); CVARS.SoundVolume = "0.6"; ProcDocDB.globalVars.soundVolume = 0.3
  Buff(2, "Clearcasting", CC, 15); auras(); noerr("x")
  check(CVARS.SoundVolume == "0.6", "volume restored, got " .. tostring(CVARS.SoundVolume)); check(STATS.sound == 1, "played")
  return "SoundVolume cvar restored"
end
S.timer_countdown = function()
  boot("MAGE"); Buff(2, "Clearcasting", CC, 15); auras(); frames60(5); noerr("x")
  local t = timerText(); check(t and t >= 9 and t <= 10, "timer about 10, got " .. tostring(t))
  frames60(10.2); W.buffs[2] = nil; auras(); frames60(0.2); check(#vis() == 0, "gone at expiry")
  return "countdown ok"
end
S.timers_disabled = function()
  boot("MAGE"); ProcDocDB.globalVars.disableTimers = true; Buff(2, "Clearcasting", CC, 15); auras(); frames60(0.5)
  check(has("DruidClearcasting.tga") and timerText() == nil, "alert without timer"); return "timers off"
end
S.refresh_detected = function()
  boot("MAGE"); Buff(2, "Clearcasting", CC, 10); auras(); frames60(6)
  check(timerText() <= 4, "was counting down: " .. tostring(timerText()))
  W.buffs[2].expire = CLOCK + 10        -- re-applied, no aura event
  frames60(0.6); local t = timerText(); check(t and t >= 9, "timer reset after refresh, got " .. tostring(t))
  return "refresh resets timer"
end
S.hotstreak_tiers = function()
  boot("MAGE"); local HS = "Interface\\Icons\\Spell_Fire_Firestarter"; local seen = {}
  for _, st in ipairs({ 1, 2, 3, 4, 5, 2, 0 }) do
    if st == 0 then W.buffs[5] = nil else Buff(5, "Hot Streak", HS, 15, st) end
    auras(); frames60(0.2); noerr("tier " .. st)
    seen[#seen + 1] = st .. "=" .. count("T ")
  end
  return table.concat(seen, " ") .. " sounds=" .. STATS.sound
end
S.druid_boons = function()
  boot("DRUID"); Buff(1, "Astral Boon", "Interface\\Icons\\Spell_Arcane_StarFire", 20, 3); Buff(2, "Natural Boon", "Interface\\Icons\\Spell_Nature_AbolishMagic", 20, 2)
  auras(); frames60(0.3); noerr("boons")
  check(has("DruidAstralBoon.tga") and has("DruidNaturalBoon.tga"), "both alerts"); check(has("F 3") and has("F 2"), "stack counts shown: " .. table.concat(vis(), ";"))
  return "boons with stacks"
end
local OP = "Interface\\Icons\\Ability_MeleeDamage"
S.action_overpower = function()
  boot("WARRIOR"); putAction(7, OP, false); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2)
  check(#vis() == 0, "not usable: no alert")
  W.usable[7] = true; ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.3); noerr("x")
  check(has("WarriorOverpower.tga"), "alert when usable"); check(STATS.sound == 1, "sound once"); check(timerText() == 4 or timerText() == 5, "5s default timer: " .. tostring(timerText()))
  ev("ACTIONBAR_UPDATE_USABLE"); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.1); check(STATS.sound == 1, "no sound spam")
  W.usable[7] = false; ev("UNIT_SPELLCAST_SUCCEEDED", "player", "Overpower"); frames60(0.1); check(#vis() == 0, "hidden after cast")
  return "overpower flow"
end
S.action_expires = function()
  boot("WARRIOR"); putAction(7, OP, true); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); check(has("WarriorOverpower.tga"), "shown")
  frames60(6); noerr("x"); check(#vis() == 0, "hidden when the 5 s window is over: " .. table.concat(vis(), ";"))
  return "timer hides action alert"
end
S.action_not_on_bar = function()
  boot("WARRIOR"); W.usable[7] = true; ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); check(#vis() == 0, "spell not on any bar: no alert")
  return "needs an action-bar slot"
end
S.action_moves_slot = function()
  boot("WARRIOR"); putAction(7, OP, true); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); check(has("WarriorOverpower.tga"), "shown")
  putAction(7, nil, nil); putAction(40, OP, true); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); noerr("x")
  check(has("WarriorOverpower.tga"), "follows the ability to its new slot")
  putAction(40, nil, nil); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); check(#vis() == 0, "removed from bars -> hidden")
  return "slot changes tracked"
end
S.action_lower_slot_added = function()
  boot("WARRIOR"); putAction(40, OP, true); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); check(has("WarriorOverpower.tga"), "shown from slot 40")
  putAction(7, OP, false); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2)   -- original: first slot found (7) decides, and it is not usable
  noerr("x"); return "first matching slot wins: " .. (has("WarriorOverpower.tga") and "still shown" or "hidden")
end
S.action_missed_event_safety_net = function()
  boot("WARRIOR"); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2)
  W.actions[7] = OP; W.usable[7] = true      -- slot changed but NO ACTIONBAR_SLOT_CHANGED delivered
  ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2)
  local immediate = has("WarriorOverpower.tga")
  frames60(5.5); ev("ACTIONBAR_UPDATE_USABLE"); frames60(0.2); noerr("x")
  check(has("WarriorOverpower.tga"), "found within the cache expiry even without the event")
  return "found " .. (immediate and "immediately" or "after the cache expired (<= 5 s)") .. " when the slot event is missed"
end
S.paladin_spellbook = function()
  boot("PALADIN"); W.book = { "Judgement", "Hammer of Justice" }; W.combat = true
  ev("PLAYER_REGEN_DISABLED"); Tick(0.1, 3); noerr("combat"); check(has("PaladinJudgement.tga"), "Judgement ready in combat: " .. table.concat(vis(), ";"))
  W.cooldowns["Judgement"] = { expire = CLOCK + 8, duration = 8 }; ev("ACTIONBAR_UPDATE_COOLDOWN"); Tick(0.1, 3); check(not has("PaladinJudgement.tga"), "hidden on cooldown")
  W.cooldowns["Judgement"] = nil; Tick(0.1, 5); check(has("PaladinJudgement.tga"), "back when the cooldown ends (polled while down)")
  W.combat = false; ev("PLAYER_REGEN_ENABLED"); Tick(0.1, 3); check(not has("PaladinJudgement.tga"), "out of combat hidden")
  return "spellbook procs"
end
S.combat_flag_no_api = function()
  boot("PALADIN"); W.book = { "Judgement" }; UnitAffectingCombat = nil
  ev("PLAYER_REGEN_DISABLED"); Tick(0.1, 3); noerr("x"); check(has("PaladinJudgement.tga"), "falls back to the combat events when UnitAffectingCombat is missing")
  return "combat fallback works"
end
S.options_panel = function()
  boot("MAGE"); SlashCmdList["PROCDOC"](""); noerr("open"); check(ProcDocOptionsFrame and ProcDocOptionsFrame._shown, "panel shown")
  local sl = ProcDocMinTransSlider; check(sl, "slider exists"); sl:SetValue(0.5); _G.this = sl; try("slider", sl._scripts.OnValueChanged, 0.5); noerr("slider")
  SlashCmdList["PROCDOC"](""); noerr("reopen")
  return "options open; minAlpha=" .. tostring(ProcDocDB.globalVars.minAlpha)
end
S.options_all_widgets = function()
  boot("MAGE"); SlashCmdList["PROCDOC"](""); noerr("open")
  local n = 0
  for _, o in ipairs(ALLOBJ()) do
    if o._scripts.OnClick and (o._kind == "Button" or o._kind == "CheckButton") then _G.this = o; _G.arg1 = "LeftButton"; try("click", o._scripts.OnClick); n = n + 1 end
  end
  for _, o in ipairs(ALLOBJ()) do
    if o._kind == "Slider" and o._scripts.OnValueChanged then _G.this = o; try("slider", o._scripts.OnValueChanged, o._value or 0) end
  end
  noerr("widgets"); frames60(0.5)
  return n .. " buttons/checkboxes clicked, all sliders driven"
end
S.db_defaults_and_migration = function()
  ProcDocDB = { globalVars = { maxSize = 1.4, minAlpha = 0.5 }, procsEnabled = {} }
  boot("MAGE"); noerr("x"); local gv = ProcDocDB.globalVars
  check(gv.maxScale == 1.4 and gv.maxSize == nil, "legacy maxSize migrated to maxScale: " .. tostring(gv.maxScale))
  check(gv.minAlpha == 0.5, "existing value kept"); check(gv.pulseSpeed == 0.4 and gv.isMuted == false and gv.soundVolume == 1.0, "defaults filled")
  return "migration ok"
end
-- ---- performance & robustness probes
local function pulsePeriod(fps)
  boot("MAGE"); Buff(2, "Clearcasting", CC, 9999); auras(); Tick(1 / fps, 5)
  local function alpha() for _, l in ipairs(vis()) do local a = l:match("a=([%d%.]+)"); if a then return tonumber(a) end end end
  local lastDir, ups, t0, t = nil, 0, CLOCK, nil
  local prev = alpha(); local turns = {}
  for i = 1, math.floor(fps * 40) do
    Tick(1 / fps, 1); local a = alpha()
    if a > prev then if lastDir == "down" then turns[#turns + 1] = CLOCK end lastDir = "up" elseif a < prev then if lastDir == "up" then turns[#turns + 1] = CLOCK end lastDir = "down" end
    prev = a
  end
  if #turns >= 3 then return (turns[#turns] - turns[1]) / (#turns - 1) * 2 end
  return nil
end
S.pulse_rate_vs_fps = function()
  local p = {}
  for _, fps in ipairs({ 30, 60, 144 }) do
    local ok, v = pcall(pulsePeriod, fps); p[#p + 1] = { fps, ok and v or nil }
  end
  local s = {}
  for _, e in ipairs(p) do s[#s + 1] = e[1] .. "fps=" .. (e[2] and string.format("%.2fs", e[2]) or "n/a") end
  check(p[1][2] and p[2][2] and p[3][2], "pulse measured: " .. table.concat(s, " "))
  local lo, hi = math.min(p[1][2], p[2][2], p[3][2]), math.max(p[1][2], p[2][2], p[3][2])
  if hi / lo > 1.15 then error("pulse speed depends on frame rate: " .. table.concat(s, " "), 0) end
  return "pulse period same at every FPS: " .. table.concat(s, " ")
end
S.cost_idle_scan = function()
  boot("MAGE")
  for i = 0, 11 do Buff(i, "Some Buff " .. i, "Interface\\Icons\\Misc_" .. i, 600) end
  auras(); ResetStats(); frames60(10)
  return "tooltip builds in 10 idle seconds with 12 buffs and no proc: " .. STATS.tooltip
end
S.cost_aura_event = function()
  boot("MAGE")
  for i = 0, 9 do Buff(i, "Some Buff " .. i, "Interface\\Icons\\Misc_" .. i, 600) end
  Buff(10, "Clearcasting", CC, 15); Buff(11, "Netherwind Focus", "Interface\\Icons\\Spell_Shadow_Teleport", 15)
  ResetStats(); auras(); noerr("x")
  return "tooltip builds for ONE aura event (12 buffs, 2 procs): " .. STATS.tooltip
end
S.cost_action_events = function()
  boot("WARRIOR")
  for s = 1, 120 do W.actions[s] = "Interface\\Icons\\Filler_" .. s end
  W.actions[100] = OP; W.usable[100] = true; ev("ACTIONBAR_SLOT_CHANGED", 100); ev("ACTIONBAR_UPDATE_USABLE"); ResetStats()
  for i = 1, 20 do ev("ACTIONBAR_UPDATE_USABLE") end noerr("x")
  return "GetActionTexture calls for 20 usable-update events: " .. STATS.actionTex
end


-- ================================================================= aura API (ClassicAPI) path
local function chatHas(sub) for _, l in ipairs(CHAT) do if l:find(sub, 1, true) then return true end end return false end
S.aura_basic = function()
  UseAuraAPI(); boot("MAGE"); Buff(2, "Clearcasting", CC, 15); ResetStats(); auras(); frames60(0.5); noerr("proc")
  check(has("DruidClearcasting.tga"), "alert shown via the aura API"); check(timerText() == 14, "timer from expirationTime: " .. tostring(timerText()))
  check(STATS.tooltip == 0, "no tooltip builds, got " .. STATS.tooltip); check(STATS.aura > 0, "aura API used")
  W.buffs[2] = nil; auras(); frames60(0.1); check(#vis() == 0, "hidden when buff ends")
  return "aura API: alert + timer, 0 tooltip builds"
end
S.aura_refresh_and_expiry = function()
  UseAuraAPI(); boot("MAGE"); Buff(2, "Clearcasting", CC, 10); auras(); frames60(6)
  check(timerText() <= 4, "counting down"); W.buffs[2].expire = CLOCK + 10; frames60(0.6)
  local t = timerText(); check(t and t >= 9, "refresh noticed via aura API, got " .. tostring(t)); noerr("x")
  return "refresh detected through the aura API"
end
S.aura_no_duration_buff = function()
  UseAuraAPI(); boot("MAGE"); Buff(2, "Clearcasting", CC, nil); auras(); frames60(0.4); noerr("x")
  check(has("DruidClearcasting.tga") and timerText() == nil, "alert without timer for an aura with no duration")
  return "no-duration buff: alert, no timer"
end
S.aura_hotstreak_and_boons = function()
  UseAuraAPI(); boot("MAGE"); local HS = "Interface\\Icons\\Spell_Fire_Firestarter"; local seen = {}
  for _, st in ipairs({ 1, 2, 3, 4, 5, 2, 0 }) do
    if st == 0 then W.buffs[5] = nil else Buff(5, "Hot Streak", HS, 15, st) end
    auras(); frames60(0.2); noerr("tier " .. st); seen[#seen + 1] = st .. "=" .. count("T ")
  end
  check(table.concat(seen, " ") == "1=0 2=0 3=1 4=2 5=3 2=0 0=0", "tiers: " .. table.concat(seen, " "))
  return table.concat(seen, " ") .. " sounds=" .. STATS.sound
end
S.aura_boons = function()
  UseAuraAPI(); package.loaded = package.loaded
  boot("DRUID"); Buff(1, "Astral Boon", "Interface\\Icons\\Spell_Arcane_StarFire", 20, 3); Buff(2, "Natural Boon", "Interface\\Icons\\Spell_Nature_AbolishMagic", 20, 2)
  auras(); frames60(0.3); noerr("boons"); check(has("DruidAstralBoon.tga") and has("DruidNaturalBoon.tga"), "both alerts"); check(has("F 3") and has("F 2"), "stack counts: " .. table.concat(vis(), ";"))
  return "boons with stacks via aura API"
end
S.aura_icon_forms = function()
  UseAuraAPI({ bareIcon = true }); boot("MAGE"); Buff(2, "Clearcasting", CC, 15); auras(); frames60(0.3); noerr("x")
  check(has("DruidClearcasting.tga"), "bare icon name (no path) still matches")
  W.buffs[2] = nil; auras(); Buff(2, "Clearcasting", "Interface\\Icons\\Some_Other_Icon", 15); auras(); frames60(0.3)
  check(#vis() == 0, "a genuinely different icon is still rejected")
  return "icon comparison tolerant but not blind"
end
S.aura_failure_fallback = function()
  UseAuraAPI({ fail = true }); boot("MAGE"); Buff(2, "Clearcasting", CC, 15); ResetStats(); auras(); frames60(0.5); noerr("x")
  check(has("DruidClearcasting.tga"), "alert still shown through the tooltip fallback"); check(STATS.tooltip > 0, "tooltips used")
  check(chatHas("aura API failed"), "user told once")
  local n = 0; for _, l in ipairs(CHAT) do if l:find("aura API failed", 1, true) then n = n + 1 end end
  check(n == 1, "message printed once, not per event: " .. n)
  return "aura API error -> tooltip fallback, no crash"
end
S.source_forced_tooltip = function()
  UseAuraAPI(); boot("MAGE"); SlashCmdList["PROCDOC"]("source tooltip"); Buff(2, "Clearcasting", CC, 15); ResetStats(); auras(); frames60(0.3); noerr("x")
  check(STATS.aura == 0 and STATS.tooltip > 0, "tooltip path forced"); check(ProcDocDB.globalVars.auraSource == "tooltip", "saved in DB")
  SlashCmdList["PROCDOC"]("source auto"); ResetStats(); auras(); check(STATS.aura > 0, "auto restores the aura API")
  SlashCmdList["PROCDOC"]("source nonsense"); check(chatHas("usage: /procdoc source"), "bad argument explained")
  return "source switch works"
end
S.scan_command = function()
  UseAuraAPI(); boot("MAGE"); Buff(2, "Clearcasting", CC, 15); Buff(3, "Mana Shield", "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", 60)
  CHAT = {}; SlashCmdList["PROCDOC"]("scan"); noerr("scan"); check(chatHas("both methods agree"), "agree: " .. table.concat(CHAT, " | "))
  UseAuraAPI({ skip = { ["Mana Shield"] = true }, skew = 4 }); CHAT = {}; SlashCmdList["PROCDOC"]("scan"); noerr("scan2")
  check(chatHas("only in tooltip scan") and chatHas("Mana Shield"), "reports the buff the aura API did not return")
  check(chatHas("time left differs") and chatHas("Clearcasting"), "reports the time mismatch")
  check(chatHas("difference(s)") and chatHas("/procdoc source tooltip"), "points to the escape hatch")
  UseAuraAPI({ bareIcon = false }); W.buffs[2].tex = "Interface\\Icons\\Other"; CHAT = {}; SlashCmdList["PROCDOC"]("scan"); check(chatHas("both methods agree"), "same data again agrees (aura reads W.buffs too)")
  return "scan reports agreement and disagreement"
end
S.scan_without_aura_api = function()
  boot("MAGE"); Buff(2, "Clearcasting", CC, 15); CHAT = {}; SlashCmdList["PROCDOC"]("scan"); noerr("scan"); check(chatHas("aura API not available"), "says so")
  CHAT = {}; SlashCmdList["PROCDOC"]("status"); check(chatHas("tooltip scan") and chatHas("ClassicAPI aura API not found"), "status explains: " .. table.concat(CHAT, " | "))
  return "scan/status without ClassicAPI"
end
S.pulsefps_command = function()
  boot("MAGE"); SlashCmdList["PROCDOC"]("pulsefps 30"); check(ProcDocDB.globalVars.pulseReferenceFps == 30, "saved")
  SlashCmdList["PROCDOC"]("pulsefps 5"); check(ProcDocDB.globalVars.pulseReferenceFps == 30, "out-of-range rejected"); check(chatHas("usage: /procdoc pulsefps"), "usage shown")
  SlashCmdList["PROCDOC"]("pulsefps abc"); check(ProcDocDB.globalVars.pulseReferenceFps == 30, "garbage rejected")
  return "pulsefps validated"
end
S.pulse_reference_scales = function()
  local function period(ref)
    boot("MAGE"); ProcDocDB.globalVars.pulseReferenceFps = ref; Buff(2, "Clearcasting", CC, 9999); auras(); Tick(1 / 60, 5)
    local function alpha() for _, l in ipairs(vis()) do local a = l:match("a=([%d%.]+)"); if a then return tonumber(a) end end end
    local last, turns, prev = nil, {}, alpha()
    for i = 1, 60 * 40 do Tick(1 / 60, 1); local a = alpha()
      if a > prev then if last == "down" then turns[#turns + 1] = CLOCK end last = "up" elseif a < prev then if last == "up" then turns[#turns + 1] = CLOCK end last = "down" end prev = a end
    return (turns[#turns] - turns[1]) / (#turns - 1) * 2
  end
  local p60 = period(60); check(math.abs(p60 - 1.67) < 0.1, "60 FPS reference matches the old speed at 60 FPS: " .. string.format("%.2f", p60))
  return string.format("period at 60 FPS reference: %.2fs", p60)
end
S.lag_spike_clamped = function()
  boot("MAGE"); Buff(2, "Clearcasting", CC, 9999); auras(); Tick(1 / 60, 10)
  local before = vis()[1]; Tick(5, 1)           -- a 5 second hitch
  noerr("x"); local a = tonumber((vis()[1] or ""):match("a=([%d%.]+)")); check(a and a >= 0.8 and a <= 1.0, "alpha stays inside the configured range after a hitch: " .. tostring(a))
  return "lag spike handled"
end
local fn = S[want]
if not fn then print("RESULT|" .. want .. "|FAIL|unknown scenario") os.exit(2) end
local ok, res = pcall(fn)
print("RESULT|" .. want .. "|" .. (ok and "PASS" or "FAIL") .. "|" .. tostring(res))
os.exit(ok and 0 or 1)
