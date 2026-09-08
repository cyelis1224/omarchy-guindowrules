pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Shared state for the GUIndowRules Editor.
// Manages the rule list, two-way sync with ~/.config/hypr/windowrules.lua,
// client picker, and live reload via hyprctl reload.
Item {
  id: store

  readonly property string pluginId: "dagyr.guindowrules"
  readonly property string luaScript: Qt.resolvedUrl("windowrules-lua.sh").toString().replace(/^file:\/\//, "")

  // --- State ---
  property var rules: []                  // Array of rule objects from windowrules.lua
  property string tail: ""               // Preserved non-rule tail from windowrules.lua (layer rules, etc.)
  property var clients: []               // Live client list from hyprctl
  property string selectedRuleId: ""     // Currently editing rule ID
  property bool pickerActive: false      // Whether the crosshair picker overlay is showing
  property var pickedClient: null        // Client picked by the crosshair
  property bool dirty: false             // Unsaved changes

  // Convenience
  readonly property var selectedRule: {
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].id === selectedRuleId) return rules[i]
    }
    return null
  }

  readonly property int enabledCount: {
    var n = 0
    for (var i = 0; i < rules.length; i++) if (rules[i].enabled) n++
    return n
  }

  // Schema references for UI
  readonly property var effectCategories: Model.EFFECT_CATEGORIES
  readonly property var effectSchema: Model.EFFECT_SCHEMA
  readonly property var matchProperties: Model.MATCH_PROPERTIES

  // --- Methods ---

  function refresh() {
    if (!clientsProc.running) clientsProc.running = true
    if (!readProc.running) readProc.running = true
  }

  function refreshClients() {
    if (!clientsProc.running) clientsProc.running = true
  }

  function selectRule(id) {
    selectedRuleId = id
  }

  function addRule(match, effects, section) {
    var rule = {
      id: Model.generateId(),
      enabled: true,
      section: section || "",
      description: "",
      match: match || { class: "^.*$" },
      effects: effects || { float: true }
    }
    var next = rules.slice()
    next.unshift(rule) // Add at top of list
    rules = next
    selectedRuleId = rule.id
    dirty = true
    applyAndSave()
    return rule
  }

  function updateRule(id, patch) {
    var next = rules.slice()
    var updatedRule = null
    for (var i = 0; i < next.length; i++) {
      if (next[i].id === id) {
        var updated = JSON.parse(JSON.stringify(next[i]))
        if (patch.match) {
          for (var mk in patch.match) updated.match[mk] = patch.match[mk]
        }
        if (patch.effects) {
          for (var ek in patch.effects) updated.effects[ek] = patch.effects[ek]
        }
        if (patch.enabled !== undefined) updated.enabled = patch.enabled
        if (patch.description !== undefined) updated.description = patch.description
        if (patch.section !== undefined) updated.section = patch.section
        next[i] = updated
        updatedRule = updated
        break
      }
    }
    rules = next
    dirty = true
    applyAndSave()

    if (updatedRule && updatedRule.effects && updatedRule.effects.opacity) {
      liveApplyOpacity(updatedRule.match, updatedRule.effects.opacity)
    }
  }

  function addEffectProperty(ruleId, key) {
    var schema = Model.effectByKey(key)
    var defVal = true
    if (schema) {
      if (schema.type === "bool") defVal = true
      else if (schema.type === "opacity") defVal = "0.80 0.80"
      else if (schema.type === "int") defVal = schema.defaultValue !== -1 ? schema.defaultValue : 0
      else if (schema.type === "float") defVal = 1.0
      else if (schema.type === "enum" && schema.options && schema.options.length > 1) defVal = schema.options[1].value
      else defVal = schema.defaultValue || ""
    }
    var next = rules.slice()
    for (var i = 0; i < next.length; i++) {
      if (next[i].id === ruleId) {
        var updated = JSON.parse(JSON.stringify(next[i]))
        if (!updated.effects) updated.effects = {}
        updated.effects[key] = defVal
        next[i] = updated
        break
      }
    }
    rules = next
    dirty = true
    applyAndSave()
  }

  function removeEffectProperty(ruleId, key) {
    var next = rules.slice()
    var targetRule = null
    for (var i = 0; i < next.length; i++) {
      if (next[i].id === ruleId) {
        var updated = JSON.parse(JSON.stringify(next[i]))
        if (updated.effects && updated.effects[key] !== undefined) {
          delete updated.effects[key]
        }
        next[i] = updated
        targetRule = updated
        break
      }
    }
    rules = next
    dirty = true
    applyAndSave()

    if (key === "opacity" && targetRule) {
      liveApplyOpacity(targetRule.match, "1.0 1.0")
    }
  }

  function liveApplyOpacity(match, opacityValue) {
    if (!clients || clients.length === 0) return
    var parts = String(opacityValue || "").trim().split(/\s+/)
    var activeVal = parts[0] || "1.0"
    var inactiveVal = parts[1] || activeVal
    var val = activeVal + " " + inactiveVal
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      if (Model.matchesClient(c, match)) {
        var cmd = 'hl.dsp.window.set_prop({ window = "address:' + c.address + '", prop = "opacity", value = "' + val + '" })'
        livePropProc.command = ["hyprctl", "dispatch", cmd]
        livePropProc.running = true
      }
    }
  }

  function duplicateRule(ruleId) {
    var next = rules.slice()
    for (var i = 0; i < next.length; i++) {
      if (next[i].id === ruleId) {
        var dup = JSON.parse(JSON.stringify(next[i]))
        dup.id = Model.generateId()
        dup.description = (dup.description || Model.ruleTitle(next[i])) + " (Copy)"
        next.splice(i + 1, 0, dup)
        rules = next
        selectedRuleId = dup.id
        dirty = true
        applyAndSave()
        return
      }
    }
  }

  function removeRule(id) {
    var next = rules.filter(function(r) { return r.id !== id })
    rules = next
    if (selectedRuleId === id) selectedRuleId = ""
    dirty = true
    applyAndSave()
  }

  function toggleRule(id) {
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].id === id) {
        updateRule(id, { enabled: !rules[i].enabled })
        return
      }
    }
  }

  function moveRuleUp(id) {
    var next = rules.slice()
    for (var i = 1; i < next.length; i++) {
      if (next[i].id === id) {
        var tmp = next[i - 1]
        next[i - 1] = next[i]
        next[i] = tmp
        rules = next
        dirty = true
        applyAndSave()
        return
      }
    }
  }

  function moveRuleDown(id) {
    var next = rules.slice()
    for (var i = 0; i < next.length - 1; i++) {
      if (next[i].id === id) {
        var tmp = next[i + 1]
        next[i + 1] = next[i]
        next[i] = tmp
        rules = next
        dirty = true
        applyAndSave()
        return
      }
    }
  }

  function startPicker() {
    refreshClients()
    pickerActive = true
    pickedClient = null
  }

  function cancelPicker() {
    pickerActive = false
    pickedClient = null
  }

  function finishPicker(client, matchProps) {
    pickerActive = false
    pickedClient = null

    var match = {}
    for (var key in matchProps) {
      if (matchProps[key]) {
        match[key] = matchProps[key]
      }
    }

    var desc = client ? (client.class || client.title || "") : ""
    addRule(match, { float: true }, desc)
    openProc.running = true
  }

  function applyAndSave() {
    var payload = JSON.stringify({ rules: rules, tail: tail })
    saveProc.command = ["bash", "-c", "printf '%s' \"$1\" | \"$0\" write", store.luaScript, payload]
    saveProc.running = true
  }

  // --- Initialization ---
  Component.onCompleted: refresh()

  // --- Processes ---

  // Read full windowrules.lua
  Process {
    id: readProc
    command: ["bash", store.luaScript, "read"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = text.trim()
        if (out) {
          try {
            var data = JSON.parse(out)
            store.rules = data.rules || []
            store.tail = data.tail || ""
          } catch (e) {
            console.error("Failed to parse windowrules JSON:", e)
          }
        }
      }
    }
  }

  // Refresh client list
  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        store.clients = Model.parseClients(text)
      }
    }
  }

  // Save rules to file and reload Hyprland
  Process {
    id: saveProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (!running) store.dirty = false
    }
  }

  // Open GUI panel via IPC
  Process {
    id: openProc
    command: ["omarchy-shell", store.pluginId, "open"]
    stdout: StdioCollector { waitForEnd: true }
  }

  // Live property preview dispatcher
  Process {
    id: livePropProc
    stdout: StdioCollector { waitForEnd: true }
  }
}
