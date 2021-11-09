require 'musa-dsl/core-ext/dynamic-proxy'

class Track
  def initialize(id, midi_devices)
    @id = id
    @midi_devices = midi_devices
    @output = Musa::Extension::DynamicProxy::DynamicProxy.new
  end

  attr_reader :id, :name

  def send
    @output
  end

  def _update_name(value)
    @name = value
    puts "track #{@id} assigned name #{@name}"
  end

  def _update_has_midi_input(value); @has_midi_input = value == 1; end
  def _update_has_midi_output(value); @has_midi_output = value == 1; end
  def _update_has_audio_input(value); @has_audio_input = value == 1; end
  def _update_has_audio_output(value); @has_audio_output = value == 1; end

  def _update_current_input_routing(value)
    @current_input_routing = value
  end

  def _update_current_input_sub_routing(value)
    @current_input_sub_routing = value

    effective_midi_voice = nil

    if @has_midi_input
      device = @midi_devices.find(@current_input_routing)

      if device
        port = /Ch\. (?<port>\d+)/.match(@current_input_sub_routing)&.[](:port)
        effective_midi_voice = device.ports[port.to_i - 1] if port

        puts "track #{@id} assigned new input: device '#{device.name}' #{effective_midi_voice}"
      end
    end

    @output.receiver = effective_midi_voice
  end

  def _update_current_output_routing(value); @current_output_routing = value; end
  def _update_current_output_sub_routing(value); @current_output_sub_routing = value; end
end


class Tracks
  include Enumerable

  def initialize(midi_devices)
    @midi_devices = midi_devices
    @tracks = {}
  end

  def grant_registry(id, name = nil,
                     has_midi_input = nil, has_midi_output = nil,
                     has_audio_input = nil, has_audio_output = nil,
                     current_input_routing = nil, current_input_sub_routing = nil,
                     current_output_routing = nil, current_output_sub_routing = nil)

    track = @tracks[id]

    unless track
      track = Track.new(id, @midi_devices)
      @tracks[id] = track
    end

    track._update_name(name) if name
    track._update_has_midi_input(has_midi_input) if has_midi_input
    track._update_has_midi_output(has_midi_output) if has_midi_output
    track._update_has_audio_input(has_audio_input) if has_audio_input
    track._update_has_audio_output(has_audio_output) if has_audio_output
    track._update_current_input_routing(current_input_routing) if current_input_routing
    track._update_current_input_sub_routing(current_input_sub_routing) if current_input_sub_routing
    track._update_current_output_routing(current_output_routing) if current_output_routing
    track._update_current_output_sub_routing(current_output_sub_routing) if current_output_sub_routing
  end

  def each(&block)
    if block_given?
      @tracks.values.each(&block)
    else
      @tracks.values.each
    end
  end

  def [](id)
    @tracks[id]
  end

  def find_by_name(name)
    @tracks.values.select { |_| _.name == name }
  end
end
