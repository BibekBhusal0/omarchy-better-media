import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "bibek.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("bibek.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: row.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    var target = panelLoader.item;
    if (!target)
      return;
    if ("bar" in target)
      target.bar = root.bar;
    if ("settings" in target)
      target.settings = root.settings;
    if ("anchorItem" in target)
      target.anchorItem = root;
    if ("hostWidget" in target)
      target.hostWidget = root;
  }

  function open() {
    if (panelLoader.item)
      panelLoader.item.open();
  }

  function close() {
    if (panelLoader.item)
      panelLoader.item.close();
  }

  function toggle() {
    if (panelLoader.item)
      panelLoader.item.toggle();
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item)
      panelLoader.item.closeForPopoutSwitch();
  }

  property real maxLabelWidth: 180

  visible: hasMedia
  implicitWidth: hasMedia ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: root.playIcon
      color: activePlayer && activePlayer.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color  {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation {
          duration: 160
        }
      }
    }

    Item {
      id: labelClip
      width: root.title !== "" ? root.maxLabelWidth : 0
      height: glyph.height
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.title !== ""

      Text {
        id: labelText
        text: root.title
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function (mouse) {
      if (!root.activePlayer)
        return;
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService)
          root.mediaService.runAction("next", false);
      } else if (mouse.button === Qt.RightButton) {
        root.toggle();
      } else {
        if (root.mediaService)
          root.mediaService.runAction("playPause", false);
      }
    }
    onWheel: function (wheel) {
      if (!root.activePlayer)
        return;
      if (wheel.angleDelta.y > 0 && root.mediaService)
        root.mediaService.runAction("previous", false);
      else if (wheel.angleDelta.y < 0 && root.mediaService)
        root.mediaService.runAction("next", false);
    }
    onEntered: if (root.bar)
      root.bar.showTooltip(root, root.hasMedia ? root.title : "")
    onExited: if (root.bar)
      root.bar.hideTooltip(root)
  }

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  Component.onCompleted: Qt.callLater(injectPanel)

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: Qt.callLater(root.injectPanel)
  }
}
