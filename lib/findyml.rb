# frozen_string_literal: true

require "yaml"

require_relative "findyml/version"

module Findyml
  class Error < StandardError; end

  Key = Struct.new(:node, :path, :terminal, :alias_path) do
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
        yield Key.new(key_node.node, new_path, children.nil?, new_alias_path)
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

  def self.find(key, dir = Dir.pwd)
    # TODO: cache fast key lookup in a temporary sqlite db?
    key_path = parse_key(key)
    files = Dir.glob(File.join(dir, '**', '*.yml'))
    files.each do |file|
      FileExtractor.call(file) do |k|
        yield "#{file}:#{k.line}#{k.alias_path.map{"(#{_1.start_line+1})"}.join('')}" if k.match?(key_path)
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
