import QtQuick
import qs.Ui
import qs.Commons
import Quickshell.Services.Mpris

Panel {
  id: root
  moduleName: "bibek.media"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(hostWidget || root, direction);
    return false;
  }

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("bibek.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color secondaryText: Qt.darker(foreground, 1.3)
  readonly property color tertiaryText: Qt.darker(foreground, 1.6)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool cursorActive: false
  property string focusSection: "controls" // "controls" | "sources"
  property int selectedIndex: 2

  readonly property bool isMprisPlayer: activePlayer && typeof activePlayer.seek === "function" && !mediaService.isCliampMpris(activePlayer)
  readonly property bool isCliamp: activePlayer && mediaService && mediaService.isCliampMpris(activePlayer)

  readonly property real positionSeconds: {
    if (!activePlayer)
      return 0;
    if (isCliamp)
      return activePlayer.position || 0;
    return activePlayer.position || 0;
  }
  readonly property real lengthSeconds: {
    if (!activePlayer)
      return 0;
    if (isCliamp)
      return activePlayer.duration || 0;
    if (isMprisPlayer && activePlayer.lengthSupported)
      return activePlayer.length || 0;
    return 0;
  }
  readonly property bool canSeek: {
    if (!activePlayer)
      return false;
    if (isCliamp)
      return (activePlayer.duration || 0) > 0;
    return activePlayer.canSeek === true;
  }
  readonly property bool hasProgress: canSeek && lengthSeconds > 0

  property real sliderValue: positionSeconds
  property bool _dragging: false

  function formatTime(seconds) {
    if (!seconds || seconds <= 0)
      return "0:00";
    var s = Math.floor(seconds);
    var m = Math.floor(s / 60);
    s = s % 60;
    return m + ":" + (s < 10 ? "0" : "") + s;
  }

  Timer {
    id: posTimer
    interval: 500
    repeat: true
    running: root.activePlayer && root.activePlayer.isPlaying && root.hasProgress && !root._dragging
    onTriggered: {
      if (!root.activePlayer || root._dragging)
        return;
      if (root.isMprisPlayer)
        root.activePlayer.positionChanged();
      root.sliderValue = root.positionSeconds;
    }
  }

  readonly property bool sourcesVisible: sourcePlayers.length > 1
  readonly property bool shuffleActive: mediaService ? mediaService.playerShuffleActive(activePlayer) : false
  readonly property string repeatState: mediaService ? mediaService.playerRepeatState(activePlayer) : "off"

  function open() {
    cursorActive = true;
    focusSection = "controls";
    selectedIndex = initialButton();
    controller.show();
  }

  function close() {
    controller.hide();
  }

  function toggle() {
    if (opened)
      close();
    else
      open();
  }

  function sourceCount() {
    return sourcesVisible ? sourcePlayers.length : 0;
  }

  function buttonEnabled(index) {
    if (index === 0)
      return mediaService ? mediaService.playerShuffleSupported(activePlayer) : false;
    if (index === 1)
      return !!activePlayer && !!activePlayer.canGoPrevious;
    if (index === 2)
      return !!activePlayer && (activePlayer.canTogglePlaying || activePlayer.canPlay || activePlayer.canPause);
    if (index === 3)
      return !!activePlayer && !!activePlayer.canGoNext;
    if (index === 4)
      return mediaService ? mediaService.playerLoopSupported(activePlayer) : false;
    return false;
  }

  function enabledButtonIndices() {
    var list = [];
    for (var i = 0; i < 5; i++)
      if (buttonEnabled(i))
        list.push(i);
    return list;
  }

  function firstEnabledButton() {
    var inds = enabledButtonIndices();
    return inds.length > 0 ? inds[0] : 2;
  }

  function lastEnabledButton() {
    var inds = enabledButtonIndices();
    return inds.length > 0 ? inds[inds.length - 1] : 2;
  }

  function initialButton() {
    return buttonEnabled(2) ? 2 : firstEnabledButton();
  }

  function moveCursor(dx, dy) {
    if (!sourcesVisible && focusSection === "sources") {
      focusSection = "controls";
      selectedIndex = initialButton();
    }
    if (!cursorActive) {
      cursorActive = true;
      focusSection = "controls";
      selectedIndex = initialButton();
      return;
    }
    var dir = dx !== 0 ? dx : dy;
    if (dir === 0)
      return;
    if (focusSection === "controls") {
      var inds = enabledButtonIndices();
      if (inds.length === 0) {
        if (sourcesVisible) {
          focusSection = "sources";
          selectedIndex = dir > 0 ? 0 : sourceCount() - 1;
        }
        return;
      }
      var first = inds[0];
      var last = inds[inds.length - 1];
      if (dir > 0) {
        if (selectedIndex >= last) {
          if (sourcesVisible) {
            focusSection = "sources";
            selectedIndex = 0;
          } else
            selectedIndex = first;
        } else {
          for (var i = 0; i < inds.length; i++)
            if (inds[i] > selectedIndex) {
              selectedIndex = inds[i];
              break;
            }
        }
      } else {
        if (selectedIndex <= first) {
          if (sourcesVisible) {
            focusSection = "sources";
            selectedIndex = sourceCount() - 1;
          } else
            selectedIndex = last;
        } else {
          for (var k = inds.length - 1; k >= 0; k--)
            if (inds[k] < selectedIndex) {
              selectedIndex = inds[k];
              break;
            }
        }
      }
    } else {
      var n = sourceCount();
      if (n <= 0)
        return;
      if (dir > 0) {
        if (selectedIndex < n - 1)
          selectedIndex += 1;
        else {
          focusSection = "controls";
          selectedIndex = firstEnabledButton();
        }
      } else {
        if (selectedIndex > 0)
          selectedIndex -= 1;
        else {
          focusSection = "controls";
          selectedIndex = lastEnabledButton();
        }
      }
    }
  }

  function activateCursor() {
    if (!cursorActive || !mediaService)
      return;
    if (focusSection === "controls") {
      if (!buttonEnabled(selectedIndex))
        return;
      var key = mediaService.playerKey(activePlayer);
      if (selectedIndex === 0)
        mediaService.toggleShuffle(key);
      else if (selectedIndex === 1)
        mediaService.runAction("previous", false, key);
      else if (selectedIndex === 2)
        mediaService.runAction("playPause", false, key);
      else if (selectedIndex === 3)
        mediaService.runAction("next", false, key);
      else if (selectedIndex === 4)
        mediaService.cycleRepeat(key);
    } else if (focusSection === "sources") {
      var player = sourcePlayers[selectedIndex];
      if (player)
        mediaService.selectPlayer(mediaService.playerKey(player));
      focusSection = "controls";
      selectedIndex = initialButton();
    }
  }

  function runAction(action) {
    if (mediaService)
      mediaService.runAction(action, false, mediaService.playerKey(activePlayer));
  }

  function toggleShuffle() {
    if (mediaService)
      mediaService.toggleShuffle(mediaService.playerKey(activePlayer));
  }

  function cycleRepeat() {
    if (mediaService)
      mediaService.cycleRepeat(mediaService.playerKey(activePlayer));
  }

  function controlHovered(index, hovered) {
    if (!hovered || !buttonEnabled(index))
      return;
    cursorActive = true;
    focusSection = "controls";
    selectedIndex = index;
  }

  function sourceHovered(index, hovered) {
    if (!hovered)
      return;
    cursorActive = true;
    focusSection = "sources";
    selectedIndex = index;
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: Style.space(320)
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function (dx, dy) {
        root.moveCursor(dx, dy);
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction);
      }
      onTextKey: function (t) {
        if (t === "q")
          root.close();
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Row {
          spacing: Style.space(10)
          width: parent.width

          BorderSurface {
            width: Style.space(64)
            height: Style.space(64)
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.foreground, root.accent)
            borderSpec: Border.controlSpec("normal", root.foreground, root.accent)

            Image {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
              visible: source !== ""
            }

            Text {
              anchors.centerIn: parent
              visible: !root.activePlayer || !root.activePlayer.trackArtUrl
              text: "󰝚"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
            }
          }

          Column {
            spacing: Style.space(4)
            width: parent.width - Style.space(74)

            Text {
              text: root.title || "Nothing playing"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.artist
              color: root.secondaryText
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Text {
              text: root.album
              color: root.tertiaryText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }
          }
        }

        Row {
          visible: root.hasProgress
          width: parent.width
          spacing: Style.space(6)
          anchors.horizontalCenter: parent.horizontalCenter

          Text {
            text: root.formatTime(root.sliderValue)
            color: root.secondaryText
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            width: Style.space(32)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
          }

          PanelSlider {
            id: seekSlider
            bar: root.bar
            width: parent.width - Style.space(72)
            value: root.sliderValue
            minimum: 0
            maximum: root.lengthSeconds > 0 ? root.lengthSeconds : 1
            trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
            knobSize: Math.max(12, Math.round(Style.spacing.controlHeight * 0.32))
            fillColor: root.accent
            trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
            knobColor: root.foreground
            anchors.verticalCenter: parent.verticalCenter

            onMoved: function (val) {
              root._dragging = true;
              root.sliderValue = val;
            }
            onReleased: function (val) {
              root.sliderValue = val;
              if (!root.activePlayer) {
                root._dragging = false;
                return;
              }
              if (root.isMprisPlayer) {
                var delta = val - root.activePlayer.position;
                if (Math.abs(delta) > 0.1)
                  root.activePlayer.seek(delta);
              } else if (root.isCliamp) {
                Quickshell.execDetached(["cliamp", "seek", String(Math.floor(val))]);
              }
              Qt.callLater(function () {
                  root._dragging = false;
                });
            }
          }

          Text {
            text: root.formatTime(root.lengthSeconds)
            color: root.secondaryText
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            width: Style.space(32)
            horizontalAlignment: Text.AlignLeft
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Button {
            iconText: "󰒟"
            foreground: root.shuffleActive ? root.accent : root.foreground
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            iconSize: Style.font.iconLarge
            enabled: mediaService ? mediaService.playerShuffleSupported(root.activePlayer) : false
            visible: enabled
            hasCursor: root.cursorActive && root.focusSection === "controls" && root.selectedIndex === 0
            onHovered: function (hovered) {
              root.controlHovered(0, hovered);
            }
            onClicked: root.toggleShuffle()
          }

          Button {
            iconText: ""
            foreground: root.foreground
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            iconSize: Style.font.iconLarge
            enabled: root.activePlayer && root.activePlayer.canGoPrevious
            visible: enabled
            hasCursor: root.cursorActive && root.focusSection === "controls" && root.selectedIndex === 1
            onHovered: function (hovered) {
              root.controlHovered(1, hovered);
            }
            onClicked: root.runAction("previous")
          }

          Button {
            iconText: root.playIcon
            foreground: root.foreground
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            iconSize: Style.font.iconLarge
            enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
            visible: enabled
            hasCursor: root.cursorActive && root.focusSection === "controls" && root.selectedIndex === 2
            onHovered: function (hovered) {
              root.controlHovered(2, hovered);
            }
            onClicked: root.runAction("playPause")
          }

          Button {
            iconText: ""
            foreground: root.foreground
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            iconSize: Style.font.iconLarge
            enabled: root.activePlayer && root.activePlayer.canGoNext
            visible: enabled
            hasCursor: root.cursorActive && root.focusSection === "controls" && root.selectedIndex === 3
            onHovered: function (hovered) {
              root.controlHovered(3, hovered);
            }
            onClicked: root.runAction("next")
          }

          Button {
            iconText: root.repeatState === "one" ? "󰑘" : "󰕇"
            foreground: root.repeatState !== "off" ? root.accent : root.foreground
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            iconSize: Style.font.iconLarge
            enabled: mediaService ? mediaService.playerLoopSupported(root.activePlayer) : false
            visible: enabled
            hasCursor: root.cursorActive && root.focusSection === "controls" && root.selectedIndex === 4
            onHovered: function (hovered) {
              root.controlHovered(4, hovered);
            }
            onClicked: root.cycleRepeat()
          }
        }

        PanelSeparator {
          visible: root.sourcesVisible
          foreground: root.foreground
        }

        Column {
          id: sourceList
          visible: root.sourcesVisible
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.sourcePlayers

            BorderSurface {
              id: sourceRow
              required property var modelData
              required property int index

              readonly property var player: modelData
              readonly property bool selected: root.activePlayer && player && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
              readonly property bool hasCursor: root.cursorActive && root.focusSection === "sources" && index === root.selectedIndex
              readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
              readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

              width: sourceList.width
              height: sourceInner.implicitHeight + Style.space(10)
              radius: Style.spacing.labelGap
              color: hasCursor ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
              borderSpec: hasCursor ? Border.controlSpec("hover-cursor", root.foreground, root.accent) : Border.none()

              Row {
                id: sourceInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
                anchors.rightMargin: sourceRow.borderRight + Style.space(8)
                spacing: Style.space(8)

                Text {
                  text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                  color: sourceRow.selected ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  width: Style.space(18)
                  horizontalAlignment: Text.AlignHCenter
                  anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                  width: parent.width - Style.space(26)
                  spacing: Style.space(1)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: sourceRow.sourceTitle
                    color: sourceRow.selected ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: sourceRow.selected
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: sourceRow.sourceDetail
                    color: root.secondaryText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== ""
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sourceHovered(sourceRow.index, true)
                onClicked: {
                  if (root.mediaService)
                    root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player));
                  root.focusSection = "controls";
                  root.selectedIndex = root.initialButton();
                }
              }
            }
          }
        }
      }
    }
  }
}
