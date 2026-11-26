# ProcDoc

**ProcDoc** is a lightweight World of Warcraft (Turtle WoW / Vanilla 1.12) addon that displays pulsing visual alerts, countdown timers, and distinct audio cues whenever your character gains a proc buff (such as Clearcasting, Shadow Trance, or Hot Streak) or when a reactive/cooldown ability becomes available (such as Overpower, Revenge, Riposte, Arcane Surge, or Judgement).

---

## Optional Client DLL Mods

ProcDoc works out of the box on a stock Vanilla 1.12.1 client. When present, it automatically detects and uses the following optional client mods:

| Mod | Status | Used For | Fallback Without It |
|---|---|---|---|
| **[Nampower](https://gitea.com/avitasia/nampower)** | Optional (Recommended) | Event-driven, buffcap-safe buff tracking (`GetPlayerAuraDuration`, `GetSpellRecField`, `GetSpellIconTexture`, `BUFF_ADDED_SELF`, `BUFF_REMOVED_SELF`, `BUFF_UPDATE_DURATION_SELF`, `AURA_CAST_ON_SELF` overflow capture) and instant reactive-proc hide on cast (`SPELL_GO_SELF`) | Falls back to ClassicAPI or stock tooltip scanning and combat-log cast hide |
| **[ClassicAPI](https://github.com/brues-code/ClassicAPI)** | Optional | Allocation-free buff reading (`C_UnitAuras.UnitAura`) with no hidden tooltip when Nampower is absent, plus `UNIT_SPELLCAST_SUCCEEDED` | Falls back to stock 1.12 hidden-tooltip buff scanning and combat-log events |

In `auto` mode (default), ProcDoc selects **Nampower → ClassicAPI → Tooltip** automatically and falls back safely if any API errors. Use `/procdoc source` to force a specific reader or `/procdoc status` to check the active backend.

---

## Features

- **Pulsing visual alerts**: large, customizable side/top textures around your character with FPS-independent pulse speed.
- **Buff-based & custom procs**: automatic class-aware buff detection, plus `/procdoc add <Buff Name> [style]` to track any extra trinket, set bonus, or custom buff without editing Lua.
- **Reactive action procs (cross-stance & combat-log aware)**:
  - Detects reactive abilities via both action-bar usability (`IsUsableAction`) and combat-log / `COMBAT_TEXT_UPDATE` (`SPELL_ACTIVE`) triggers (`Overpower`, `Revenge`, `Counterattack`, `Riposte`, `Surprise Attack`, `Arcane Surge`, `Execute`, `Hammer of Wrath`, `Lacerate`, `Kill Command`).
  - **Low-resource / wrong-stance dimming**: when a reactive proc is active but you lack Mana/Rage/Energy or are in another stance, the alert displays dimmed with its countdown and lights up immediately once pressable (configurable via `/procdoc resource dim|hide`).
  - **Spellbook cooldown gating**: suppresses false triggers when an ability's cooldown exceeds the proc window, and resets the countdown if the proc refreshes.
- **Spellbook-based procs** (Paladin `Judgement` and `Hammer of Justice`): shown in combat whenever off cooldown, even if not placed on an action bar.
- **Timers & urgent warning**: automatic countdown timers with buff-refresh detection, optional `0.1s` decimal precision under `5s`, and urgent red-orange text color under `2s`.
- **Distinct audio cues**: `SpellAlert.ogg` for buff procs and `SpellAlert2.ogg` for action/reactive procs; can be muted.
- **Mage Hot Streak tiers**: scales visually across stacks (3 stacks = left, 4 = left + right, 5 = left + right + top).
- **Combat Only mode & per-proc toggles**: optionally hide all live alerts outside combat and enable/disable any individual proc in `/procdoc`.
- **True-zero idle CPU**: detaches `OnUpdate` completely when no alerts are active.

---

## Supported Procs

| Class | Buff-based | Action-based |
|---|---|---|
| **Warlock** | Shadow Trance | |
| **Mage** | Clearcasting, Netherwind Focus, Temporal Convergence, Flash Freeze, Arcane Rupture, Hot Streak | Arcane Surge |
| **Warrior** | Enrage, Riposte | Overpower, Execute, Counterattack, Revenge |
| **Druid** | Clearcasting, Nature's Grace, Tiger's Fury, Astral Boon, Natural Boon, Arcane Eclipse, Nature Eclipse, Owlkin Frenzy | |
| **Rogue** | Remorseless, Tricks of the Trade | Riposte, Surprise Attack |
| **Shaman** | Clearcasting, Ancestral Swiftness, Stormstrike, Flurry, Elemental Devastation | |
| **Priest** | Resurgence, Enlightened, Searing Light, Shadow Veil, Spell Blasting, Resurgent Shield | |
| **Hunter** | Quick Shots, Scent of Blood, Lock and Load, Explosive Ammunition, Poisonous Ammunition, Enchanted Ammunition | Lacerate, Kill Command |
| **Paladin** | Daybreak, Zealous Defense, Holy Judgement, Holy Might | Hammer of Wrath, Judgement, Hammer of Justice |

---

## Configuration

Open the options panel with `/procdoc`:

- **Min / Max Transparency**: pulse alpha range.
- **Min / Max Size**: pulse scale range.
- **Pulse Speed**: animation speed (FPS-independent, calibrated via `/procdoc pulsefps`).
- **Top Offset / Side Offset**: vertical and horizontal alert placement.
- **Sound Volume**: alert sound volume (`0%`–`100%`).
- **Mute All Proc Sounds**: silence all alert sounds.
- **Disable Timers**: hide countdown numbers.
- **Dim Low Resource**: show reactive procs dimmed when out of Mana/Rage/Energy or in the wrong stance (uncheck to hide instead).
- **Decimal Timers**: show `0.1s` precision when remaining time is under `5s`.
- **Combat Only**: only display live alerts while in combat.
- **Per-proc checkboxes** (including your `[Custom]` procs), **Test Proc**, **Hide All**, **Reset Defaults**, and **Close**.

---

## Slash Commands

| Command | Action |
|---|---|
| `/procdoc` | Open the options panel |
| `/procdoc status` | Show active buff reader and current settings |
| `/procdoc scan` | Compare tooltip scan vs aura API on your current buffs |
| `/procdoc source auto\|nampower\|aura\|tooltip` | Set buff reader priority (`auto`: Nampower → ClassicAPI → Tooltip) |
| `/procdoc resource dim\|hide` | Dim low-resource / wrong-stance reactive procs (default) or hide them |
| `/procdoc decimals on\|off` | Toggle `0.1s` decimal countdown under `5s` (default: on) |
| `/procdoc combat on\|off` | Toggle Combat Only mode (default: off) |
| `/procdoc add <Buff Name> [style] [texture]` | Add a custom buff proc (`TOP`, `TOP2`, `TOP_ROTATED`, `SIDES`, `SIDES2`, `LEFT`, `RIGHT`) with optional texture |
| `/procdoc remove <Buff Name>` | Remove a custom buff proc |
| `/procdoc list` | List all custom buff procs |
| `/procdoc textures` | List built-in alert texture names available for `/procdoc add` |
| `/procdoc trace` | Toggle debug trace output in chat |
| `/procdoc pulsefps <10-500>` | Calibrate pulse speed reference FPS (default: 60) |
| `/procdoc help` | List available commands |

---

## What Was Added / Improved vs Upstream (v2.7)

### New Features & Turtle WoW Updates
- **Nampower buffcap-safe buff reader**: event-driven buff/stack/duration tracking with `AURA_CAST_ON_SELF` overflow support for 32-buff raid environments and `SPELL_GO_SELF` instant cast hide.
- **Smart reactive triggers & dimming**: combat-log + `COMBAT_TEXT_UPDATE` (`SPELL_ACTIVE`) detection for `Overpower`, `Revenge`, `Counterattack`, `Riposte`, `Surprise Attack`, and `Arcane Surge` with spellbook cooldown gating, timer refresh on re-proc, and low-resource / wrong-stance dimming.
- **Dual alert sounds**: `SpellAlert.ogg` for buff procs and `SpellAlert2.ogg` for action/reactive procs.
- **Decimal & urgent timers**: `0.1s` countdown precision under `5s` and red-orange urgent text color under `2s`.
- **7 new Turtle WoW talent procs**: `Owlkin Frenzy` (Druid), `Elemental Devastation` (Shaman), `Scent of Blood` (Hunter), `Riposte` buff (Warrior), `Resurgent Shield` (Priest), `Holy Judgement` and `Holy Might` (Paladin).
- **Custom user buff procs**: `/procdoc add`, `/procdoc remove`, and `/procdoc list`.
- **Options UI additions**: `Dim Low Resource`, `Decimal Timers`, `Combat Only` checkboxes, `Reset Defaults` button, and `/procdoc trace`.

### Bug Fixes & Performance
- **Turtle WoW DB accuracy**: fixed Paladin `Zealous Defense` spelling (was `Zealous Defence`), updated Shaman `Ancestral Swiftness` (was `Nature's Swiftness`), and updated Mage `Hot Streak` icon (`Ability_Mage_Firestarter`).
- **Crash & namespace safety**: localized 9 tuning variables with defaults (prevents pre-`VARIABLES_LOADED` `OnUpdate` nil-compare crash and global namespace pollution) and removed the duplicate `VARIABLES_LOADED` frame.
- **Tooltip scan & GC**: added `ProcDocScanTooltip:ClearLines()` before `SetPlayerBuff(i)` and reused separate tooltip/aura/Nampower buff tables.
- **True-zero idle CPU**: `OnUpdate` detaches completely when no alert is active; `spellbookCheckFrame` only attaches `OnUpdate` for Paladins.
- **UI & animation fixes**: isolated test preview alerts (`isTest`) from `CheckProcs()`, cleaned up test alerts on `Esc`/`OnHide`, fixed `TOP_ROTATED` (`Poisonous Ammunition`) and `ShowActionProcAlert` re-anchoring, reset reused `timerTexts` horizontal offset to `0`, hid `stackText` on timer expiry and `Disable Timers`, preserved smooth pulse phase across unrelated aura events, prevented action-proc timeout re-trigger loops (`state.timedOut`), fixed missing `DEFAULT_ALERT_TEXTURE` fallback, and refreshed live alerts immediately when toggling checkboxes.

---

## Credits

Original authors: **Clempton, Clumpton, Fruiter, Poot, Zeph, rexarlet**.

## License

Feel free to use, modify, or share **ProcDoc**. A mention or credit is welcome but not required.
