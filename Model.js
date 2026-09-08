// Pure helpers for the GUIndowRules Editor plugin.
// No QML, no side effects — testable with Node.

// ---------------------------------------------------------------------------
// Effect schema — every Hyprland window rule effect, grouped by category.
// Each entry: { key, type, label, description, default, category, options? }
//
// Types: "bool", "string", "int", "float", "enum", "color", "opacity"
// ---------------------------------------------------------------------------

var EFFECT_CATEGORIES = [
  { id: "layout",     label: "LAYOUT",     icon: "󰙀" },
  { id: "position",   label: "POSITION",   icon: "󰆧" },
  { id: "appearance", label: "APPEARANCE", icon: "󰏘" },
  { id: "behavior",   label: "BEHAVIOR",   icon: "󰒓" },
  { id: "advanced",   label: "ADVANCED",   icon: "󰘳" },
  { id: "plugin",     label: "PLUGIN",     icon: "󰐱" }
]

var EFFECT_SCHEMA = [
  // Layout
  { key: "float",       type: "bool",   label: "Float",              description: "Float the window above tiled layout",                  defaultValue: false, category: "layout" },
  { key: "tile",        type: "bool",   label: "Tile",               description: "Force-tile the window",                                defaultValue: false, category: "layout" },
  { key: "fullscreen",  type: "enum",   label: "Fullscreen",         description: "Fullscreen mode",                                      defaultValue: "",    category: "layout",
    options: [{ value: "", label: "Off" }, { value: "0", label: "Real" }, { value: "1", label: "Maximize" }, { value: "2", label: "No loss" }] },
  { key: "maximize",    type: "bool",   label: "Maximize",           description: "Maximize the window on open",                          defaultValue: false, category: "layout" },
  { key: "pseudo",      type: "bool",   label: "Pseudo-tile",        description: "Pseudo-tile (occupies tiled slot but keeps own size)",  defaultValue: false, category: "layout" },
  { key: "center",      type: "enum",   label: "Center",             description: "Center floating window on monitor",                    defaultValue: "",    category: "layout",
    options: [{ value: "", label: "Off" }, { value: "1", label: "Center" }, { value: "2", label: "Center (respect reserved)" }] },

  // Position
  { key: "move",        type: "string", label: "Move",               description: "Position floating window (e.g. '100 200', 'cursor')",  defaultValue: "",    category: "position" },
  { key: "size",        type: "string", label: "Size",               description: "Resize window (e.g. '800 600', '50% 50%')",            defaultValue: "",    category: "position" },
  { key: "monitor",     type: "string", label: "Monitor",            description: "Force window to specific monitor (name or index)",      defaultValue: "",    category: "position" },
  { key: "workspace",   type: "string", label: "Workspace",          description: "Force window to workspace (id, name, or 'special')",   defaultValue: "",    category: "position" },

  // Appearance
  { key: "opacity",         type: "opacity", label: "Opacity",           description: "Opacity: active [inactive [fullscreen]] (0.0–1.0)",    defaultValue: "",    category: "appearance" },
  { key: "border_size",     type: "int",     label: "Border size",       description: "Override border width (px)",                           defaultValue: -1,    category: "appearance", min: 0, max: 10 },
  { key: "border_color",    type: "color",   label: "Border color",      description: "Override border color (e.g. 'rgba(ff5555ff)')",        defaultValue: "",    category: "appearance" },
  { key: "rounding",        type: "int",     label: "Rounding",          description: "Override corner rounding (px)",                        defaultValue: -1,    category: "appearance", min: -1, max: 30 },
  { key: "shadow",          type: "bool",    label: "Shadow",            description: "Enable window shadow",                                 defaultValue: true,  category: "appearance" },
  { key: "dim_around",      type: "bool",    label: "Dim around",        description: "Dim everything except this window",                    defaultValue: false, category: "appearance" },

  // Behavior
  { key: "pin",              type: "bool", label: "Pin",               description: "Pin floating window to all workspaces",                  defaultValue: false, category: "behavior" },
  { key: "no_focus",         type: "bool", label: "No focus",          description: "Prevent window from being focused",                      defaultValue: false, category: "behavior" },
  { key: "no_initial_focus", type: "bool", label: "No initial focus",  description: "Don't focus this window when it opens",                  defaultValue: false, category: "behavior" },
  { key: "no_blur",          type: "bool", label: "No blur",           description: "Disable blur behind this window",                        defaultValue: false, category: "behavior" },
  { key: "no_border",        type: "bool", label: "No border",         description: "Remove window border entirely",                          defaultValue: false, category: "behavior" },
  { key: "no_shadow",        type: "bool", label: "No shadow",         description: "Remove window shadow",                                   defaultValue: false, category: "behavior" },
  { key: "no_dim",           type: "bool", label: "No dim",            description: "Don't dim this window when inactive",                    defaultValue: false, category: "behavior" },
  { key: "keep_aspect_ratio", type: "bool", label: "Keep aspect ratio", description: "Preserve aspect ratio when resizing",                   defaultValue: false, category: "behavior" },

  // Advanced
  { key: "tag",              type: "string", label: "Tag",              description: "Add (+name) or remove (-name) a tag",                    defaultValue: "",    category: "advanced" },
  { key: "group",            type: "string", label: "Group",            description: "Group behavior (set, new, lock, deny, etc.)",            defaultValue: "",    category: "advanced" },
  { key: "suppress_event",   type: "string", label: "Suppress event",   description: "Suppress events (maximize, minimize, activate, etc.)",   defaultValue: "",    category: "advanced" },
  { key: "animation",        type: "string", label: "Animation",        description: "Override animation style for this window",               defaultValue: "",    category: "advanced" },
  { key: "content",          type: "string", label: "Content type",     description: "Content type hint (none, photo, video, game)",           defaultValue: "",    category: "advanced" },

  // Plugin (hyprbars)
  { key: "hyprbars:no_bar",  type: "bool",  label: "No title bar",     description: "Hide hyprbars title bar decoration",                     defaultValue: false, category: "plugin" }
]

