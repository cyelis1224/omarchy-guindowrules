import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// KDE-style Window Rules manager for Omarchy.
// Directly manages ~/.config/hypr/windowrules.lua with full round-trip sync.
Panel {
  id: root
  moduleName: RuleStore.pluginId
  ipcTarget: RuleStore.pluginId
  manageIpc: false

  IpcHandler {
    target: RuleStore.pluginId
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function pick() { RuleStore.startPicker() }
    function state(): string { return JSON.stringify({ rules: RuleStore.rules, selectedRuleId: RuleStore.selectedRuleId }) }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) RuleStore.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱂬"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(12)

          // ========== Hero ==========
          PanelHero {
            width: parent.width
            title: "GUIndowRules"
            meta: RuleStore.rules.length + " rules (" + RuleStore.enabledCount + " active)"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : ""
            iconComponent: Component {
              Text {
                text: "󱂬"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : ""
                font.pixelSize: Style.font.display
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          // ========== Top Actions (KDE-style Detect & Add) ==========
          Row {
            width: parent.width - Style.space(16)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            // Detect Window Properties (Crosshair picker)
            Rectangle {
              width: (parent.width - parent.spacing) * 0.58
              height: Style.space(40)
              radius: Style.cornerRadius
              color: Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.close()
                  RuleStore.startPicker()
                }
              }

              Row {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "󰓾"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : ""
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "Detect Window"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : ""
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            // Add Rule Manually
            Rectangle {
              width: (parent.width - parent.spacing) * 0.42
              height: Style.space(40)
              radius: Style.cornerRadius
              color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: RuleStore.addRule({ class: "^.*$" }, { float: true }, "Custom Rule")
              }

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text {
                  text: "󰐕"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : ""
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "Add New Rule"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : ""
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          // =================================================================
          // KDE-STYLE RULE DETAIL EDITOR (when a rule is selected)
          // =================================================================
          Column {
            id: editorSection
            width: parent.width
            spacing: Style.space(12)
            visible: RuleStore.selectedRule !== null

            // Rule Header & Description
            Column {
              width: parent.width - Style.space(16)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              Row {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  text: "EDITING RULE"
                  color: Color.accent
                  font.family: root.bar ? root.bar.fontFamily : ""
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                  width: Math.max(Style.space(4), parent.width - Style.space(90) - editActionButtons.implicitWidth)
                  height: 1
                }

                Row {
                  id: editActionButtons
                  spacing: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter

                  Button {
                    text: "󰁝"
                    tooltipText: "Move rule up"
                    fontSize: Style.font.caption
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : ""
                    onClicked: RuleStore.moveRuleUp(RuleStore.selectedRuleId)
                  }

                  Button {
                    text: "󰁅"
                    tooltipText: "Move rule down"
                    fontSize: Style.font.caption
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : ""
                    onClicked: RuleStore.moveRuleDown(RuleStore.selectedRuleId)
                  }

                  Button {
                    text: "󰉍 Copy"
                    tooltipText: "Duplicate this rule"
                    fontSize: Style.font.caption
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : ""
                    onClicked: RuleStore.duplicateRule(RuleStore.selectedRuleId)
                  }

                  Button {
                    text: "󰆴 Delete"
                    tooltipText: "Delete this rule permanently"
                    bordered: true
                    fontSize: Style.font.caption
                    foreground: Color.error || "#ff5555"
                    fontFamily: root.bar ? root.bar.fontFamily : ""
                    onClicked: RuleStore.removeRule(RuleStore.selectedRuleId)
                  }

                  Button {
                    text: "󰅖 Done"
                    tooltipText: "Close editor"
                    bordered: true
                    fontSize: Style.font.caption
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : ""
                    onClicked: RuleStore.selectRule("")
                  }
                }
              }

              // Description input
              Rectangle {
                width: parent.width
                height: Style.spacing.controlHeight
                radius: Style.cornerRadius * 0.6
                color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

                TextInput {
                  id: descInput
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : ""
                  font.pixelSize: Style.font.body
                  text: RuleStore.selectedRule ? (RuleStore.selectedRule.description || RuleStore.selectedRule.section || "") : ""
                  selectByMouse: true
                  clip: true
                  verticalAlignment: TextInput.AlignVCenter
                  Timer {
                    id: descTimer
                    interval: 350
                    repeat: false
                    onTriggered: {
                      if (RuleStore.selectedRule) {
                        RuleStore.updateRule(RuleStore.selectedRuleId, { description: descInput.text.trim(), section: descInput.text.trim() })
                      }
                    }
                  }

                  onTextEdited: descTimer.restart()
                  onAccepted: { descTimer.stop(); descTimer.triggered() }
                  onActiveFocusChanged: if (!activeFocus && descTimer.running) { descTimer.stop(); descTimer.triggered() }

                  Text {
                    anchors.fill: parent
                    text: "Rule Description / Section name..."
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 2.0)
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.caption
                    visible: !descInput.text && !descInput.activeFocus
                    verticalAlignment: Text.AlignVCenter
                  }
                }
              }
            }

            // ========== Section 1: Window Matching Criteria ==========
            PanelSectionHeader {
              text: "WINDOW MATCHING"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : ""
            }

            Repeater {
              model: Model.MATCH_PROPERTIES

              Column {
                required property var modelData
                width: editorSection.width - Style.space(16)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.spacing.labelGap

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: modelData.label
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "· " + modelData.description
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 2.2)
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.spacing.controlHeight
                  radius: Style.cornerRadius * 0.6
                  color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

                  TextInput {
                    id: matchInput
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.body
                    text: RuleStore.selectedRule ? (RuleStore.selectedRule.match[modelData.key] || "") : ""
                    selectByMouse: true
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter

                    Timer {
                      id: matchTimer
                      interval: 350
                      repeat: false
                      onTriggered: {
                        if (!RuleStore.selectedRule) return
                        var patch = {}
                        patch[modelData.key] = matchInput.text.trim()
                        RuleStore.updateRule(RuleStore.selectedRuleId, { match: patch })
                      }
                    }

                    onTextEdited: matchTimer.restart()
                    onAccepted: { matchTimer.stop(); matchTimer.triggered() }
                    onActiveFocusChanged: if (!activeFocus && matchTimer.running) { matchTimer.stop(); matchTimer.triggered() }
                  }
                }
              }
            }

            // ========== Section 2: Applied Properties (KDE-Style) ==========
            PanelSectionHeader {
              text: "APPLIED PROPERTIES"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : ""
            }

            // Active properties list
            Repeater {
              model: RuleStore.selectedRule ? Model.appliedProperties(RuleStore.selectedRule.effects) : []

              Rectangle {
                id: propCard
                required property var modelData
                width: editorSection.width - Style.space(16)
                anchors.horizontalCenter: parent.horizontalCenter
                implicitHeight: cardContentCol.implicitHeight + Style.space(20)
                height: implicitHeight
                radius: Style.cornerRadius * 0.6
                color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.12)

                Column {
                  id: cardContentCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  // Header: Label, Description, Remove Button
                  Item {
                    width: parent.width
                    height: Math.max(propLabelRow.implicitHeight, deletePropBtn.height)

                    Row {
                      id: propLabelRow
                      anchors.left: parent.left
                      anchors.right: deletePropBtn.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Text {
                        id: pLabel
                        text: modelData.label
                        color: root.bar ? root.bar.foreground : Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : ""
                        font.pixelSize: Style.font.body
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        text: "· " + (modelData.description || modelData.key)
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
                        font.family: root.bar ? root.bar.fontFamily : ""
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: Math.max(0, propLabelRow.width - pLabel.implicitWidth - propLabelRow.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    // Remove property button (×)
                    MouseArea {
                      id: deletePropBtn
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(26)
                      height: Style.space(26)
                      cursorShape: Qt.PointingHandCursor
                      hoverEnabled: true
                      onClicked: RuleStore.removeEffectProperty(RuleStore.selectedRuleId, modelData.key)

                      Rectangle {
                        anchors.fill: parent
                        radius: Style.cornerRadius * 0.4
                        color: parent.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.15) : "transparent"
                      }

                      Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: parent.containsMouse ? (Color.error || "#ff5555") : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
                        font.family: root.bar ? root.bar.fontFamily : ""
                        font.pixelSize: Style.font.body
                      }
                    }
                  }

                  // Property Control Loader
                  Loader {
                    width: parent.width
                    property var effectSchema: modelData
                    sourceComponent: {
                      if (modelData.type === "bool") return boolControl
                      if (modelData.type === "enum") return enumControl
                      if (modelData.type === "opacity" || modelData.key === "opacity") return opacityControl
                      return stringControl
                    }
                  }
                }
              }
            }

            // Empty state for applied properties
            Text {
              visible: RuleStore.selectedRule && Object.keys(RuleStore.selectedRule.effects || {}).length === 0
              width: parent.width
              text: "No properties applied yet. Click \"+ Add Property\" below to configure one."
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
              font.family: root.bar ? root.bar.fontFamily : ""
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(4)
              bottomPadding: Style.space(4)
            }

            // ========== "+ Add Property..." Picker (KDE-style) ==========
            Column {
              id: addPropertySection
              width: editorSection.width - Style.space(16)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              property bool expanded: false

              Rectangle {
                width: parent.width
                height: Style.space(36)
                radius: Style.cornerRadius * 0.6
                color: addPropertySection.expanded
                  ? Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                  : Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: addPropertySection.expanded = !addPropertySection.expanded
                }

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    text: addPropertySection.expanded ? "󰅃" : "󰐕"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: addPropertySection.expanded ? "Close Property List" : "+ Add Property..."
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              // Categorized property options list
              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: addPropertySection.expanded

                Repeater {
                  model: RuleStore.selectedRule ? Model.availableProperties(RuleStore.selectedRule.effects) : []

                  Column {
                    required property var modelData
                    width: parent.width
                    spacing: Style.space(4)

                    Row {
                      spacing: Style.space(6)
                      Text {
                        text: modelData.icon
                        color: Color.accent
                        font.family: root.bar ? root.bar.fontFamily : ""
                        font.pixelSize: Style.font.caption
                      }
                      Text {
                        text: modelData.label
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : ""
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: modelData.effects

                        Rectangle {
                          required property var modelData
                          width: propPillText.implicitWidth + Style.space(16)
                          height: Style.space(26)
                          radius: Style.space(13)
                          color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.07)
                          border.width: 1
                          border.color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.15)

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              RuleStore.addEffectProperty(RuleStore.selectedRuleId, modelData.key)
                            }
                          }

                          Text {
                            id: propPillText
                            anchors.centerIn: parent
                            text: "+ " + modelData.label
                            color: root.bar ? root.bar.foreground : Color.foreground
                            font.family: root.bar ? root.bar.fontFamily : ""
                            font.pixelSize: Style.font.caption
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }
          }

          // =================================================================
          // MASTER RULES LIST (Shows all rules from windowrules.lua)
          // =================================================================
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "ALL WINDOW RULES (" + RuleStore.rules.length + ")"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : ""
            }

            // Empty state
            Text {
              visible: RuleStore.rules.length === 0
              width: parent.width
              text: "No window rules found in windowrules.lua."
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
              font.family: root.bar ? root.bar.fontFamily : ""
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(12)
              bottomPadding: Style.space(12)
            }

            Repeater {
              model: RuleStore.rules

              CursorSurface {
                id: ruleRow
                required property var modelData
                required property int index
                width: panelColumn.width
                implicitHeight: ruleInner.implicitHeight + Style.spacing.xl
                current: modelData.id === RuleStore.selectedRuleId
                hasCursor: ruleMouseArea.containsMouse
                foreground: root.bar ? root.bar.foreground : Color.foreground

                MouseArea {
                  id: ruleMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: RuleStore.selectRule(ruleRow.modelData.id === RuleStore.selectedRuleId ? "" : ruleRow.modelData.id)
                }

                Row {
                  id: ruleInner
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  // Rule icon
                  Text {
                    text: ruleRow.modelData.enabled ? "󰖲" : "󰖳"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    opacity: ruleRow.modelData.enabled ? 1.0 : 0.4
                    font.family: root.bar ? root.bar.fontFamily : ""
                    font.pixelSize: Style.font.title
                    width: Style.space(20)
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Rule text: title + match criteria + effects
                  Column {
                    width: parent.width - Style.space(20) - ruleToggle.width - Style.space(26) - parent.spacing * 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Row {
                      width: parent.width
                      spacing: Style.space(6)

                      Text {
                        text: Model.ruleTitle(ruleRow.modelData)
                        color: root.bar ? root.bar.foreground : Color.foreground
                        opacity: ruleRow.modelData.enabled ? 1.0 : 0.5
                        font.family: root.bar ? root.bar.fontFamily : ""
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight
                      }
                    }

                    Text {
                      width: parent.width
                      text: Model.matchDescription(ruleRow.modelData.match)
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      opacity: ruleRow.modelData.enabled ? 1.0 : 0.5
                      font.family: root.bar ? root.bar.fontFamily : ""
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: Model.effectSummary(ruleRow.modelData.effects)
                      color: Color.accent
                      opacity: ruleRow.modelData.enabled ? 0.9 : 0.4
                      font.family: root.bar ? root.bar.fontFamily : ""
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  // Enable/Disable Toggle
                  ToggleSwitch {
                    id: ruleToggle
                    checked: ruleRow.modelData.enabled
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: RuleStore.toggleRule(ruleRow.modelData.id)
                  }

                  // Direct Delete button on row
                  MouseArea {
                    width: Style.space(26)
                    height: Style.space(26)
                    anchors.verticalCenter: parent.verticalCenter
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: RuleStore.removeRule(ruleRow.modelData.id)

                    Rectangle {
                      anchors.fill: parent
                      radius: Style.cornerRadius * 0.4
                      color: parent.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.15) : "transparent"
                    }

                    Text {
                      anchors.centerIn: parent
                      text: "󰆴"
                      color: parent.containsMouse ? (Color.error || "#ff5555") : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
                      font.family: root.bar ? root.bar.fontFamily : ""
                      font.pixelSize: Style.font.body
                    }
                  }
                }
              }
            }
          }

          // ========== Footer ==========
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Row {
            width: parent.width - Style.space(16)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Button {
              text: "Edit windowrules.lua"
              tooltipText: "Open ~/.config/hypr/windowrules.lua in your editor"
              fontSize: Style.font.caption
              foreground: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              fontFamily: root.bar ? root.bar.fontFamily : ""
              onClicked: editFileProc.running = true
            }

            Button {
              text: "Refresh from file"
              tooltipText: "Re-read windowrules.lua from disk"
              fontSize: Style.font.caption
              foreground: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              fontFamily: root.bar ? root.bar.fontFamily : ""
              onClicked: RuleStore.refresh()
            }
          }

          // Bottom padding
          Item { width: 1; height: Style.space(8) }
        }
      }
    }
  }

  // --- Components for dynamic property loaders ---

  Component {
    id: boolControl

    Row {
      width: parent.width
      spacing: Style.space(12)

      ToggleSwitch {
        id: bToggle
        anchors.verticalCenter: parent.verticalCenter
        checked: {
          if (!RuleStore.selectedRule) return false
          return RuleStore.selectedRule.effects[effectSchema.key] === true
        }
        foreground: root.bar ? root.bar.foreground : Color.foreground
        onToggled: {
          if (!RuleStore.selectedRule) return
          var patch = {}
          patch[effectSchema.key] = !bToggle.checked
          RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: (RuleStore.selectedRule && RuleStore.selectedRule.effects[effectSchema.key] === true) ? "Enabled" : "Disabled"
        color: (RuleStore.selectedRule && RuleStore.selectedRule.effects[effectSchema.key] === true) ? Color.accent : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
        font.family: root.bar ? root.bar.fontFamily : ""
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  Component {
    id: enumControl

    Dropdown {
      width: Math.min(parent.width, Style.space(220))
      label: ""
      options: effectSchema.options || []
      value: {
        if (!RuleStore.selectedRule) return ""
        var v = RuleStore.selectedRule.effects[effectSchema.key]
        return v !== undefined && v !== null ? String(v) : ""
      }
      foreground: root.bar ? root.bar.foreground : Color.foreground
      fontFamily: root.bar ? root.bar.fontFamily : ""
      onChanged: function(v) {
        if (!RuleStore.selectedRule) return
        var patch = {}
        patch[effectSchema.key] = v
        RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
      }
    }
  }

  Component {
    id: stringControl

    Rectangle {
      width: parent.width
      height: Style.spacing.controlHeight
      radius: Style.cornerRadius * 0.6
      color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

      TextInput {
        id: effectInput
        anchors.fill: parent
        anchors.margins: Style.space(8)
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : ""
        font.pixelSize: Style.font.body
        selectByMouse: true
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        text: {
          if (!RuleStore.selectedRule) return ""
          var v = RuleStore.selectedRule.effects[effectSchema.key]
          return v !== undefined && v !== null ? String(v) : ""
        }

        Timer {
          id: strCommitTimer
          interval: 350
          repeat: false
          onTriggered: {
            if (!RuleStore.selectedRule) return
            var patch = {}
            var val = effectInput.text
            if (effectSchema.type === "int") val = parseInt(effectInput.text, 10) || 0
            else if (effectSchema.type === "float") val = parseFloat(effectInput.text) || 0
            patch[effectSchema.key] = val
            RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
          }
        }

        onTextEdited: strCommitTimer.restart()
        onAccepted: { strCommitTimer.stop(); strCommitTimer.triggered() }
        onActiveFocusChanged: if (!activeFocus && strCommitTimer.running) { strCommitTimer.stop(); strCommitTimer.triggered() }
      }
    }
  }

  // KDE-style rich Opacity Control (sliders, presets, raw input)
  Component {
    id: opacityControl

    Column {
      width: parent.width
      spacing: Style.space(10)

      readonly property var parsed: {
        if (!RuleStore.selectedRule) return { active: 100, inactive: 100, fullscreen: 100 }
        var v = RuleStore.selectedRule.effects[effectSchema.key]
        return Model.parseOpacity(v)
      }

      // Quick Presets Row
      Row {
        spacing: Style.space(6)

        Text {
          text: "Presets:"
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
          font.family: root.bar ? root.bar.fontFamily : ""
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Repeater {
          model: [100, 95, 90, 85, 80, 75, 70, 60]

          Rectangle {
            required property int modelData
            width: presetText.implicitWidth + Style.space(12)
            height: Style.space(24)
            radius: Style.space(12)
            color: (parsed.active === modelData && parsed.inactive === modelData)
              ? Color.accent
              : Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var formatted = Model.formatOpacity(modelData, modelData, 100)
                var patch = {}
                patch[effectSchema.key] = formatted
                RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
              }
            }

            Text {
              id: presetText
              anchors.centerIn: parent
              text: modelData + "%"
              color: (parsed.active === modelData && parsed.inactive === modelData)
                ? "white"
                : (root.bar ? root.bar.foreground : Color.foreground)
              font.family: root.bar ? root.bar.fontFamily : ""
              font.pixelSize: Style.font.caption
              font.bold: parsed.active === modelData
            }
          }
        }
      }

      // Active Window Opacity Slider
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          width: parent.width
          Text {
            text: "Active window: "
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : ""
            font.pixelSize: Style.font.caption
          }
          Text {
            text: parsed.active + "% (" + (parsed.active / 100).toFixed(2) + ")"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : ""
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        PanelSlider {
          id: activeSlider
          bar: root.bar
          width: parent.width
          minimum: 10
          maximum: 100
          step: 5
          integer: true
          value: parsed.active
          onMoved: function(v) {
            var formatted = Model.formatOpacity(Math.round(v), parsed.inactive, parsed.fullscreen)
            var patch = {}
            patch[effectSchema.key] = formatted
            RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
          }
        }
      }

      // Inactive Window Opacity Slider
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          width: parent.width
          Text {
            text: "Inactive window: "
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : ""
            font.pixelSize: Style.font.caption
          }
          Text {
            text: parsed.inactive + "% (" + (parsed.inactive / 100).toFixed(2) + ")"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : ""
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        PanelSlider {
          id: inactiveSlider
          bar: root.bar
          width: parent.width
          minimum: 10
          maximum: 100
          step: 5
          integer: true
          value: parsed.inactive
          onMoved: function(v) {
            var formatted = Model.formatOpacity(parsed.active, Math.round(v), parsed.fullscreen)
            var patch = {}
            patch[effectSchema.key] = formatted
            RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
          }
        }
      }

      // Raw String Field (for advanced values like "0.90 0.90 1.0")
      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "Raw value:"
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8)
          font.family: root.bar ? root.bar.fontFamily : ""
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
          width: parent.width - Style.space(80)
          height: Style.space(28)
          radius: Style.cornerRadius * 0.5
          color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.08)

          TextInput {
            id: rawOpacityInput
            anchors.fill: parent
            anchors.margins: Style.space(6)
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : ""
            font.pixelSize: Style.font.caption
            selectByMouse: true
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            text: RuleStore.selectedRule ? String(RuleStore.selectedRule.effects[effectSchema.key] || "") : ""

            Timer {
              id: rawTimer
              interval: 400
              repeat: false
              onTriggered: {
                if (!RuleStore.selectedRule) return
                var patch = {}
                patch[effectSchema.key] = rawOpacityInput.text.trim()
                RuleStore.updateRule(RuleStore.selectedRuleId, { effects: patch })
              }
            }

            onTextEdited: rawTimer.restart()
            onAccepted: { rawTimer.stop(); rawTimer.triggered() }
          }
        }
      }
    }
  }

  // Open file in editor
  Process {
    id: editFileProc
    command: ["bash", "-c", "${EDITOR:-xdg-open} ~/.config/hypr/windowrules.lua"]
    stdout: StdioCollector { waitForEnd: true }
  }
}
