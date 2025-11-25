require 'musa-dsl/core-ext/dynamic-proxy'

module MusaLCEServer
  module Bitwig
    # Collection of tracks for Bitwig.
    #
    # Tracks are created dynamically based on channel names received
    # from the Bitwig controller extension.
    #
    # @api private
    class Tracks
      include Enumerable

      # Creates a new tracks collection.
      #
      # @param logger [Logger] the logger
      def initialize(logger:)
        @logger = logger
        @tracks = {}
      end

      # Creates a new track with the given name.
      #
      # @param name [String] the track name
      # @return [Track] the created track
      def create(name)
        @tracks[name] = Track.new(name, logger: @logger)
      end

      # Iterates over all tracks.
      #
      # @yield [Track] each track
      # @return [Enumerator] if no block given
      def each(&block)
        if block_given?
          @tracks.values.each(&block)
        else
          @tracks.values.each
        end
      end

      # Retrieves a track by name.
      #
      # @param name [String] the track name
      # @return [Track, nil] the track or nil if not found
      def [](name)
        @tracks[name]
      end

      # Sets a track by name.
      #
      # @param name [String] the track name
      # @param track [Track] the track
      # @return [Track] the track
      def []=(name, track)
        @tracks[name] = track
      end
    end

    # Represents a track in Bitwig with dynamic MIDI output.
    #
    # Uses DynamicProxy to allow the output to be reassigned
    # when channel mappings change.
    class Track
      # Creates a new track.
      #
      # @param name [String] the track name
      # @param logger [Logger] the logger
      def initialize(name, logger:)
        @name = name
        @logger = logger

        @output = Musa::Extension::DynamicProxy::DynamicProxy.new
      end

      # @!attribute [r] name
      #   @return [String] the track name
      attr_reader :name

      # Disconnects the current channel from this track.
      # @api private
      # @return [void]
      def _forget_channel
        @output.receiver = nil
      end

      # Sets the channel for this track.
      # @api private
      # @param new_channel [Channel] the channel to assign
      # @return [void]
      def _channel=(new_channel)
        @logger.info "Assigning #{new_channel} to track '#{@name}'"
        @output.receiver = new_channel.output
      end

      # Returns the MIDI output for this track.
      #
      # @return [Musa::Extension::DynamicProxy::DynamicProxy] proxy to the MIDI voice
      def out
        @output
      end
    end
  end
end