// Match property options shown in the picker.
var MATCH_PROPERTIES = [
  { key: "class",         label: "Class",         description: "Window class (application identifier)" },
  { key: "title",         label: "Title",         description: "Current window title" },
  { key: "initial_class", label: "Initial Class", description: "Class when window first opened" },
  { key: "initial_title", label: "Initial Title", description: "Title when window first opened" }
]


// ---------------------------------------------------------------------------
// Client parsing
// ---------------------------------------------------------------------------

function parseClients(raw) {
  var clients = []
  try {
    clients = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    clients = []
  }
  if (!Array.isArray(clients)) return []

  return clients.map(function(c) {
    return {
      address:      String(c.address || ""),
      class:        String(c.class || ""),
      title:        String(c.title || ""),
      initialClass: String(c.initialClass || ""),
      initialTitle: String(c.initialTitle || ""),
      pid:          Number(c.pid) || 0,
      xwayland:     c.xwayland === true,
      floating:     c.floating === true,
      monitor:      Number(c.monitor) || 0,
      workspace:    c.workspace ? (c.workspace.id || 0) : 0,
      at:           Array.isArray(c.at) ? c.at : [0, 0],
      size:         Array.isArray(c.size) ? c.size : [0, 0],
      mapped:       c.mapped !== false,
      hidden:       c.hidden === true,
      pinned:       c.pinned === true,
      fullscreen:   Number(c.fullscreen) || 0,
      tags:         Array.isArray(c.tags) ? c.tags : []
    }
  }).filter(function(c) { return c.mapped && !c.hidden })
}


// ---------------------------------------------------------------------------
// Regex helpers
// ---------------------------------------------------------------------------

