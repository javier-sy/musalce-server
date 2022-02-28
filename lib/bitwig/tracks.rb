require 'musa-dsl/core-ext/dynamic-proxy'

module MusaLCEServer
  module Bitwig
    class Tracks
      include Enumerable

      def initialize(logger:)
        @logger = logger
        @tracks = {}
      end

      def create(name)
        @tracks[name] = Track.new(name, logger: @logger)
      end

      def each(&block)
        if block_given?
          @tracks.values.each(&block)
        else
          @tracks.values.each
        end
      end

      def [](name)
        @tracks[name]
      end

      def []=(name, track)
        @tracks[name] = track
      end
    end

    class Track
      def initialize(name, logger:)
        @name = name
        @logger = logger

        @output = Musa::Extension::DynamicProxy::DynamicProxy.new
      end

      attr_reader :name

      def _forget_channel
        @output.receiver = nil
      end

      def _channel=(new_channel)
        @logger.info "Assigning #{new_channel} to track '#{@name}'"
        @output.receiver = new_channel.output
      end

      def out
        @output
      end
    end
  end
end