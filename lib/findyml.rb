# frozen_string_literal: true

require "yaml"

require_relative "findyml/version"

module Findyml
  class Error < StandardError; end

  def self.find(key, dir: Dir.pwd)
    # TODO: cache fast key lookup in a temporary sqlite db?
    key_path = key.split('.').map { |k|
      k.match?(/\d+/) ? k.to_i : k
    }
    files = Dir.glob(File.join(dir, '**', '*.yml'))
    files.each do |file|
      # TODO: do our own parsing or otherwise find a way to get line numbers
      #       we also want to be super permissive and fast
      #       we don't care about the values
      #       and we want to keep the keys as strings
      #       oh and we want to have line numbers!
      yaml = YAML.unsafe_load_file(file)

      # TODO: if a value is _actually_ nil then this will give a false negative
      #       custom parser could do a line-by-line stream rather
      #       and just care about key presence
      #       also this raises if you try dig into a terminal value, e.g. string
      puts file if yaml.dig(*key_path)
    rescue YAML::SyntaxError => e
      # just skip files we can't parse
      # TODO: silence warnings?
      warn "Skipping #{file} due to parse error"
    end
  end
end
