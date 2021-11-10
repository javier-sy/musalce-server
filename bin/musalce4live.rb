require 'musa-dsl'

require 'osc-ruby'
require 'osc-ruby/em_server'

require_relative '../lib/live'

main_thread = Thread.current
live = Live.default

live.sequencer.with(main_thread: main_thread, live: live) do |main_thread:, live:|
  @keep_proc_context_on_with = true

  @__main_thread = main_thread
  @__live = live

  alias __puts puts
  alias __require_relative require_relative

  def puts(...)
    @__repl.puts(...)
  end

  def require_relative(filename, from_server: false)
    if from_server
      require_relative filename
    else
      require @user_pathname.dirname + filename
    end
  end

  def live
    @__live
  end


  def reset
    # TODO
    puts "reset: missing operation"
  end

  def shutdown
    @__main_thread.wakeup
  end

  @__repl = Musa::REPL::REPL.new(binding)
end

sleep
