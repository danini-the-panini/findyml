# frozen_string_literal: true

require "yaml"

require_relative "findyml/version"

module Findyml
  class Error < StandardError; end

  Key = Struct.new(:node, :path, :terminal) do
    def terminal? = terminal

    def match?(key_path)
      # TODO: partial path(s)
      key_path == path
    end

    def line
      node.start_line + 1
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
      case node
      when Integer then nil
      else node.start_line
      end
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
        puts "---"
        print_nodes(nodes)
        extract_nodes(nodes, &block)
      end
    end

    def print_nodes(nodes, indent='')
      nodes.each do |key_node, (children, yaml_node)|
        puts "#{indent}#{key_node}: #{children ? '...' : 'X'}"
        print_nodes(children, indent + '  ') if children
      end
    end

    def extract_nodes(nodes, path=[], &block)
      nodes.each do |key_node, (children, yaml_node)|
        new_path = [*path, key_node.to_s]
        yield Key.new(key_node.node, new_path, children.nil?)
        extract_nodes(children, new_path, &block) if children
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
              h[KeyNode.new(key)] = construct_nodes(node)
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
        puts "vvvvv ALIAS:"
        p current_node.anchor
        puts KeyNode.new(@anchors[current_node.anchor].last).to_s
        print_nodes(@anchors[current_node.anchor].first)
        puts "^^^^^"
        return @anchors[current_node.anchor] # TODO: deep dup and re-jig?
      end

      case current_node
      when Psych::Nodes::Mapping, Psych::Nodes::Sequence, Psych::Nodes::Scalar
        @anchors[current_node.anchor] = [nodes, current_node] if current_node.anchor
      end

      [nodes, current_node]
    end

    def to_s
      "FileExtractor(#{@file})"
    end

    def inspect
      "#<Findyml::FileExtractor @file=#{@file.inspect}>"
    end
  end

  def self.find(key, dir = Dir.pwd)
    # TODO: cache fast key lookup in a temporary sqlite db?
    key_path = parse_key(key)
    files = Dir.glob(File.join(dir, '**', '*.yml'))
    files.each do |file|
      FileExtractor.call(file) do |k|
        yield "#{file}:#{k.line}" if k.match?(key_path)
      end
    rescue YAML::SyntaxError
      # just skip files we can't parse
      # TODO: silence warnings?
      warn "Skipping #{file} due to parse error"
    end
  end

  def self.parse_key(key)
    pre  = []
    post = []
    if key =~ /\A\./
      key = $'
      pre << :*
    end
    if key =~ /\.\z/
      key = $`
      post << :*
    end
    [*pre, *parse_key_parts(key), *post]
  end

  def self.parse_key_parts(key)
    invalid_key! if key.empty?

    case key
    when /\A['"]/
      invalid_key! unless $' =~ /#{$&}/

      quoted_key = $`

      case $'
      when ''     then [quoted_key]
      when /\A\./ then [quoted_key, *parse_key_parts($')]
      else invalid_key!
      end
    when /\./
      invalid_key! if $`.empty?
      k = $` == '*' ? :* : $`
      [k, *parse_key_parts($')]
    else
      [key]
    end
  end

  def self.invalid_key!
    raise Error, "invalid key"
  end
end
