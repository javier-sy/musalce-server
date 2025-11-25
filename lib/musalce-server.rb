require 'musa-dsl'

require 'osc-ruby'
require 'osc-ruby/em_server'

require_relative 'version'
require_relative 'live/live'
require_relative 'bitwig/bitwig'

# Musa Live Coding Environment Server.
#
# This module provides the main entry point for the MusaLCE server,
# which enables live coding with Ableton Live 11+ and Bitwig Studio 5+.
#
# The server provides:
# - OSC communication with DAW controller extensions
# - MIDI device management and routing
# - A REPL (Read-Eval-Print-Loop) for interactive live coding
# - Integration with Musa-DSL sequencer for music composition
#
# @example Starting the server for Bitwig Studio
#   MusaLCEServer.run('bitwig')
#
# @example Starting the server for Ableton Live
#   MusaLCEServer.run('live')
#
# @see Daw Base class for DAW controllers
# @see Bitwig::Bitwig Bitwig Studio driver
# @see Live::Live Ableton Live driver
module MusaLCEServer
  # Starts the MusaLCE server for the specified DAW.
  #
  # This method initializes the DAW controller, sets up the REPL environment,
  # and starts the main server loop. The server runs until `shutdown` is called from the REPL.
  #
  # @param daw_name [String] the DAW to connect to ('bitwig' or 'live')
  # @return [void]
  # @raise [ArgumentError] if daw_name is nil or not a supported DAW
  #
  # @example
  #   MusaLCEServer.run('bitwig')
  def self.run(daw_name)
    raise ArgumentError, 'A daw must be specified. Options: \'bitwig\' or \'live\'' unless daw_name
    raise ArgumentError, "Incompatible DAW '#{daw_name}'. Options: 'bitwig' or 'live'" unless %w[bitwig live].include?(daw_name)

    main_thread = Thread.current

    daw = Daw.daw_controller_for(daw_name.to_sym)

    daw.sequencer.with(main_thread: main_thread, daw: daw, keep_block_context: false) do |main_thread:, daw:|
      @__main_thread = main_thread
      @__daw = daw

      alias __puts puts
      alias __require_relative require_relative

      def puts(...)
        @__repl.puts(...)
      end

      def require_relative(filename, from_server: false)
        if from_server
          require_relative filename
        else
          # @user_pathname is injected from REPL
          require @user_pathname.dirname + filename
        end
      end

      def daw
        @__daw
      end

      def reload
        @__daw.reload
      end

      def shutdown
        @__main_thread.wakeup
      end

      @__repl = Musa::REPL::REPL.new(binding, highlight_exception: false)
    end

    sleep
  end
end
