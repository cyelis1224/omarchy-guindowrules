import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Fullscreen transparent overlay for the window-picking flow.
// Phase 1: Crosshair cursor over a dark scrim, click a window to select.
// Phase 2: Modal dialog to choose which match property to create the rule for.
//
// Uses the same PanelWindow + WlrLayershell pattern as the Display plugin's
// Arrange overlay.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: RuleStore.pickerActive

  property int phase: 1                   // 1 = picking, 2 = choose match prop
  property var hoveredClient: null         // Client under cursor
  property var selectedClient: null        // Client that was clicked

  // Which match properties the user has selected (checkboxes in phase 2)
  property var selectedMatchProps: ({})

  onOpenedChanged: {
    phase = 1
    hoveredClient = null
    selectedClient = null
    selectedMatchProps = ({})
    if (opened) {
      RuleStore.refreshClients()
      Qt.callLater(function() {
        if (overlayKeyCatcher) overlayKeyCatcher.forceActiveFocus()
      })
    }
  }

  function open(payloadJson) {
    RuleStore.refreshClients()
    phase = 1
    hoveredClient = null
    selectedClient = null
    selectedMatchProps = ({})
    RuleStore.pickerActive = true
    Qt.callLater(function() {
      if (overlayKeyCatcher) overlayKeyCatcher.forceActiveFocus()
    })
  }

  function close() {
    phase = 1
    hoveredClient = null
    selectedClient = null
    selectedMatchProps = ({})
    RuleStore.cancelPicker()
  }

  // Find which client the cursor is over using geometry from hyprctl
  function findClientAt(gx, gy) {
    var clients = RuleStore.clients
    var best = null
    var bestArea = Infinity

    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      var cx = c.at[0], cy = c.at[1]
      var cw = c.size[0], ch = c.size[1]

      if (gx >= cx && gx <= cx + cw && gy >= cy && gy <= cy + ch) {
        var area = cw * ch
        // Pick the smallest (most specific) window under the cursor
        if (area < bestArea) {
          bestArea = area
          best = c
        }
      }
    }
    return best
  }

  // Build the match props from the selected client based on checked boxes
  function buildMatchProps() {
    if (!selectedClient) return {}
    var props = {}
    if (selectedMatchProps["class"] && selectedClient.class)
      props.class = Model.anchoredRegex(selectedClient.class)
    if (selectedMatchProps["title"] && selectedClient.title)
      props.title = Model.anchoredRegex(selectedClient.title)
    if (selectedMatchProps["initial_class"] && selectedClient.initialClass)
      props.initial_class = Model.anchoredRegex(selectedClient.initialClass)
    if (selectedMatchProps["initial_title"] && selectedClient.initialTitle)
      props.initial_title = Model.anchoredRegex(selectedClient.initialTitle)
    return props
  }

  function hasAnyMatchSelected() {
    for (var k in selectedMatchProps) {
      if (selectedMatchProps[k]) return true
    }
    return false
  }

  // ========== Fullscreen overlay window ==========
  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-guindowrules-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // ========== Phase 1: Crosshair pick ==========
    Rectangle {
      id: pickLayer
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.35)
      visible: root.phase === 1

      Item {
        id: overlayKeyCatcher
        anchors.fill: parent
        focus: root.phase === 1

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
          }
        }
      }

      MouseArea {
        id: pickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor

        onPositionChanged: function(mouse) {
          var globalPos = mapToGlobal(mouse.x, mouse.y)
          root.hoveredClient = root.findClientAt(globalPos.x, globalPos.y)
          // Move tooltip
          tooltip.x = Math.min(pickArea.width - tooltip.width - 20, mouse.x + 24)
          tooltip.y = Math.min(pickArea.height - tooltip.height - 20, mouse.y + 24)
        }

        onClicked: function(mouse) {
          if (root.hoveredClient) {
            root.selectedClient = root.hoveredClient
            root.hoveredClient = null
            // Pre-select class by default
            root.selectedMatchProps = { "class": true }
            root.phase = 2
            Qt.callLater(function() { dialogKeyCatcher.forceActiveFocus() })
          }
        }
      }

      // Floating tooltip near cursor showing client info
      Rectangle {
        id: tooltip
        visible: root.hoveredClient !== null
        width: tooltipCol.implicitWidth + Style.space(24)
        height: tooltipCol.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.88)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)

        Column {
          id: tooltipCol
          anchors.centerIn: parent
          spacing: Style.space(4)

          Row {
            spacing: Style.space(6)
            Text {
              text: "class:"
              color: Qt.rgba(1, 1, 1, 0.5)
              font.pixelSize: Style.font.caption
            }
            Text {
              text: root.hoveredClient ? root.hoveredClient.class : ""
              color: "white"
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          Row {
            spacing: Style.space(6)
            Text {
              text: "title:"
              color: Qt.rgba(1, 1, 1, 0.5)
              font.pixelSize: Style.font.caption
            }
            Text {
              text: root.hoveredClient
                ? (root.hoveredClient.title.length > 50
                  ? root.hoveredClient.title.substring(0, 50) + "…"
                  : root.hoveredClient.title)
                : ""
              color: Qt.rgba(1, 1, 1, 0.7)
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            visible: root.hoveredClient !== null && root.hoveredClient !== undefined && root.hoveredClient.xwayland
            text: "⚠ XWayland"
            color: "#ffaa44"
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Instructions banner at top center
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Style.space(24)
        width: bannerRow.implicitWidth + Style.space(40)
        height: bannerRow.implicitHeight + Style.space(20)
        radius: Style.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.82)
        border.width: 1
        border.color: Color.accent

        Row {
          id: bannerRow
          anchors.centerIn: parent
          spacing: Style.space(12)

          Text {
            text: "󰓾"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "Click on a window to create a rule  ·  Esc to cancel"
            color: "white"
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    // ========== Phase 2: Property chooser dialog ==========
    Rectangle {
      id: dialogBackdrop
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)
      visible: root.phase === 2

      MouseArea {
        anchors.fill: parent
        onClicked: {} // Eat backdrop clicks
      }

      Item {
        id: dialogKeyCatcher
        anchors.fill: parent
        focus: root.phase === 2

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
          }
        }
      }

      // Centered dialog card
      Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.space(80), Style.space(480))
        height: dialogCol.implicitHeight + Style.space(48)
        radius: Style.cornerRadius * 1.5
        color: Qt.rgba(0.12, 0.12, 0.14, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        // Prevent click-through
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: dialogCol
          anchors.fill: parent
          anchors.margins: Style.space(24)
          spacing: Style.space(14)

          // Title
          Text {
            text: "Create Window Rule"
            color: "white"
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          // Selected window info card
          Rectangle {
            width: parent.width
            height: clientInfoCol.implicitHeight + Style.space(20)
            radius: Style.cornerRadius * 0.8
            color: Qt.rgba(1, 1, 1, 0.06)

            Column {
              id: clientInfoCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(14)
              spacing: Style.space(4)

              Text {
                text: root.selectedClient ? Model.clientLabel(root.selectedClient) : ""
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                width: parent.width
                elide: Text.ElideRight
              }

              Text {
                text: root.selectedClient ? root.selectedClient.title : ""
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                width: parent.width
                elide: Text.ElideRight
              }
            }
          }

          // Section header
          Text {
            text: "MATCH BY"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          // Match property checkboxes
          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: [
                { key: "class",         value: root.selectedClient ? root.selectedClient.class : "",        label: "Class" },
                { key: "title",         value: root.selectedClient ? root.selectedClient.title : "",        label: "Title" },
                { key: "initial_class", value: root.selectedClient ? root.selectedClient.initialClass : "", label: "Initial Class" },
                { key: "initial_title", value: root.selectedClient ? root.selectedClient.initialTitle : "", label: "Initial Title" }
              ]

              Rectangle {
                required property var modelData
                required property int index
                width: dialogCol.width
                height: propRow.implicitHeight + Style.space(16)
                radius: Style.cornerRadius * 0.6
                visible: modelData.value !== ""

                color: (root.selectedMatchProps[modelData.key] === true)
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
                  : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: (root.selectedMatchProps[modelData.key] === true)
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
                  : Qt.rgba(1, 1, 1, 0.08)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var next = JSON.parse(JSON.stringify(root.selectedMatchProps))
                    next[modelData.key] = !next[modelData.key]
                    root.selectedMatchProps = next
                  }
                }

                Row {
                  id: propRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(14)
                  spacing: Style.space(12)

                  // Checkbox
                  Rectangle {
                    width: Style.space(20)
                    height: Style.space(20)
                    radius: Style.space(4)
                    anchors.verticalCenter: parent.verticalCenter
                    color: (root.selectedMatchProps[modelData.key] === true) ? Color.accent : "transparent"
                    border.width: 2
                    border.color: (root.selectedMatchProps[modelData.key] === true)
                      ? Color.accent
                      : Qt.rgba(1, 1, 1, 0.3)

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                      anchors.centerIn: parent
                      text: "✓"
                      color: "white"
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      visible: root.selectedMatchProps[modelData.key] === true
                    }
                  }

                  Column {
                    width: parent.width - Style.space(32) - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                      text: modelData.label
                      color: "white"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }

                    Text {
                      width: parent.width
                      text: Model.anchoredRegex(modelData.value)
                      color: Qt.rgba(1, 1, 1, 0.45)
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }
          }

          // Action buttons
          Row {
            width: parent.width
            spacing: Style.space(10)
            layoutDirection: Qt.RightToLeft

            Button {
              text: "Create Rule"
              bordered: true
              selected: true
              foreground: "white"
              enabled: root.hasAnyMatchSelected()
              opacity: enabled ? 1 : 0.4
              onClicked: {
                var matchProps = root.buildMatchProps()
                RuleStore.finishPicker(root.selectedClient, matchProps)
              }
            }

            Button {
              text: "Cancel"
              bordered: true
              foreground: Qt.rgba(1, 1, 1, 0.7)
              onClicked: root.close()
            }
          }
        }
      }
    }
  }
}
