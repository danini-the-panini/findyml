# frozen_string_literal: true

require "yaml"

require_relative "findyml/version"

module Findyml
  class Error < StandardError; end

  def self.find(key, dir = Dir.pwd)
    # TODO: cache fast key lookup in a temporary sqlite db?
    key_path = parse_key(key)
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
      key = Integer(key, exception: false)
      return false unless key
      return false if key >= obj.size || key < 0
      deep_key_presence?(obj[key], rest)
    else
      false
    end
  end

  def self.parse_key(key)
    invalid_key! if key.empty?

    case key
    when /\A['"]/
      invalid_key! unless $' =~ /#{$&}/

      quoted_key = $`

      case $'
      when ''     then [quoted_key]
      when /\A\./ then [quoted_key, *parse_key($')]
      else invalid_key!
      end
    when /\./
      invalid_key! if $`.empty?
      [$`, *parse_key($')]
    else
      [key]
    end
  end

  def self.invalid_key!
    raise Error, "invalid key"
  end
end
