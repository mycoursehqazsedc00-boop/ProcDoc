-- usage: [AURA=1] [NOHS=1] [TRACE=n] texlua pdfuzz.lua <addon_dir> <seed> [steps]
PD_DIR = arg[1]; local seed = tonumber(arg[2]); local steps = tonumber(arg[3] or 300)
local SD = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
dofile(SD .. "/pdenv.lua")
local NOHS, TRACE = os.getenv("NOHS"), tonumber(os.getenv("TRACE"))
-- extract the class proc tables straight from the addon source
local src = io.open(PD_DIR .. "/ProcDoc.lua", "rb"):read("a")
local function unesc(s) return (s:gsub("\\\\", "\\")) end
local buffProcs, actionProcs, section, class, cur = {}, {}, "buff", nil, nil
for line in src:gmatch("[^\n]+") do
  if line:find("local ACTION_PROCS", 1, true) then section = "action"; class = nil end
  if line:find("local DEFAULT_ALERT_TEXTURE", 1, true) then section = "done" end
  if section ~= "done" then
    local c = line:match('^%s*%["(%u+)"%]%s*=%s*{')
    if c then class = c end
    local bn = line:match('buffName%s*=%s*"([^"]+)"')
    if bn and class then cur = { name = bn, class = class }; local t = (section == "buff") and buffProcs or actionProcs; t[#t + 1] = cur end
    local tx = line:match('^%s*texture%s*=%s*"([^"]+)"'); if tx and cur then cur.tex = unesc(tx) end
    local sp = line:match('spellName%s*=%s*"([^"]+)"'); if sp and cur then cur.spell = sp end
    if line:find("useSpellbook%s*=%s*true") and cur then cur.book = true end
  end
end
local classes = { "MAGE", "WARRIOR", "DRUID", "PALADIN", "ROGUE", "HUNTER", "PRIEST", "SHAMAN", "WARLOCK" }
local CLASSNAME = { WARRIOR = "Warrior", MAGE = "Mage", DRUID = "Druid", PALADIN = "Paladin", ROGUE = "Rogue", HUNTER = "Hunter", PRIEST = "Priest", SHAMAN = "Shaman", WARLOCK = "Warlock" }
local cls = classes[(seed % #classes) + 1]
if os.getenv("AURA") then UseAuraAPI() end
W.class = cls; W.className = CLASSNAME[cls]
local _fire = FireEvent
EVLOG = {}
FireEvent = function(e, a, b, c, d) EVLOG[#EVLOG + 1] = e; _fire(e, a, b, c, d) end
LoadAddon(); FireEvent("VARIABLES_LOADED"); FireEvent("PLAYER_LOGIN"); Tick(1 / 60, 3)
math.randomseed(seed * 7919 + 13)
local myBuff, myAct = {}, {}
for _, p in ipairs(buffProcs) do if p.class == cls and not (NOHS and p.name == "Hot Streak") then myBuff[#myBuff + 1] = p end end
for _, p in ipairs(actionProcs) do if p.class == cls then myAct[#myAct + 1] = p end end
local spellsAll = {}
for _, p in ipairs(myAct) do if p.book and p.spell then spellsAll[#spellsAll + 1] = p.spell end end
W.book = spellsAll
local fillers = {}
for i = 1, 12 do fillers[i] = { name = "Filler Buff " .. i, tex = "Interface\\Icons\\Filler_" .. i } end
local function pickBuff()
  if #myBuff > 0 and math.random() < 0.7 then return myBuff[math.random(#myBuff)] end
  return fillers[math.random(#fillers)]
end
local function stacksFor(p) if p.name == "Hot Streak" or p.name == "Astral Boon" or p.name == "Natural Boon" then return math.random(1, 5) end return 0 end
local function randomRemaining() if math.random() < 0.1 then return nil end return math.random(3, 40) end
local function freeSlot() local t = {} for i = 0, 31 do if not W.buffs[i] then t[#t + 1] = i end end if #t == 0 then return nil end return t[math.random(#t)] end
local function usedSlot() local t = {} for i = 0, 31 do if W.buffs[i] then t[#t + 1] = i end end if #t == 0 then return nil end return t[math.random(#t)] end
local hash = 5381
local function mix(str) for i = 1, #str do hash = (hash * 33 + str:byte(i)) % 4294967296 end end
local function snapshot()
  local v = Visible(); mix(table.concat(v, "|")); mix("S" .. STATS.sound .. "E" .. #ERRORS .. "C" .. tostring(CVARS.SoundVolume))
end
for step = 1, steps do
  local r = math.random(1, 100)
  local what = "tick"
  if r <= 30 then
    if os.getenv("SETTLE") then Tick(1 / 60, 19) end   -- a running game always has frames between changes
    local k = math.random(1, 4)
    if k == 1 then
      local s = freeSlot()
      if s then
        local p = pickBuff()
        local dup = false
        for i = 0, 31 do if W.buffs[i] and W.buffs[i].name == p.name then dup = true end end   -- a character cannot hold the same self-buff twice
        if not dup or os.getenv("DUPS") then Buff(s, p.name, p.tex or "Interface\\Icons\\X", randomRemaining(), stacksFor(p)) end
      end
      what = "buff+"
    elseif k == 2 then local s = usedSlot(); if s then W.buffs[s] = nil end what = "buff-"
    elseif k == 3 then local s = usedSlot(); if s and W.buffs[s].expire then W.buffs[s].expire = math.max(W.buffs[s].expire, CLOCK + math.random(3, 40)) end what = "refresh"   -- re-applying a buff never shortens it
    else local s = usedSlot(); if s then W.buffs[s].stacks = (W.buffs[s].stacks or 0) > 0 and math.random(1, 5) or 0 end what = "stacks" end
    if math.random() < 0.9 then FireEvent("PLAYER_AURAS_CHANGED") end
  elseif r <= 50 then
    if #myAct > 0 then
      local p = myAct[math.random(#myAct)]
      if p.tex then
        local slot = math.random(1, 120)
        if math.random() < 0.6 then W.actions[slot] = p.tex; W.usable[slot] = math.random() < 0.6 else W.actions[slot] = nil; W.usable[slot] = nil end
        FireEvent("ACTIONBAR_SLOT_CHANGED", slot)
      end
      for slot, _ in pairs(W.actions) do if math.random() < 0.3 then W.usable[slot] = math.random() < 0.5 end end
      FireEvent("ACTIONBAR_UPDATE_USABLE")
    end
    what = "bars"
  elseif r <= 58 then
    local evs = { "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_SHAPESHIFT_FORM" }
    FireEvent(evs[math.random(#evs)]); what = "event"
  elseif r <= 64 then
    W.combat = not W.combat; FireEvent(W.combat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); what = "combat"
  elseif r <= 68 then
    if #spellsAll > 0 then local sp = spellsAll[math.random(#spellsAll)]; if math.random() < 0.5 then W.cooldowns[sp] = { expire = CLOCK + math.random(2, 20), duration = 10 } else W.cooldowns[sp] = nil end FireEvent("ACTIONBAR_UPDATE_COOLDOWN") end
    what = "cooldown"
  elseif r <= 72 then
    if #myAct > 0 then local p = myAct[math.random(#myAct)]; if p.spell then FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", p.spell) end end
    what = "cast"
  elseif r <= 76 then
    local k = math.random(1, 3)
    if k == 1 then ProcDocDB.globalVars.isMuted = not ProcDocDB.globalVars.isMuted
    elseif k == 2 then ProcDocDB.globalVars.disableTimers = not ProcDocDB.globalVars.disableTimers
    else local all = {}; for _, p in ipairs(myBuff) do all[#all + 1] = p.name end for _, p in ipairs(myAct) do all[#all + 1] = p.name end
      if #all > 0 then local n = all[math.random(#all)]; ProcDocDB.procsEnabled[n] = (ProcDocDB.procsEnabled[n] == false) and true or false end end
    what = "options"
  else
    Tick(1 / 60, math.random(1, 90)); what = "tick"
  end
  snapshot()
  if TRACE == seed then
    local bs = {}
    for i = 0, 31 do local b = W.buffs[i]; if b then bs[#bs + 1] = string.format("%d:%s=%s", i, b.name, b.expire and string.format("%.1f", b.expire - CLOCK) or "inf") end end
    print(string.format("STEP %d %s snd=%d %s", step, what, STATS.sound, table.concat(Visible(), "|")))
    if os.getenv("BUFFS") then print("   EVENTS " .. table.concat(EVLOG, ",")) end
    EVLOG = {}
    if os.getenv("BUFFS") then print("   BUFFS " .. table.concat(bs, " ") .. string.format("  t=%.3f", CLOCK)) end
  end
end
print(string.format("SEED %d class=%s errs=%d sounds=%d tooltip=%d aura=%d actionTex=%d hash=%d", seed, cls, #ERRORS, STATS.sound, STATS.tooltip, STATS.aura, STATS.actionTex, hash))
if #ERRORS > 0 then print("ERR " .. ERRORS[1].where .. " " .. ERRORS[1].msg:sub(1, 200):gsub("\n", " ")) end
