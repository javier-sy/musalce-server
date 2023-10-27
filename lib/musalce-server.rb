require 'musa-dsl'

require 'osc-ruby'
require 'osc-ruby/em_server'

require_relative 'live/live'
require_relative 'bitwig/bitwig'

module MusaLCEServer
  VERSION = '0.4.8'.freeze

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
