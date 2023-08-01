# frozen_string_literal: true

require "yaml"

require_relative "findyml/version"

module Findyml
  class Error < StandardError; end

  def self.find(key, dir = Dir.pwd)
    # TODO: cache fast key lookup in a temporary sqlite db?
    key_path = key.split('.').map { |k|
      k.match?(/\d+/) ? k.to_i : k
    }
    files = Dir.glob(File.join(dir, '**', '*.yml'))
    files.each do |file|
      # TODO: use YAML.parse to get raw nodes with line numbers
      #       or build our own custom handler
      yaml = YAML.unsafe_load_file(file)

      puts file if deep_key_presence?(yaml, key_path)
    rescue YAML::SyntaxError
      # just skip files we can't parse
      # TODO: silence warnings?
      warn "Skipping #{file} due to parse error"
    end
  end

  def self.deep_key_presence?(obj, key_path)
    return true if key_path.empty?
    key, *rest = key_path

    case obj
    when Hash then
      return false unless obj.key?(key)
      deep_key_presence?(obj[key], rest)
    when Array then
      return false unless key.is_a?(Integer)
      return false if key >= obj.size || key < 0
      deep_key_presence?(obj[key], rest)
    else
      false
    end
  end
end
