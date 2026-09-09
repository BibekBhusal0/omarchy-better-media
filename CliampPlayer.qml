import QtQuick
import Quickshell
import Quickshell.Io

// Synthetic player for the cliamp daemon (https://github.com/bjarneo/cliamp).
// Headless mode ("cliamp --daemon") exposes no MPRIS bridge, so this polls the
// IPC socket via `cliamp status --json` and routes playback actions through the
// `cliamp` CLI, letting the media widget treat cliamp like any other source.
Item {
  id: root

  property bool available: false
  property bool isPlaying: false
  property string state: "stopped"
  property string trackTitle: ""
  property string trackArtist: ""
  property string trackAlbum: ""
  property string trackArtUrl: ""
  property string playlist: ""
  property real position: 0
  property real duration: 0
  property real volume: 0
  property bool shuffle: false
  property string repeat: "off" // "off" | "all" | "one"

  // Polled even while a cliamp MPRIS player is present: its MPRIS bridge
  // exposes no Shuffle/LoopStatus, so this feed supplies those toggle states.
  property bool pollEnabled: true

  readonly property string identity: "cliamp"
  readonly property string desktopEntry: "cliamp"
  readonly property string dbusName: "cliamp"

  readonly property bool hasMedia: trackTitle !== "" || trackArtist !== ""
  readonly property bool canPlay: available
  readonly property bool canPause: available
  readonly property bool canTogglePlaying: available
  readonly property bool canGoNext: available
  readonly property bool canGoPrevious: available
  readonly property bool shuffleSupported: available
  readonly property bool loopSupported: available

  function run(cmd) {
    Quickshell.execDetached(["cliamp", cmd]);
  }

  function play() {
    run("play");
  }
  function pause() {
    run("pause");
  }
  function togglePlaying() {
    run("toggle");
  }
  function next() {
    run("next");
  }
  function previous() {
    run("prev");
  }
  function setShuffle(on) {
    Quickshell.execDetached(["cliamp", "shuffle", on ? "on" : "off"]);
  }
  function setRepeat(mode) {
    Quickshell.execDetached(["cliamp", "repeat", mode]);
  }

  function poll() {
    statusProc.running = false;
    statusProc.collected = "";
    statusProc.command = ["cliamp", "status", "--json"];
    statusProc.running = true;
  }

  function parseStatus(raw) {
    var text = String(raw || "").trim();
    var data = {};
    if (text !== "") {
      try {
        data = JSON.parse(text);
      } catch (error) {
        console.warn("Cliamp: ignoring invalid status:", error);
      }
    }
    if (data.ok !== true) {
      clear();
      return;
    }
    available = true;
    var newState = String(data.state || "stopped");
    var track = data.track || {};
    state = newState;
    isPlaying = newState === "playing";
    trackTitle = String(track.title || "");
    trackArtist = String(track.artist || "");
    trackAlbum = String(track.album || "");
    trackArtUrl = String(track.artUrl || "");
    playlist = String(data.playlist || "");
    position = Number(data.position) || 0;
    duration = Number(data.duration) || 0;
    volume = Number(data.volume) || 0;
    shuffle = data.shuffle === true;
    var repeatRaw = String(data.repeat || "").toLowerCase();
    if (repeatRaw.indexOf("one") !== -1)
      repeat = "one";
    else if (repeatRaw.indexOf("all") !== -1)
      repeat = "all";
    else
      repeat = "off";
  }

  function clear() {
    available = false;
    isPlaying = false;
    trackTitle = "";
    trackArtist = "";
    trackAlbum = "";
    trackArtUrl = "";
    playlist = "";
    position = 0;
    duration = 0;
    volume = 0;
    shuffle = false;
    repeat = "off";
  }

  Timer {
    id: pollTimer
    interval: 2000
    repeat: true
    running: root.pollEnabled
    onTriggered: root.poll()
  }

  Process {
    id: statusProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function (data) {
        statusProc.collected += data + "\n";
      }
    }
    onExited: function (exitCode) {
      if (exitCode === 0 && String(statusProc.collected).trim() !== "")
        root.parseStatus(statusProc.collected);
      else
        root.clear();
    }
  }

  Component.onCompleted: root.poll()
}
