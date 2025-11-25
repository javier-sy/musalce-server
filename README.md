# MusaLCE Server

[![Ruby Version](https://img.shields.io/badge/ruby-2.7+-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.html)

**Musa-DSL Live Coding Environment Server for Ableton Live 11+ and Bitwig Studio 5+**

This server enables live coding music composition using [Musa-DSL](https://github.com/javier-sy/musa-dsl) with your favorite DAW and code editor.

## Overview

The MusaLCE system allows you to write Ruby code in your editor (Visual Studio Code recommended) and have it executed in real-time, sending MIDI to tracks in your DAW. The typical workflow is:

1. Start the MusaLCE Server with your DAW choice
2. Open your code editor with the MusaLCE extension
3. Write and execute Musa-DSL code interactively
4. The code controls MIDI instruments in your DAW

## Requirements

- Ruby 2.7+
- [Musa-DSL](https://github.com/javier-sy/musa-dsl) (installed automatically as dependency)
- A supported DAW with its controller extension:
  - **Bitwig Studio 5+** with [MusaLCE for Bitwig](https://github.com/javier-sy/MusaLCEforBitwig) Controller Extension
  - **Ableton Live 11+** with [MusaLCE for Live](https://github.com/javier-sy/MusaLCEforLive) MIDI Remote Script
- A code editor with MusaLCE client extension:
  - **Visual Studio Code** (recommended) with [MusaLCE Client for VSCode](https://github.com/javier-sy/MusaLCEClientForVSCode)
  - Atom with [MusaLCE Client for Atom](https://github.com/javier-sy/MusaLCEClientForAtom) (Atom is discontinued)

## Installation

If you're using Bundler, add this line to your application's Gemfile:

```ruby
gem 'musalce-server'
```

Otherwise:

```bash
gem install musalce-server
```

## Quick Start

1. **Install the DAW controller extension** for your DAW (Bitwig or Live)
2. **Install the VSCode extension** [MusaLCE Client for VSCode](https://github.com/javier-sy/MusaLCEClientForVSCode)
3. **Start your DAW** and ensure the MusaLCE controller is loaded
4. **Start the server** (see below)
5. **Open VSCode** and create a `.rb` file
6. **Execute code** using the MusaLCE extension commands

## Starting the Server

The `musalce-server` command starts the live coding server:

```bash
musalce-server <daw>
```

Where `<daw>` is one of:
- `bitwig` - for Bitwig Studio
- `live` - for Ableton Live

Examples:

```bash
musalce-server bitwig   # Start server for Bitwig Studio
musalce-server live     # Start server for Ableton Live
```

The server runs in the foreground and logs activity to the console. Use `Ctrl+C` or the `shutdown` command from the editor to stop it.

## Running Environment

A complete MusaLCE live coding session requires **three components running simultaneously**:

1. **Code Editor** (Visual Studio Code with MusaLCE extension)
   - Where you write and execute Ruby/Musa-DSL code
   - Connects to musalce-server via TCP port 1327

2. **MusaLCE Server** (`musalce-server` command)
   - Receives code from the editor and executes it
   - Communicates with the DAW via OSC
   - Manages MIDI routing and the Musa-DSL sequencer

3. **DAW** (Bitwig Studio or Ableton Live)
   - With the corresponding MusaLCE controller extension loaded
   - Receives transport and sync commands from the server
   - Routes MIDI from the server to instruments/tracks

## Architecture

The MusaLCE system connects three components:

```
┌─────────────────────┐        TCP         ┌─────────────────────┐
│    Code Editor      │◄──────────────────►│   MusaLCE Server    │
│  (VSCode + Plugin)  │    port 1327       │   (Ruby + REPL)     │
└─────────────────────┘                    └─────────────────────┘
                                                   │ ▲
                                           OSC     │ │    OSC
                                       port 10001  │ │  port 11011
                                                   ▼ │
                                           ┌─────────────────────┐
                                           │  DAW Controller     │
                                           │    Extension        │
                                           │  (Bitwig or Live)   │
                                           └─────────────────────┘
                                                   │
                                                   │ MIDI
                                                   ▼
                                           ┌─────────────────────┐
                                           │   DAW Tracks &      │
                                           │   Instruments       │
                                           └─────────────────────┘
```

### Communication Ports

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 1327 | TCP | Editor ↔ Server | REPL code execution |
| 10001 | OSC/UDP | Server → DAW | Transport commands, sync requests |
| 11011 | OSC/UDP | DAW → Server | Track info, controller registration |

## REPL Commands Reference

The following commands are available in the REPL context (executed from your editor):

### DAW Access

```ruby
daw                      # Access the DAW controller object
daw.sequencer            # Access the Musa-DSL sequencer
daw.clock                # Access the MIDI clock
daw.tracks               # Access all tracks
```

### Track Operations

```ruby
# Get a track by name
bass = daw.track('Bass')

# Get all tracks with a name (Live only, can have duplicates)
drums = daw.track('Drums', all: true)

# Send MIDI to a track
bass.out.note(60, velocity: 100, duration: 1)
bass.out.note_on(60, 100)
bass.out.note_off(60)
bass.out.control_change(1, 64)
bass.out.program_change(5)
bass.out.all_notes_off
```

### Transport Controls

Transport controls send commands to the DAW. **Only available for Bitwig Studio** (Live's MIDI Remote Script API doesn't support transport control).

```ruby
daw.play                 # Start playback
daw.stop                 # Stop playback
daw.continue             # Continue from current position
daw.goto(5)              # Go to bar 5
daw.record               # Start recording
```

### Sequencer (Musa-DSL)

All [Musa-DSL](https://github.com/javier-sy/musa-dsl) sequencer methods are available:

```ruby
# Schedule events at specific positions
at 1 do
  bass.out.note(48, velocity: 80, duration: 0.5)
end

# Wait relative to current position
wait 2 do
  bass.out.note(52, velocity: 80, duration: 0.5)
end

# Schedule repeating patterns (returns EveryControl)
pattern = every 4 do
  drums.out.note(36, velocity: 100, duration: 0.25)
end

# Play a series (returns PlayControl)
serie = S(60, 62, 64, 65, 67)
melody = play serie do |note|
  bass.out.note(note, velocity: 80, duration: 1)
end

# Animate values over time (returns MoveControl)
sweep = move from: 0, to: 127, duration: 4 do |value|
  bass.out.control_change(1, value.to_i)
end
```

### Controlling Playback

The `play`, `every`, and `move` methods return control objects that allow you to stop, pause, and monitor playback:

```ruby
# Stop a pattern or playback
pattern.stop
melody.stop

# Check status
pattern.stopped?          # true if stopped
melody.paused?            # true if paused

# Pause and continue (for play)
melody.pause
melody.continue

# Callback when stopped
pattern.on_stop do
  puts "Pattern stopped"
end

# Callback after play completes
melody.after(2) do
  puts "2 bars after melody finished"
end
```

### Utility Commands

```ruby
reload                   # Reload DAW controller extension
daw.sync                 # Re-synchronize track information
daw.panic!               # Send All Notes Off to all tracks
shutdown                 # Stop the server
```

### Module Import

```ruby
# Import additional modules into the REPL context
import(MyHelperModule)
```

### File Require

```ruby
# Require files relative to your editor's current file
require_relative 'my_patterns'
```

## DAW-Specific Notes

### Bitwig Studio

Requires [MusaLCE for Bitwig](https://github.com/javier-sy/MusaLCEforBitwig) controller extension.

- Full transport control support (play, stop, continue, goto, record)
- Track names must be unique
- MIDI clock sync from any controller marked as clock source
- Controllers and channels configured in the Bitwig extension

### Ableton Live

Requires [MusaLCE for Live](https://github.com/javier-sy/MusaLCEforLive) MIDI Remote Script.

- **No transport control** (Live's MIDI Remote Script API limitation)
- Multiple tracks can have the same name
- Use `daw.midi_sync('Device Name')` to set MIDI clock source
- Track routing configured in Live's preferences

```ruby
# Set MIDI clock source for Live
daw.midi_sync('IAC Driver Bus 1')
```

## Related Projects

| Component | Description |
| --- | --- |
| [Musa-DSL](https://github.com/javier-sy/musa-dsl) | Core music composition DSL |
| [MusaLCE Server](https://github.com/javier-sy/musalce-server) | Live coding server (this gem) |
| [MusaLCE for Bitwig](https://github.com/javier-sy/MusaLCEforBitwig) | Bitwig Studio controller extension |
| [MusaLCE for Live](https://github.com/javier-sy/MusaLCEforLive) | Ableton Live MIDI Remote Script |
| [MusaLCE Client for VSCode](https://github.com/javier-sy/MusaLCEClientForVSCode) | VSCode extension (recommended) |
| [MusaLCE Client for Atom](https://github.com/javier-sy/MusaLCEClientForAtom) | Atom plugin (discontinued) |

## Documentation

API documentation is available via YARD:

```bash
bundle exec yard doc
bundle exec yard server
```

Then open http://localhost:8808 in your browser.

## Author

* [Javier Sánchez Yeste](https://github.com/javier-sy)

## License

[MusaLCE Server](https://github.com/javier-sy/musalce-server) Copyright (c) 2021-2025 [Javier Sánchez Yeste](https://yeste.studio), licensed under GPL 3.0 License