function escapeRegex(str) {
  return String(str).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

function anchoredRegex(str) {
  return "^" + escapeRegex(str) + "$"
}


// ---------------------------------------------------------------------------
// Rule ID generation
// ---------------------------------------------------------------------------

var _nextId = 1

function generateId() {
  return "wr-" + Date.now() + "-" + (_nextId++)
}


// ---------------------------------------------------------------------------
// Lua code generation
// ---------------------------------------------------------------------------

function luaQuote(text) {
  return '"' + String(text).replace(/[\\\"]/g, "\\$&").replace(/[\r\n]/g, " ") + '"'
}

// Convert a rule object to an o.window(...) Lua call.
function ruleToLua(rule) {
  if (!rule || !rule.match) return ""

  var matchKeys = Object.keys(rule.match).filter(function(k) {
    return rule.match[k] !== "" && rule.match[k] !== undefined && rule.match[k] !== null
  })
  var effectKeys = Object.keys(rule.effects || {}).filter(function(k) {
    var v = rule.effects[k]
    var schema = effectByKey(k)
    if (!schema) return v !== "" && v !== undefined && v !== null
    if (schema.type === "bool") return v === true
    if (schema.type === "int" || schema.type === "float") return v !== schema.defaultValue && v !== -1 && v !== "" && v !== undefined
    return v !== "" && v !== undefined && v !== null
  })

  if (matchKeys.length === 0 || effectKeys.length === 0) return ""

  // Build match argument
  var matchArg
  if (matchKeys.length === 1 && matchKeys[0] === "class") {
    matchArg = luaQuote(rule.match.class)
  } else {
    var matchParts = matchKeys.map(function(k) {
      return k + " = " + luaQuote(rule.match[k])
    })
    matchArg = "{ " + matchParts.join(", ") + " }"
  }

  // Build effects table
  var effectParts = effectKeys.map(function(k) {
    var v = rule.effects[k]
    var schema = effectByKey(k)
    var luaKey = k.indexOf(":") >= 0 ? '["' + k + '"]' : k

    if (schema && schema.type === "bool") {
      return luaKey + " = " + (v ? "true" : "false")
    } else if (schema && (schema.type === "int" || schema.type === "float")) {
      return luaKey + " = " + v
    } else {
      return luaKey + " = " + luaQuote(String(v))
    }
  })

  return "o.window(" + matchArg + ", { " + effectParts.join(", ") + " })"
}

function effectByKey(key) {
  for (var i = 0; i < EFFECT_SCHEMA.length; i++) {
    if (EFFECT_SCHEMA[i].key === key) return EFFECT_SCHEMA[i]
  }
  return null
}


// ---------------------------------------------------------------------------
// Build entire managed block from rules array
// ---------------------------------------------------------------------------

function buildManagedBlock(rules) {
  var lines = []
  for (var i = 0; i < rules.length; i++) {
    if (!rules[i].enabled) continue
    var lua = ruleToLua(rules[i])
    if (lua) lines.push(lua)
  }
  return lines.join("\n")
}


// ---------------------------------------------------------------------------
// Parse managed block back to rule objects
// ---------------------------------------------------------------------------

function parseManagedBlock(text) {
  var rules = []
  if (!text) return rules

  var lines = String(text).split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line || line.indexOf("--") === 0) continue

    var rule = parseLuaWindowRule(line)
    if (rule) {
      rule.id = generateId()
      rule.enabled = true
      rules.push(rule)
    }
  }
  return rules
}

// Parse a single o.window(...) line back into a rule object.
// This handles the two forms:
//   o.window("^pattern$", { key = value, ... })
//   o.window({ class = "^x$", title = "^y$" }, { key = value, ... })
function parseLuaWindowRule(line) {
  // Strip o.window( ... ) wrapper
  var inner = line.replace(/^o\.window\(\s*/, "").replace(/\s*\)\s*$/, "")
  if (inner === line) return null // didn't match

  // Split at the comma between match arg and effects table.
  // We need to find the comma that separates the two top-level arguments.
  var args = splitTopLevelArgs(inner)
  if (args.length < 2) return null

  var matchArg = args[0].trim()
  var effectsArg = args[1].trim()

  var match = {}
  var effects = {}

  // Parse match
  if (matchArg.charAt(0) === '"' || matchArg.charAt(0) === "'") {
    // Simple string match = class regex
    match.class = unquoteLua(matchArg)
  } else if (matchArg.charAt(0) === "{") {
    match = parseLuaTable(matchArg)
  }

  // Parse effects
  if (effectsArg.charAt(0) === "{") {
    effects = parseLuaTable(effectsArg)
  }

  // Convert string "true"/"false" to booleans where the schema says bool
  for (var key in effects) {
    var schema = effectByKey(key)
    if (schema) {
      if (schema.type === "bool") {
        effects[key] = effects[key] === true || effects[key] === "true"
      } else if (schema.type === "int") {
        effects[key] = parseInt(effects[key], 10) || 0
      } else if (schema.type === "float") {
        effects[key] = parseFloat(effects[key]) || 0
      }
    }
  }

  return { match: match, effects: effects }
}

// Split a string by top-level commas (not inside braces or quotes).
function splitTopLevelArgs(s) {
  var args = []
  var depth = 0
  var inStr = false
  var strChar = ""
  var current = ""

  for (var i = 0; i < s.length; i++) {
    var c = s.charAt(i)

    if (inStr) {
      current += c
      if (c === "\\" && i + 1 < s.length) {
        current += s.charAt(++i)
      } else if (c === strChar) {
        inStr = false
      }
      continue
    }

    if (c === '"' || c === "'") {
      inStr = true
      strChar = c
      current += c
    } else if (c === "{" || c === "[" || c === "(") {
      depth++
      current += c
    } else if (c === "}" || c === "]" || c === ")") {
      depth--
      current += c
    } else if (c === "," && depth === 0) {
      args.push(current)
      current = ""
    } else {
      current += c
    }
  }

  if (current.trim()) args.push(current)
  return args
}

// Parse a simple Lua table literal: { key = value, key2 = value2 }
function parseLuaTable(s) {
  var result = {}
  var inner = s.replace(/^\{\s*/, "").replace(/\s*\}$/, "")
  var pairs = splitTopLevelArgs(inner)

  for (var i = 0; i < pairs.length; i++) {
    var pair = pairs[i].trim()
    if (!pair) continue

    var eqIndex = -1
    // Handle ["key:with:colon"] = value
    if (pair.charAt(0) === "[") {
      var closeBracket = pair.indexOf("]")
      if (closeBracket < 0) continue
      eqIndex = pair.indexOf("=", closeBracket)
      if (eqIndex < 0) continue
      var bracketKey = pair.substring(1, closeBracket).trim()
      bracketKey = unquoteLua(bracketKey)
      var bracketVal = pair.substring(eqIndex + 1).trim()
      result[bracketKey] = parseLuaValue(bracketVal)
    } else {
      eqIndex = pair.indexOf("=")
      if (eqIndex < 0) continue
      var key = pair.substring(0, eqIndex).trim()
      var val = pair.substring(eqIndex + 1).trim()
      result[key] = parseLuaValue(val)
    }
  }
  return result
}

function parseLuaValue(s) {
  s = s.trim()
  if (s === "true") return true
  if (s === "false") return false
  if (s === "nil") return null
  if ((s.charAt(0) === '"' && s.charAt(s.length - 1) === '"') ||
      (s.charAt(0) === "'" && s.charAt(s.length - 1) === "'")) {
    return unquoteLua(s)
  }
  var num = Number(s)
  if (isFinite(num)) return num
  return s
}

function unquoteLua(s) {
  s = s.trim()
  if ((s.charAt(0) === '"' && s.charAt(s.length - 1) === '"') ||
      (s.charAt(0) === "'" && s.charAt(s.length - 1) === "'")) {
    s = s.substring(1, s.length - 1)
  }
  return s.replace(/\\(.)/g, "$1")
}


// ---------------------------------------------------------------------------
// Human-readable summaries
// ---------------------------------------------------------------------------

function matchDescription(match) {
  if (!match) return "No match"
  var parts = []
  if (match.class) parts.push("class: " + match.class)
  if (match.title) parts.push("title: " + match.title)
  if (match.initial_class) parts.push("initialClass: " + match.initial_class)
  if (match.initial_title) parts.push("initialTitle: " + match.initial_title)
  if (match.xwayland) parts.push("xwayland")
  return parts.length > 0 ? parts.join(", ") : "All windows"
}

function effectSummary(effects) {
  if (!effects) return "No effects"
  var parts = []
  var keys = Object.keys(effects)
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i]
    var v = effects[k]
    var schema = effectByKey(k)
    if (!schema) { parts.push(k); continue }

    if (schema.type === "bool") {
      if (v === true) parts.push(schema.label)
    } else if (v !== "" && v !== undefined && v !== null && v !== schema.defaultValue && v !== -1) {
      parts.push(schema.label + " " + v)
    }
  }
  return parts.length > 0 ? parts.join(", ") : "No effects"
}

