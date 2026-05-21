# MusaLCE Suite Architecture

This document is the canonical reference for the **suite workflow** of MusaLCE — running [musalce-server](https://github.com/javier-sy/musalce-server) together with the per-DAW extension to drive Bitwig Studio or Ableton Live from a code editor in real time, optionally with Stream Deck integration via the MusaLCE Surface relay in **Pulso** — [yeste.studio](https://yeste.studio)'s upcoming Stream Deck control system for music DAWs (Bitwig today; Ableton planned). MusaLCE Surface support is one feature of Pulso among many DAW-control features. Public release pending.

It is a companion to (not a replacement for) the lower-level [musa-dsl REPL subsystem doc](https://github.com/javier-sy/musa-dsl/blob/master/docs/subsystems/repl.md), which covers the **standalone REPL** workflow (case 1). The suite documented here is **internally a specialization** of that case — `musalce-server` opens `Musa::REPL::REPL.new(binding)` after pre-building the sequencer, clock, transport, DAW handler and surface, so you don't have to.

## When to use this (vs the standalone REPL)

| Use this (suite) | Use the standalone REPL |
|---|---|
| Target is Bitwig Studio or Ableton Live | Target is SuperCollider, Max/MSP, OSC apps, custom hardware |
| You want `daw.*`, `surface[:event]` and DAW transport out of the box | You want full control over the wiring |
| You want a Stream Deck wired into your score via Pulso's MusaLCE Surface integration (Bitwig only today) | You're prototyping a personal live-coding DSL |
| Worked example: `_demo-13b-live-coding-suite` (planned) | Worked example: [`_demo-13-live-coding`](https://github.com/javier-sy/musadsl-demo) |

Both workflows use the same [MusaLCEClientForVSCode](https://github.com/javier-sy/MusaLCEClientForVSCode) extension; the extension does not know or care which server is on the other end of TCP/1327.

## The big picture

```
                                                       ┌────────────────────────────┐
                                                       │     Stream Deck plugin     │
                                                       │ (Pulso Workflow .sdPlugin) │
                                                       └─────────────┬──────────────┘
                                                                     │ OSC over UDP (Pulso wire)
                                                                     ▼
┌────────────────────┐  TCP 1327     ┌──────────────────┐         ┌─────────────────────────┐         ┌──────────────────┐
│  VSCode +          │ ◀──────────▶  │   musalce-server │  ─────▶ │ MusaLCEforBitwig        │ ◀────▶ │  Bitwig Studio   │
│  MusaLCEClient     │   (REPL)      │   (Ruby gem)     │         │  + Pulso Bridge relay   │         └──────────────────┘
│  ForVSCode         │               │                  │  UDP    └─────────────────────────┘
└────────────────────┘               │  • REPL          │  OSC                  OR
                                     │  • Sequencer     │
                                     │  • DAW handler   │  ─────▶ ┌─────────────────────────┐         ┌──────────────────┐
                                     │  • Surface       │         │ MusaLCEforLive          │ ◀────▶ │  Ableton Live    │
                                     │  • MIDI out      │         │  (Python)               │         └──────────────────┘
                                     └──────────────────┘         └─────────────────────────┘
```

Two parallel OSC contracts cross the server ↔ extension boundary:

- **Handler protocol** — `/musalce4bitwig/*` or `/musalce4live/*` plus a common `/hello`, `/version`, `/reload`. Carries DAW control (transport, track sync, channels). Documented [below](#osc-handler-protocol).
- **Surface protocol** — `/musalce/surface/*`. Carries Stream Deck control state (inventory, triggers, state propagation). Documented in `MusaLCEforBitwig/src/main/java/.../MusaLCESurfaceRelay.java` (javadoc) and summarised below. The canonical Pulso-side spec will be linked here once Pulso publishes. Bitwig only today; Live side not implemented.

## Component responsibilities

| Component | Repo | Role | Language |
|---|---|---|---|
| **musa-dsl** | [musa-dsl](https://github.com/javier-sy/musa-dsl) | The composition framework: series, sequencer, neumas, transport, REPL primitive. | Ruby |
| **musalce-server** | [musalce-server](https://github.com/javier-sy/musalce-server) | Packages the REPL + sequencer + per-DAW handler + surface into a single command (`musalce-server bitwig\|live`). | Ruby |
| **MusaLCEforBitwig** | [MusaLCEforBitwig](https://github.com/javier-sy/MusaLCEforBitwig) | Bitwig controller extension; bridges Bitwig and musalce-server over OSC, includes the `MusaLCESurfaceRelay` for Pulso. | Java (Bitwig Extension API 18) |
| **MusaLCEforLive** | [MusaLCEforLive](https://github.com/javier-sy/MusaLCEforLive) | Ableton Live MIDI Remote Script; bridges Live and musalce-server over OSC. Inherits `/live/*` from AbletonOSC. | Python |
| **MusaLCEClientForVSCode** | [MusaLCEClientForVSCode](https://github.com/javier-sy/MusaLCEClientForVSCode) | VSCode extension that is a REPL client over TCP/1327. | TypeScript |
| **Pulso Bridge** *(optional)* | *private repo (public release pending)* | The DAW-side component of [yeste.studio](https://yeste.studio)'s upcoming Pulso, a Stream Deck control system for music DAWs (Bitwig today; Ableton planned). Pulso's primary scope is generic DAW control (transport, tracks, devices, browser, parameter encoders); *optionally*, Pulso Bridge can also relay the MusaLCE Surface protocol to/from MusaLCEforBitwig — that's the integration described in this doc. | Java |

## REPL DSL surface (`daw.*`)

The DSL context exposed in the REPL of the suite workflow extends what's available in the standalone REPL with a `daw` accessor. Quick reference (full reference: [musalce-server README → REPL Commands Reference](https://github.com/javier-sy/musalce-server#readme)):

| Accessor | Returns | What it's for |
|---|---|---|
| `daw` | `Daw` (Bitwig or Live subclass) | Root entry point |
| `daw.sequencer` | `Musa::Sequencer::Sequencer` | The sequencer, also the implicit DSL host |
| `daw.clock` | `Musa::Clock::InputMidiClock` | The MIDI clock |
| `daw.transport` | `Musa::Transport::Transport` | The transport. Exposes `on_start`/`after_stop`/`before_begin` for callbacks that survive Stop/Play (since v0.7.2). |
| `daw.tracks` | DAW-specific | Track collection (`daw.track('Name')`) |
| `daw.surface` | `Surface` | Stream Deck / hardware surface object — `surface[:event]` (see below) |
| `daw.play`, `daw.stop`, `daw.continue`, `daw.goto(bar)`, `daw.record` | — | Transport remote control. **Bitwig only** (Live API limitation). |
| `daw.panic!` | — | All-notes-off to every track |

## `surface[:event]` DSL — Stream Deck integration

A *Surface* control is named by an **event Symbol** that doubles as the identifier the sequencer uses when dispatching from a physical control. The surface is registered by an external bridge — Pulso when published — via the inventory protocol; the server **owns the state** (message, enabled, value, range) and propagates changes outbound.

There are three control types: **Toggle**, **Trigger** and **Encoder**.

### Trigger — momentary

```ruby
# In score code:
surface[:launch_chorus].set(message: "Chorus")

on :launch_chorus do |payload|
  puts "Stream Deck button fired (#{payload.inspect})"
  # ... schedule the chorus section ...
end
```

A Trigger has no persistent state beyond an optional `message`. Pressing the Stream Deck button reaches the `on :launch_chorus do |payload| … end` handler through the sequencer's event dispatch.

### Toggle — three-state (Action / Ready / Idle)

```ruby
surface[:mode].set(message: "Verse", enabled: true)

on :mode do |payload|
  if surface[:mode].enabled
    surface[:mode].enabled = false
    # ... toggle off behaviour ...
  else
    surface[:mode].enabled = true
    # ... toggle on behaviour ...
  end
end
```

`enabled` accepts `true` / `false` / `:inactive` — Pulso paints the three states with distinct palettes (Action / Ready / Idle).

### Encoder — integer with range

```ruby
surface[:tempo].set(value: 120, range: [60, 200], message: "BPM")

on :tempo do |payload|
  new_value = payload[:value].to_i
  surface[:tempo].value = new_value
  # ... apply tempo change ...
end
```

The encoder owns its `value` (an integer) and its `range` (min, max integers). State propagates back to the Stream Deck plugin so the key/dial repaints.

## Stop/Play semantics

The server registers exactly one built-in callback on the transport:

```ruby
transport.after_stop { sequencer.reset }
```

`sequencer.reset` (`musa-dsl/sequencer/base-sequencer.rb`) wipes:

- `@timeslots` — all `at`-scheduled events
- `@everying` — all `every` loops
- `@playing` — all `play` operations
- `@moving` — all `move` operations
- `@event_handlers` — **all `on :event` handlers**

What survives a Stop/Play cycle:

| | Survives Stop? |
|---|---|
| Top-level Ruby (`def`, constants, modules) | ✅ (Ruby process is alive) |
| `daw.*` (sequencer, transport, tracks, surface) | ✅ (instance state of `Daw`) |
| `surface[:event]` **control declarations** | ✅ (live on `@surface`) |
| `surface[:event]` **handler blocks** (`on :event do … end`) | ❌ (wiped with `@event_handlers`) |
| `at`, `every`, `play`, `move` | ❌ |

**Asymmetry warning**: the Stream Deck button keeps painting after a Stop, but pressing it dispatches to a handler that is no longer registered — silence.

### Rehydration pattern

Use `daw.transport.on_start` (exposed since v0.7.2 — see [musalce-server commit `fb8480f`](https://github.com/javier-sy/musalce-server/commit/fb8480f)) to re-install handlers and schedules on every Play:

```ruby
daw.transport.on_start do
  load 'persistent_actions.rb'   # re-establishes on :event, every, at, …
end
```

`on_start` callbacks accumulate (append-only list), so you can register more from the REPL at any time. Use `before_begin` for callbacks that should run **only on the first Start of the session**, and `after_stop` for cleanup (e.g. `voices.panic`).

## OSC handler protocol

Two unidirectional channels, both UDP:

- **server listens** on `127.0.0.1:11011` (extension → server)
- **server sends** to `127.0.0.1:10001` (server → extension)

Both ports are **hardcoded** on the server side (`musalce-server/lib/daw.rb`). The DAW extensions match these defaults.

### Common addresses (both DAWs)

| Direction | Address | Args | Purpose |
|---|---|---|---|
| ext → server | `/hello` | — | Extension announces itself on init. Server replies with `/version` + a per-DAW sync request. |
| server → ext | `/version` | `s` (VERSION) | Server announces its gem version. Extension can refuse to talk to incompatible versions. |
| server → ext | `/reload` | — | Asks the extension to reset and re-sync (used by `reload` REPL command). |

### Bitwig-specific (`/musalce4bitwig/*`)

| Direction | Address | Args | Purpose |
|---|---|---|---|
| server → ext | `/musalce4bitwig/sync` | — | Ask the extension to re-emit controllers + channels. |
| server → ext | `/musalce4bitwig/play` | — | Bitwig transport play. |
| server → ext | `/musalce4bitwig/stop` | — | Bitwig transport stop. |
| server → ext | `/musalce4bitwig/continue` | — | Bitwig transport continue. |
| server → ext | `/musalce4bitwig/goto` | `d` (position in beats from bar 1) | Move playhead. |
| server → ext | `/musalce4bitwig/record` | — | Toggle record. |
| ext → server | `/musalce4bitwig/controllers` | `s s s …` (names) | Register all controllers in Bitwig. |
| ext → server | `/musalce4bitwig/controller` | `s s i` (name, port_name, is_clock 0/1) | Register a single controller. |
| ext → server | `/musalce4bitwig/controller/update` | `s s s i` (old_name, new_name, port_name, is_clock) | Rename / update a controller. |
| ext → server | `/musalce4bitwig/channels` | `s i i …` (controller_name, channels…) | Register channels for a controller. |

### Live-specific (`/musalce4live/*`)

| Direction | Address | Args | Purpose |
|---|---|---|---|
| server → ext | `/musalce4live/tracks` | — | Ask the script to re-emit the track registry. |
| ext → server | `/musalce4live/tracks` | bulk (sliced 10) | Bulk track registry dump. |
| ext → server | `/musalce4live/track/name` | bulk (sliced 2) | Track names. |
| ext → server | `/musalce4live/track/midi` | bulk (sliced 3) | MIDI track metadata. |
| ext → server | `/musalce4live/track/audio` | bulk (sliced 3) | Audio track metadata. |
| ext → server | `/musalce4live/track/routings` | bulk (sliced 5) | Routing metadata. |

### `/live/*` — inherited from AbletonOSC (Live only)

MusaLCEforLive inherits the full `/live/*` surface from [ideoforms/AbletonOSC](https://github.com/ideoforms/AbletonOSC) — dozens of endpoints covering volume, pan, send, clip control, devices, etc. These are not MusaLCE-specific and are not documented here; see the upstream README for the full address list.

## MusaLCE Surface protocol — Stream Deck via Pulso's MusaLCE integration (Bitwig only)

The MusaLCE Surface protocol carries surface inventory, triggers and state between `musalce-server`, MusaLCEforBitwig (`MusaLCESurfaceRelay`) and Pulso Bridge. It is one of several OSC surfaces that Pulso Bridge speaks (the rest are Pulso's own DAW-control surfaces, unrelated to MusaLCE). It is implemented in this codebase (server side) and in [`MusaLCEforBitwig/src/main/java/.../MusaLCESurfaceRelay.java`](https://github.com/javier-sy/MusaLCEforBitwig/blob/main/src/main/java/org/musadsl/musalce4bitwig/MusaLCESurfaceRelay.java) (relay side). The end-to-end wire-protocol spec lives in Pulso's repo (currently private; will be public once Pulso publishes).

Quick summary of address space:

- `/musalce/surface/inventory/{begin,add,remove,end}` — surface inventory (Pulso → server)
- `/musalce/surface/trigger event payload` — Pulso → server, dispatched to `on :event` via `@sequencer.launch`
- `/musalce/surface/state/{message,enabled,value,range} event …` — server → Pulso, repaints the Stream Deck
- `/musalce/surface/sync_request`, `/musalce/surface/state_request` — handshake messages

In the suite the relay is implemented on the Bitwig side only (`MusaLCEforBitwig/.../MusaLCESurfaceRelay.java`). **There is no Live-side relay yet** — Stream Deck integration is Bitwig-only at the time of writing.

## Current versions

| Component | Version |
|---|---|
| musa-dsl | 0.42.7+ |
| musalce-server | 0.7.2 |
| MusaLCEforBitwig | from `git describe` (typically `0.x`) |
| MusaLCEforLive | (no semver published) |
| MusaLCEClientForVSCode | 0.1.0 |
| Pulso Bridge | 0.x (private repo; pinned by commit until Pulso publishes) |
| Pulso Workflow (Stream Deck plugin) | matches Bridge |

Stay on the same release branch across components — pin musalce-server in your `Gemfile.lock`, build the matching `.bwextension`/Remote Script from the same point in time. There's no semantic compatibility matrix today; protocol changes are coordinated across components by commit (see e.g. the simultaneous `id → event` rename in musalce-server `346fe51` ↔ pulso `0c6536f` ↔ MusaLCEforBitwig `33e4d7c`).

## Where to go next

- Reference the **standalone REPL** workflow: [musa-dsl/docs/subsystems/repl.md](https://github.com/javier-sy/musa-dsl/blob/master/docs/subsystems/repl.md).
- Reference the **REPL commands** (`daw.*`, transport controls, sequencer DSL) of the suite: [musalce-server README](https://github.com/javier-sy/musalce-server#readme).
- Configure the **DAW extensions**: [MusaLCEforBitwig README](https://github.com/javier-sy/MusaLCEforBitwig#readme), [MusaLCEforLive README](https://github.com/javier-sy/MusaLCEforLive#readme).
- Wire the **VSCode editor**: [MusaLCEClientForVSCode README](https://github.com/javier-sy/MusaLCEClientForVSCode#readme).
- Wire the **Stream Deck** (Bitwig only): pending Pulso's public release. The relay side is implemented in [`MusaLCEforBitwig/src/main/java/.../MusaLCESurfaceRelay.java`](https://github.com/javier-sy/MusaLCEforBitwig/blob/main/src/main/java/org/musadsl/musalce4bitwig/MusaLCESurfaceRelay.java) and ready for Pulso to connect once it ships.
