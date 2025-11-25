# Musa Live Coding Environment Server.
#
# A Ruby server for live coding with Ableton Live and Bitwig Studio DAWs.
# Provides OSC communication, MIDI device management, and a REPL for
# interactive music composition using Musa-DSL.
#
# @see MusaLCEServer.run Entry point for starting the server
# @see MusaLCEServer::Daw Base class for DAW controllers
#
# @author Javier Sánchez Yeste
# @since 0.1.0
module MusaLCEServer
  # Current version of the musalce-server gem.
  VERSION = '0.6.0'.freeze
end
