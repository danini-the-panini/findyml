# frozen_string_literal: true

require "yaml"

require_relative "findyml/version"

module Findyml
  class Error < StandardError; end

  Key = Struct.new(:file, :node, :path, :terminal, :alias_path) do
    def terminal? = terminal

    def line
      node.start_line + 1
    end

    def col
      node.start_column + 1
    end

    def inspect
      "#{path.map(&:inspect).join('.')} -> #{self}"
    end
  end

  class KeyNode
    attr_reader :node

    def initialize(node)
      @node = node
    end

    def ==(other)
      other.is_a?(KeyNode) &&
        node.class == other.node.class &&
        to_s == other.to_s
    end
    alias :eql? :==

    def hash
      [node.class, to_s].hash
    end

    def line
      node.start_line + 1
    end

    def to_s
      @to_s ||= case node
      when Psych::Nodes::Scalar
        node.value
      when Psych::Nodes::Mapping
        "{#{node.children.each_slice(2).map { |k, v| "#{KeyNode.new(k).to_s}:#{KeyNode.new(v).to_s}" }.join(',')}}"
      when Psych::Nodes::Sequence
        "[#{node.children.map { KeyNode.new(_1).to_s }.join(',')}]"
      end
    end

    def inspect
      "#<Findyml::KeyNode @node=#{self}>"
    end
  end

  class IndexNode < KeyNode
    def initialize(node, index)
      super(node)
      @index = index
    end

    def to_s
      @index.to_s
    end
  end

  class FileExtractor
    def self.call(file, &block)
      new(file).extract(&block)
    end

    def initialize(file)
      @file = File.expand_path(file)
      @yaml = YAML.parse_file(@file)
      @anchors = {}
    end

    def extract(&block)
      all_nodes = @yaml.children.map { construct_nodes(_1) }

      all_nodes.each do |nodes, _|
        extract_nodes(nodes, &block)
      end
    end

    def extract_nodes(nodes, path=[], alias_path=[], &block)
      nodes.each do |key_node, (children, yaml_node, alias_node)|
        new_path = [*path, key_node.to_s]
        new_alias_path = [*alias_path, *alias_node]
        yield Key.new(@file, key_node.node, new_path, children.nil?, new_alias_path)
        extract_nodes(children, new_path, new_alias_path, &block) if children
      end
    end

    def construct_nodes(current_node=yaml)
      nodes = case current_node
      when Psych::Nodes::Document
        return construct_nodes(current_node.children.first)
      when Psych::Nodes::Mapping
        current_node
          .children
          .each_slice(2)
          .each_with_object({}) { |(key, node), h|
            if key.is_a?(Psych::Nodes::Scalar) && key.value == '<<'
              h.merge!(construct_nodes(node).first)
            else
              key_node = KeyNode.new(key)
              h.delete(key_node)
              h[key_node] = construct_nodes(node)
            end
          }
      when Psych::Nodes::Sequence
        current_node
          .children
          .each_with_index
          .map { |node, index| [IndexNode.new(node, index), construct_nodes(node)] }
      when Psych::Nodes::Scalar
        nil
      when Psych::Nodes::Alias
        a_nodes, anchor = @anchors[current_node.anchor]
        return [a_nodes.transform_values { |(a, b, c)| [a, b, [*c, current_node]] }, anchor]
      end

      case current_node
      when Psych::Nodes::Mapping, Psych::Nodes::Sequence, Psych::Nodes::Scalar
        @anchors[current_node.anchor] = [nodes, current_node, []] if current_node.anchor
      end

      [nodes, current_node, []]
    end

    def to_s
      "FileExtractor(#{@file})"
    end

    def inspect
      "#<Findyml::FileExtractor @file=#{@file.inspect}>"
    end
  end

  def self.parse_options
    case ARGV.size
    when 1
      [Dir.pwd, ARGV.last]
    when 2
      ARGV
    else
      puts "Usage: #{$0} [path] query"
      exit(1)
    end
  end

  def self.find(query_string, dir = Dir.pwd)
    return to_enum(:find, query_string, dir) unless block_given?

    # TODO: cache fast key lookup in a temporary sqlite db?
    query = parse_key(query_string)
    files = Dir.glob(File.join(dir, '**', '*.yml'))
    files.each do |file|
      FileExtractor.call(file) do |key|
        yield key if key_match?(key.path, query)
      end
    rescue YAML::SyntaxError
      # just skip files we can't parse
      # TODO: silence warnings?
      warn "Skipping #{file} due to parse error"
    end
  end

  def self.find_and_print(*args)
    find(*args) do |key|
      puts "#{key.file}:#{key.line}:#{key.col}#{key.alias_path.map{"(#{_1.start_line+1})"}.join('')}"
    end
  end

  def self.parse_key(key)
    pre  = []
    post = []
    if key =~ /\A\./ # start with a dot
      key = $' # everything after the dot
      pre << :splat
    end
    if key =~ /\.\z/ # end with a dot
      key = $` # everything before the dot
      post << :splat
    end
    [*pre, *parse_key_parts(key), *post]
  end

  def self.parse_key_parts(key)
    invalid_key! if key.empty?

    case key
    # starts with quote
    when /\A['"]/
       # invalid unless rest has matching quote
      invalid_key! unless $' =~ /#{$&}/

      # everything before the next matching quote (i.e. contents of quotes)
      quoted_key = $`

      case $'
      # quote was at end of string
      when ''     then [quoted_key]

      # dot follows quote, parse everything after the dot
      when /\A\./ then [quoted_key, *parse_key_parts($')]

      # anything else after the quote is not allowed
      else invalid_key!
      end

    # includes a dot
    when /\./
      # invalid unless something before the dot
      invalid_key! if $`.empty?

      k = $` == '*' ? :splat : $`

      # parse everything after the dot
      [k, *parse_key_parts($')]

    # splat at the end of the string
    when '*' then [:splat]

    # single key query
    else [key]
    end
  end

  def self.invalid_key!
    raise Error, "invalid key"
  end

  def self.key_match?(path, query)
    path == query unless query.include? :splat

    query_parts = query.slice_before(:splat)

    query_parts.each do |q|
      case q
      in [:splat]
        return false if path.empty?
        path = []
      in [:splat, *partial]
        return false if path.empty?
        rest = munch(path[1..], partial)
        return false unless rest
        path = rest
      else
        return false unless path[0...q.size] == q
        path = path.drop(q.size)
      end
    end

    path.empty?
  end

  def self.munch(arr, part)
    raise ArgumentError, "part must not be empty" if part.empty?
    return if arr.empty?
    return if arr.size < part.size
    return arr[part.size..] if arr[0...part.size] == part

    munch(arr[1..], part)
  end
end
