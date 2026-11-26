-- Mock WoW 1.12 (+ optional ClassicAPI aura API) environment for ProcDoc. Requires global PD_DIR.
local DIR = assert(PD_DIR, "PD_DIR not set")

table.getn = table.getn or function(t) return #t end
getn = table.getn; tinsert = table.insert; tremove = table.remove
strlower = string.lower; strupper = string.upper; strfind = string.find; strsub = string.sub; strlen = string.len
strgsub = string.gsub; format = string.format; string.gfind = string.gmatch
floor = math.floor; ceil = math.ceil; abs = math.abs; max = math.max; min = math.min
mod = function(a, b) return a - math.floor(a / b) * b end
unpack = unpack or table.unpack
function getglobal(n) return _G[n] end
function setglobal(n, v) _G[n] = v end

CLOCK = 1000.0
ERRORS = {}; CHAT = {}; UNKNOWN = {}
STATS = { tooltip = 0, aura = 0, actionTex = 0, usable = 0, sound = 0, setcvar = 0 }
local function logerr(where, msg) ERRORS[#ERRORS + 1] = { where = where, msg = tostring(msg) } end
function try(where, fn, ...)
  local ok, res = xpcall(fn, function(m) return debug.traceback(tostring(m), 2) end, ...)
  if not ok then logerr(where, res) end
  return ok, res
end

-- ------------------------------------------------------------ frame/region mock
local ALL = {}
local Obj = {}
local MT = { __index = function(t, k)
  local v = Obj[k]; if v ~= nil then return v end
  if type(k) == "string" and k:match("^[A-Z]") then return function() UNKNOWN[k] = (UNKNOWN[k] or 0) + 1 end end
  return nil
end }
local function new(kind, name, parent)
  local o = setmetatable({ _kind = kind, _name = name, _parent = parent, _shown = true, _scripts = {}, _events = {}, _alpha = 1,
    _w = 0, _h = 0, _text = "", _value = 0, _checked = nil, _points = {}, _children = {}, _kids = {} }, MT)
  if name then _G[name] = o end
  ALL[#ALL + 1] = o
  if parent and parent._kids then parent._kids[#parent._kids + 1] = o end
  return o
end
local function runHook(f, hook, ...)
  local fn = f._scripts[hook]; if not fn then return end
  local old = _G.this; _G.this = f
  local a = { ... }; for i = 1, 9 do _G["arg" .. i] = a[i] end
  local ok, err = xpcall(fn, function(m) return debug.traceback(tostring(m), 2) end)
  _G.this = old
  if not ok then logerr((f._name or f._kind) .. ":" .. hook, err) end
end
function Obj.GetName(s) return s._name end
function Obj.GetParent(s) return s._parent end
function Obj.SetScript(s, h, fn) s._scripts[h] = fn end
function Obj.GetScript(s, h) return s._scripts[h] end
function Obj.RegisterEvent(s, e) s._events[e] = true end
function Obj.UnregisterEvent(s, e) s._events[e] = nil end
function Obj.Show(s) if not s._shown then s._shown = true; runHook(s, "OnShow") end end
function Obj.Hide(s) if s._shown then s._shown = false; runHook(s, "OnHide") end end
function Obj.IsShown(s) return s._shown and 1 or nil end
function Obj.IsVisible(s) local f = s; while f do if not f._shown then return nil end; f = f._parent end return 1 end
function Obj.SetAlpha(s, a) s._alpha = a end
function Obj.GetAlpha(s) return s._alpha end
function Obj.SetWidth(s, w) s._w = w end
function Obj.SetHeight(s, h) s._h = h end
function Obj.GetWidth(s) return s._w end
function Obj.GetHeight(s) return s._h end
function Obj.SetTexture(s, t) s._tex = t end
function Obj.GetTexture(s) return s._tex end
function Obj.SetText(s, t) s._text = t end
function Obj.GetText(s) return s._text end
function Obj.ClearAllPoints(s) s._points = {} end
function Obj.SetPoint(s, ...) local a = { ... }; s._points[#s._points + 1] = a end
function Obj.SetValue(s, v) s._value = v end
function Obj.GetValue(s) return s._value end
function Obj.SetChecked(s, v) s._checked = v and 1 or nil end
function Obj.GetChecked(s) return s._checked end
function Obj.CreateTexture(s, name) return new("Texture", name, s) end
function Obj.CreateFontString(s, name) return new("FontString", name, s) end
function Obj.GetNumChildren(s) return #s._kids end

local function tooltipLines(f)
  for i = 1, 8 do new("FontString", f._name .. "TextLeft" .. i, f); new("FontString", f._name .. "TextRight" .. i, f) end
end
function Obj.SetOwner(s) end
function Obj.SetPlayerBuff(s, slot)
  STATS.tooltip = STATS.tooltip + 1
  local b = W.buffs[slot]
  local l1, r1, l2 = _G[s._name .. "TextLeft1"], _G[s._name .. "TextRight1"], _G[s._name .. "TextLeft2"]
  if l1 then l1._text = b and b.name or nil end
  if r1 then r1._text = b and b.tipRight or nil end
  if l2 then l2._text = b and b.tipLeft2 or nil end
end
function CreateFrame(kind, name, parent, template)
  local f = new(kind, name, parent or UIParent)
  if kind == "GameTooltip" and name then tooltipLines(f) end
  if kind == "Slider" and name then for _, suf in ipairs({ "Low", "High", "Text" }) do new("FontString", name .. suf, f) end end
  if kind == "CheckButton" and name then new("FontString", name .. "Text", f) end
  return f
end
UIParent = new("Frame", "UIParent", nil)
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHAT[#CHAT + 1] = tostring(m) end }
SlashCmdList = {}
UISpecialFrames = {}
function GetTime() return CLOCK end

-- ------------------------------------------------------------ game state
W = { class = "MAGE", className = "Mage", combat = false,
      buffs = {},         -- slot (0..31) -> { name, tex, expire (absolute), stacks, spellId, tipRight, tipLeft2 }
      actions = {},       -- slot -> texture path
      usable = {},        -- slot -> true
      cooldowns = {},     -- spell name -> { start, duration }
      book = {} }         -- list of spell names (single tab)
CVARS = { SoundVolume = "1" }; CVAR_LOG = {}; SOUND_LOG = {}
function UnitClass(u) return W.className, W.class end
function UnitAffectingCombat() return W.combat and 1 or nil end
function GetCVar(n) return CVARS[n] end
function SetCVar(n, v) STATS.setcvar = STATS.setcvar + 1; CVAR_LOG[#CVAR_LOG + 1] = n .. "=" .. tostring(v); CVARS[n] = v end
function PlaySoundFile(path, ch) STATS.sound = STATS.sound + 1; SOUND_LOG[#SOUND_LOG + 1] = { path = path, ch = ch, vol = CVARS.SoundVolume, t = CLOCK } end
function PlaySound() end
function GetPlayerBuffTexture(i) local b = W.buffs[i]; return b and b.tex or nil end
function GetPlayerBuffTimeLeft(i) local b = W.buffs[i]; if not b or not b.expire then return 0 end local t = b.expire - CLOCK; return t > 0 and t or 0 end
function GetPlayerBuffApplications(i) local b = W.buffs[i]; return b and b.stacks or 0 end
function GetActionTexture(slot) STATS.actionTex = STATS.actionTex + 1; return W.actions[slot] end
function IsUsableAction(slot) STATS.usable = STATS.usable + 1; return W.usable[slot] and 1 or nil end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo(t) return "General", "", 0, #W.book end
function GetSpellName(i, book) return W.book[i] end
function GetSpellCooldown(i, book)
  local n = W.book[i]; local c = n and W.cooldowns[n]
  if c and c.expire and c.expire > CLOCK then return c.expire - c.duration, c.duration, 1 end
  return 0, 0, 1
end
BOOKTYPE_SPELL = "spell"

-- optional ClassicAPI aura API (tests switch it on with UseAuraAPI)
local function activeBuffs()
  local list = {}
  for slot = 0, 31 do if W.buffs[slot] then list[#list + 1] = W.buffs[slot] end end
  return list
end
function UseAuraAPI(opts)
  opts = opts or {}
  if opts == false then C_UnitAuras = nil; return end
  C_UnitAuras = {
    UnitAura = function(unit, index, filter)
      STATS.aura = STATS.aura + 1
      if opts.fail then error("aura api exploded") end
      if unit ~= "player" then return nil end
      local list = {}
      for _, bb in ipairs(activeBuffs()) do if not (opts.skip and opts.skip[bb.name]) then list[#list + 1] = bb end end
      local b = list[index]
      if not b then return nil end
      local icon = b.tex
      if opts.bareIcon and icon then icon = icon:match("([^\\]+)$") end
      local exp = b.expire or 0
      if opts.skew and b.expire then exp = exp + opts.skew end
      return b.name, icon, math.max(1, b.stacks or 0), nil, (b.expire and 30 or 0), exp, nil, false, false, b.spellId or 0
    end,
    GetAuraDataBySpellName = function(unit, name) end,
  }
end

-- ------------------------------------------------------------ driver
function LoadAddon()
  local chunk, err = loadfile(DIR .. "/ProcDoc.lua")
  if not chunk then error("compile: " .. tostring(err)) end
  local ok, e = xpcall(chunk, function(m) return debug.traceback(tostring(m), 2) end)
  if not ok then logerr("load", e) end
end
function FireEvent(ev, a1, a2, a3, a4)
  _G.event = ev
  for _, f in ipairs(ALL) do if f._events[ev] and f._scripts.OnEvent then runHook(f, "OnEvent", a1, a2, a3, a4) end end
end
function Tick(dt, frames)
  frames = frames or 1
  for _ = 1, frames do
    CLOCK = CLOCK + dt
    for _, f in ipairs(ALL) do
      if f._scripts.OnUpdate and f._shown then runHook(f, "OnUpdate", dt) end
    end
  end
end
function ALLOBJ() return ALL end
function ResetErrors() ERRORS = {} end
function ResetStats() for k in pairs(STATS) do STATS[k] = 0 end end
function Buff(slot, name, tex, remaining, stacks, extra)
  local b = { name = name, tex = tex, expire = remaining and (CLOCK + remaining) or nil, stacks = stacks or 0 }
  if extra then for k, v in pairs(extra) do b[k] = v end end
  W.buffs[slot] = b
end
-- visible alert state signature (what the player would see)
function Visible()
  local out = {}
  for _, o in ipairs(ALL) do
    if o._kind == "Texture" and o._shown and o._tex and o._tex:find("ProcDoc", 1, true) then
      out[#out + 1] = string.format("T %s a=%.3f w=%.1f h=%.1f", o._tex:match("([^\\]+)$"), o._alpha, o._w, o._h)
    elseif o._kind == "FontString" and o._shown and o._text ~= "" and o._text ~= nil and not (o._name or ""):find("Tooltip") and not (o._name or ""):find("^ProcDoc.*Slider") and not (o._name or ""):find("Text$") then
      out[#out + 1] = "F " .. tostring(o._text)
    end
  end
  return out
end
