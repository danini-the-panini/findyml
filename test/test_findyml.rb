# frozen_string_literal: true

require "test_helper"

class TestFindyml < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Findyml::VERSION
  end

  def test_deep_key_presence?
    assert Findyml.deep_key_presence?({ 'foo' => 'bar' }, ['foo'])
    assert Findyml.deep_key_presence?({ 'foo' => { 'bar' => 'baz' } }, ['foo', 'bar'])
    assert Findyml.deep_key_presence?({ 'foo' => { 'bar' => 'baz' } }, ['foo'])
    assert Findyml.deep_key_presence?({ 'foo' => ['bar', 'baz'] }, ['foo', 0])
    assert Findyml.deep_key_presence?({ 'foo' => ['bar', 'baz'] }, ['foo', 1])
    assert Findyml.deep_key_presence?({ 'foo' => [{ 'bar' => 'baz' }, { 'qux' => 'norf' }] }, ['foo', 1, 'qux'])

    refute Findyml.deep_key_presence?({ 'foo' => 'bar' }, ['bar'])
    refute Findyml.deep_key_presence?({ 'foo' => 'bar' }, ['foo', 'bar'])
    refute Findyml.deep_key_presence?({ 'foo' => { 'bar' => 'baz' } }, ['foo', 'baz'])
    refute Findyml.deep_key_presence?({ 'foo' => { 'bar' => 'baz' } }, ['bar', 'baz'])
    refute Findyml.deep_key_presence?({ 'foo' => { 'bar' => 'baz' } }, ['foo', 'bar', 'baz'])
    refute Findyml.deep_key_presence?({ 'foo' => ['bar', 'baz'] }, ['foo', 2])
    refute Findyml.deep_key_presence?({ 'foo' => ['bar', 'baz'] }, ['foo', 'bar'])
    refute Findyml.deep_key_presence?({ 'foo' => ['bar', 'baz'] }, ['foo', -1])
    refute Findyml.deep_key_presence?({ 'foo' => [{ 'bar' => 'baz' }, { 'qux' => 'norf' }] }, ['foo', 1, 'bar'])
    refute Findyml.deep_key_presence?({ 'foo' => [{ 'bar' => 'baz' }, { 'qux' => 'norf' }] }, ['foo', 2, 'bar'])
  end

  def find
    assert_find_yaml 'foo.bar',               'example.yml'
    assert_find_yaml 'foo.multiline',         'example.yml'
    assert_find_yaml 'another_top_level_key', 'example.yml'
  end

  def test_find_multiple_files
    assert_find_yaml 'also',                 'another_example.yml', 'example.yml'
    assert_find_yaml 'also.in_another',      'another_example.yml', 'example.yml'
    assert_find_yaml 'also.in_another.file', 'another_example.yml', 'example.yml'
    assert_find_yaml 'qux.norf',             'another_example.yml'
  end

  def test_not_found
    refute_find_yaml 'does.not.exist'
  end

  def test_quoted_keys
    assert_find_yaml '"foo"',         'example.yml'
    assert_find_yaml '"foo".bar',     'example.yml'
    assert_find_yaml '"foo"',         'example.yml'
    assert_find_yaml 'foo."bar"',     'example.yml'
    assert_find_yaml 'foo."bar".baz', 'example.yml'

    assert_find_yaml "'foo'",         'example.yml'
    assert_find_yaml "'foo'.bar",     'example.yml'
    assert_find_yaml "foo.'bar'",     'example.yml'
    assert_find_yaml "foo.'bar'.baz", 'example.yml'

    assert_find_yaml "foo.wierdness.'Funny Key'",              'example.yml'
    assert_find_yaml "foo.wierdness.'Funny Key with : in it'", 'example.yml'
    assert_find_yaml "foo.wierdness.'Funny Key with . in it'", 'example.yml'
    assert_find_yaml "foo.wierdness.'asdf.qwer'",              'example.yml'

    refute_find_yaml "foo.wierdness.asdf.qwer"
  end

  def test_non_string_keys
    assert_find_yaml 'foo.wierdness.0',            'example.yml'
    assert_find_yaml 'foo.wierdness.yes',          'example.yml'
    assert_find_yaml 'foo.wierdness.2020-01-01',   'example.yml'
    assert_find_yaml 'foo.wierdness.:symbol',      'example.yml'
    assert_find_yaml 'foo.wierdness.:',            'example.yml'
    assert_find_yaml 'foo.wierdness.::',           'example.yml'
    assert_find_yaml 'foo.wierdness.:::',          'example.yml'
    assert_find_yaml 'foo.wierdness.[1,2,3]',      'example.yml'
    assert_find_yaml 'foo.wierdness."{foo: bar}"', 'example.yml'
  end

  def test_arrays
    assert_find_yaml 'foo.array.0', 'example.yml'
    assert_find_yaml 'foo.array.1', 'example.yml'
    assert_find_yaml 'foo.array.2', 'example.yml'

    refute_find_yaml 'foo.array.3'

    assert_find_yaml 'foo.arrays_of_objects.0.foo', 'example.yml'
    assert_find_yaml 'foo.arrays_of_objects.1.foo', 'example.yml'
    assert_find_yaml 'foo.arrays_of_objects.1.bar', 'example.yml'

    refute_find_yaml 'foo.arrays_of_objects.3.foo'
  end

  def test_alias
    assert_find_yaml 'foo.alias.alias_key', 'example.yml'
    assert_find_yaml 'foo.alias.another_alias_key', 'example.yml'

    assert_find_yaml 'foo.inherit_alias.alias_key', 'example.yml'
    assert_find_yaml 'foo.inherit_alias.another_alias_key', 'example.yml'
    assert_find_yaml 'foo.inherit_alias.another_key', 'example.yml'

    assert_find_yaml 'foo.override_alias.alias_key', 'example.yml'
    assert_find_yaml 'foo.override_alias.another_alias_key', 'example.yml'
  end

  private

  def assert_find_yaml(key, *files, base: File.join(__dir__, 'yaml'))
    out, err = capture_io do
      Findyml.find(key, base)
    end

    assert_equal files.flatten.map { File.join(base, _1) }, out.lines.map(&:chomp).reject(&:empty?)
    assert_empty err
  end

  def refute_find_yaml(key, base: File.join(__dir__, 'yaml'))
    out, err = capture_io do
      Findyml.find(key, base)
    end

    assert_empty out
    assert_empty err
  end
end