// Return a short, friendly name for a client (class or title, whatever is shortest)
function clientLabel(client) {
  if (client.class) return client.class
  if (client.title) return client.title.substring(0, 40)
  return "Unknown"
}

// Parse opacity string or number into { active: int(0-100), inactive: int(0-100), fullscreen: int(0-100) }
function parseOpacity(val) {
  if (typeof val === "number") {
    var pct = Math.round(val * 100)
    return { active: pct, inactive: pct, fullscreen: 100 }
  }
  var str = String(val || "").trim()
  var parts = str.split(/\s+/).map(parseFloat).filter(function(n) { return !isNaN(n) })
  if (parts.length === 0) return { active: 100, inactive: 100, fullscreen: 100 }
  if (parts.length === 1) {
    var v = Math.round(parts[0] * 100)
    return { active: v, inactive: v, fullscreen: 100 }
  }
  if (parts.length === 2) {
    return { active: Math.round(parts[0] * 100), inactive: Math.round(parts[1] * 100), fullscreen: 100 }
  }
  return {
    active: Math.round(parts[0] * 100),
    inactive: Math.round(parts[1] * 100),
    fullscreen: Math.round(parts[2] * 100)
  }
}

// Format percentages back to Hyprland lua opacity string: "active inactive [fullscreen]"
function formatOpacity(activePct, inactivePct, fullscreenPct) {
  var a = (activePct / 100).toFixed(2)
  var i = (inactivePct / 100).toFixed(2)
  var f = (fullscreenPct !== undefined ? fullscreenPct / 100 : 1.0).toFixed(2)
  if (f === "1.00" && a === i) {
    return a + " " + i + " 1.0"
  }
  return a + " " + i + " " + (f === "1.00" ? "1.0" : f)
}

