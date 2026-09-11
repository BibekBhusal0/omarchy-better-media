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

  property string cliampBin: ""

  function run(cmd) {
    if (root.cliampBin === "")
      return;
    Quickshell.execDetached([root.cliampBin, cmd]);
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
    if (root.cliampBin === "")
      return;
    Quickshell.execDetached([root.cliampBin, "shuffle", on ? "on" : "off"]);
  }
  function setRepeat(mode) {
    if (root.cliampBin === "")
      return;
    Quickshell.execDetached([root.cliampBin, "repeat", mode]);
  }
  function seekTo(seconds) {
    if (root.cliampBin === "")
      return false;
    Quickshell.execDetached([root.cliampBin, "seek", String(Math.floor(Number(seconds) || 0))]);
    return true;
  }

  function acceptCliampBin(raw) {
    var line = String(raw || "").split("\n")[0].trim();
    if (line === "" || line.charAt(0) !== "/" || line.length > 1024)
      return "";
    if (/[\u0000-\u001F\u007F]/.test(line))
      return "";
    return line;
  }

  function resolveCliamp() {
    if (resolveProc.running)
      return;
    resolveProc.collected = "";
    resolveProc.collectedBytes = 0;
    resolveProc.overflowed = false;
    resolveProc.timedOut = false;
    resolveProc.command = ["/usr/bin/sh", "-c", "p=$(command -v cliamp 2>/dev/null); [ -n \"$p\" ] && [ -x \"$p\" ] && printf '%s' \"$p\""];
    resolveProc.running = true;
    resolveWatchdog.restart();
  }

  function killResolveProc() {
    try {
      resolveProc.signal(9);
    } catch (e) {
    }
    resolveProc.running = false;
  }

  property int maxOutputBytes: 32768
  property int maxFieldChars: 512
  property int pollTimeoutMs: 1500
  property int maxResolveBytes: 4096
  property int resolveTimeoutMs: 3000

  function killStatusProc() {
    try {
      statusProc.signal(9);
    } catch (e) {
    }
    statusProc.running = false;
  }

  function boundedField(value) {
    if (value === undefined || value === null)
      return "";
    var s = String(value);
    if (s.length > root.maxFieldChars)
      return null;
    return s;
  }

  function poll() {
    if (root.cliampBin === "") {
      root.clear();
      root.resolveCliamp();
      return;
    }
    if (statusProc.running)
      return;
    statusProc.collected = "";
    statusProc.collectedBytes = 0;
    statusProc.overflowed = false;
    statusProc.timedOut = false;
    statusProc.command = [root.cliampBin, "status", "--json"];
    statusProc.running = true;
    pollWatchdog.restart();
  }

  function parseStatus(raw) {
    if (String(raw || "").length > root.maxOutputBytes) {
      clear();
      return;
    }
    var text = String(raw || "").trim();
    var data = {};
    if (text !== "") {
      try {
        data = JSON.parse(text);
      } catch (error) {
        console.warn("Cliamp: ignoring invalid status:", error);
      }
    }
    if (!data || typeof data !== "object" || Array.isArray(data) || data.ok !== true) {
      clear();
      return;
    }
    if (Object.keys(data).length > 64) {
      clear();
      return;
    }
    var newState = boundedField(data.state);
    var track = data.track;
    if (track === undefined || track === null)
      track = {};
    if (typeof track !== "object" || Array.isArray(track)) {
      clear();
      return;
    }
    if (Object.keys(track).length > 32) {
      clear();
      return;
    }
    var title = boundedField(track.title);
    var artist = boundedField(track.artist);
    var album = boundedField(track.album);
    var artUrl = boundedField(track.artUrl);
    var playlistName = boundedField(data.playlist);
    var repeatRaw = boundedField(data.repeat);
    if (newState === null || title === null || artist === null || album === null || artUrl === null || playlistName === null || repeatRaw === null) {
      clear();
      return;
    }
    if (newState === "")
      newState = "stopped";
    available = true;
    var pos = Number(data.position);
    var dur = Number(data.duration);
    var vol = Number(data.volume);
    if (!isFinite(pos))
      pos = 0;
    if (!isFinite(dur))
      dur = 0;
    if (!isFinite(vol))
      vol = 0;
    state = newState;
    isPlaying = newState === "playing";
    trackTitle = title;
    trackArtist = artist;
    trackAlbum = album;
    trackArtUrl = artUrl;
    root.playlist = playlistName;
    root.position = Math.max(0, Math.min(86400, pos));
    root.duration = Math.max(0, Math.min(86400, dur));
    root.volume = Math.max(0, Math.min(100, vol));
    shuffle = data.shuffle === true;
    var repeatLower = repeatRaw.toLowerCase();
    if (repeatLower.indexOf("one") !== -1)
      repeat = "one";
    else if (repeatLower.indexOf("all") !== -1)
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

  Timer {
    id: pollWatchdog
    interval: root.pollTimeoutMs
    repeat: false
    onTriggered: {
      if (statusProc.running) {
        statusProc.timedOut = true;
        statusProc.collected = "";
        statusProc.collectedBytes = 0;
        root.killStatusProc();
        root.clear();
      }
    }
  }

  Process {
    id: statusProc
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (statusProc.overflowed || statusProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (statusProc.collectedBytes + chunk.length > root.maxOutputBytes) {
          statusProc.overflowed = true;
          statusProc.collected = "";
          statusProc.collectedBytes = 0;
          root.killStatusProc();
          return;
        }
        statusProc.collected += chunk;
        statusProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (statusProc.overflowed || statusProc.timedOut)
          return;
        statusProc.collectedBytes += String(data + "\n").length;
        if (statusProc.collectedBytes > root.maxOutputBytes) {
          statusProc.overflowed = true;
          statusProc.collected = "";
          statusProc.collectedBytes = 0;
          root.killStatusProc();
        }
      }
    }
    onExited: function (exitCode) {
      pollWatchdog.stop();
      var failed = statusProc.overflowed || statusProc.timedOut;
      var output = String(statusProc.collected);
      statusProc.collected = "";
      statusProc.collectedBytes = 0;
      statusProc.overflowed = false;
      statusProc.timedOut = false;
      if (failed)
        root.clear();
      else if (exitCode === 0 && output.trim() !== "")
        root.parseStatus(output);
      else
        root.clear();
    }
  }

  Timer {
    id: resolveWatchdog
    interval: root.resolveTimeoutMs
    repeat: false
    onTriggered: {
      if (resolveProc.running) {
        resolveProc.timedOut = true;
        resolveProc.collected = "";
        resolveProc.collectedBytes = 0;
        root.killResolveProc();
      }
    }
  }

  Process {
    id: resolveProc
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (resolveProc.overflowed || resolveProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (resolveProc.collectedBytes + chunk.length > root.maxResolveBytes) {
          resolveProc.overflowed = true;
          resolveProc.collected = "";
          resolveProc.collectedBytes = 0;
          root.killResolveProc();
          return;
        }
        resolveProc.collected += chunk;
        resolveProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (resolveProc.overflowed || resolveProc.timedOut)
          return;
        resolveProc.collectedBytes += String(data + "\n").length;
        if (resolveProc.collectedBytes > root.maxResolveBytes) {
          resolveProc.overflowed = true;
          resolveProc.collected = "";
          resolveProc.collectedBytes = 0;
          root.killResolveProc();
        }
      }
    }
    onExited: function (exitCode) {
      resolveWatchdog.stop();
      var failed = resolveProc.overflowed || resolveProc.timedOut;
      var output = String(resolveProc.collected);
      resolveProc.collected = "";
      resolveProc.collectedBytes = 0;
      resolveProc.overflowed = false;
      resolveProc.timedOut = false;
      if (!failed && exitCode === 0)
        root.cliampBin = root.acceptCliampBin(output);
      if (root.cliampBin !== "")
        root.poll();
      else
        root.clear();
    }
  }

  Component.onCompleted: root.resolveCliamp()
}