// Return effects grouped by category for UI rendering.
function effectsByCategory() {
  var groups = []
  for (var i = 0; i < EFFECT_CATEGORIES.length; i++) {
    var cat = EFFECT_CATEGORIES[i]
    var items = EFFECT_SCHEMA.filter(function(e) { return e.category === cat.id })
    if (items.length > 0) {
      groups.push({ id: cat.id, label: cat.label, icon: cat.icon, effects: items })
    }
  }
  return groups
}

// Return list of schema entries that are currently active on this rule
function appliedProperties(effects) {
  if (!effects) return []
  var list = []
  for (var i = 0; i < EFFECT_SCHEMA.length; i++) {
    var schema = EFFECT_SCHEMA[i]
    if (effects[schema.key] !== undefined) {
      list.push(schema)
    }
  }
  // Also include any unknown/custom keys that exist in effects
  for (var k in effects) {
    var found = false
    for (var j = 0; j < EFFECT_SCHEMA.length; j++) {
      if (EFFECT_SCHEMA[j].key === k) { found = true; break }
    }
    if (!found) {
      list.push({ key: k, type: "string", label: k, category: "advanced", defaultValue: "" })
    }
  }
  return list
}

// Return schema entries grouped by category that are NOT yet applied to this rule
function availableProperties(effects) {
  var eff = effects || {}
  var groups = []
  for (var i = 0; i < EFFECT_CATEGORIES.length; i++) {
    var cat = EFFECT_CATEGORIES[i]
    var items = EFFECT_SCHEMA.filter(function(e) {
      return e.category === cat.id && eff[e.key] === undefined
    })
    if (items.length > 0) {
      groups.push({ id: cat.id, label: cat.label, icon: cat.icon, effects: items })
    }
  }
  return groups
}

// Generate a human-friendly KDE-style rule title
function ruleTitle(rule) {
  if (!rule) return "Rule"
  if (rule.description && rule.description.trim()) return rule.description.trim()

  var matchStr = ""
  if (rule.match) {
    if (rule.match.class) {
      var cls = String(rule.match.class).replace(/^\^/, "").replace(/\$$/, "")
      matchStr = cls
    } else if (rule.match.title) {
      var tit = String(rule.match.title).replace(/^\^/, "").replace(/\$$/, "")
      matchStr = tit
    }
  }

  var effStr = ""
  if (rule.effects) {
    var effParts = []
    if (rule.effects.float) effParts.push("Float")
    if (rule.effects.tile) effParts.push("Tile")
    if (rule.effects.opacity) effParts.push("Opacity " + rule.effects.opacity)
    if (rule.effects.workspace) effParts.push("Workspace " + rule.effects.workspace)
    if (rule.effects.monitor) effParts.push("Monitor " + rule.effects.monitor)
    if (effParts.length > 0) effStr = effParts.join(", ")
  }

  if (matchStr && effStr) return matchStr + " (" + effStr + ")"
  if (matchStr) return matchStr
  if (rule.section) return rule.section
  return "Window Rule"
}


// ---------------------------------------------------------------------------
// Eval code generation for live preview
// ---------------------------------------------------------------------------

function ruleToEvalCode(rule) {
  var lua = ruleToLua(rule)
  if (!lua) return ""
  return lua
}


function matchesClient(client, match) {
  if (!client || !match) return false
  if (match.class) {
    try {
      var re = new RegExp(match.class)
      if (!re.test(client.class)) return false
    } catch (_) { return false }
  }
  if (match.title) {
    try {
      var re = new RegExp(match.title)
      if (!re.test(client.title)) return false
    } catch (_) { return false }
  }
  if (match.initial_class) {
    try {
      var re = new RegExp(match.initial_class)
      if (!re.test(client.initialClass)) return false
    } catch (_) { return false }
  }
  if (match.initial_title) {
    try {
      var re = new RegExp(match.initial_title)
      if (!re.test(client.initialTitle)) return false
    } catch (_) { return false }
  }
  return true
}


// ---------------------------------------------------------------------------
// Exports for Node testing
// ---------------------------------------------------------------------------

if (typeof module !== "undefined") {
  module.exports = {
    EFFECT_SCHEMA: EFFECT_SCHEMA,
    EFFECT_CATEGORIES: EFFECT_CATEGORIES,
    MATCH_PROPERTIES: MATCH_PROPERTIES,
    parseClients: parseClients,
    escapeRegex: escapeRegex,
    anchoredRegex: anchoredRegex,
    generateId: generateId,
    ruleToLua: ruleToLua,
    buildManagedBlock: buildManagedBlock,
    parseManagedBlock: parseManagedBlock,
    matchDescription: matchDescription,
    effectSummary: effectSummary,
    clientLabel: clientLabel,
    effectsByCategory: effectsByCategory,
    appliedProperties: appliedProperties,
    availableProperties: availableProperties,
    ruleTitle: ruleTitle,
    parseOpacity: parseOpacity,
    formatOpacity: formatOpacity,
    effectByKey: effectByKey,
    ruleToEvalCode: ruleToEvalCode,
    matchesClient: matchesClient
  }
}
