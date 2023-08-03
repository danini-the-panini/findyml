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

  def test_parse_key
    assert_equal ['foo'],                           Findyml.parse_key('foo')
    assert_equal ['foo', 'bar'],                    Findyml.parse_key('foo.bar')
    assert_equal ['foo', 'bar', '0', 'baz'],        Findyml.parse_key('foo.bar.0.baz')
    assert_equal ['foo', 'bar', 'baz'],             Findyml.parse_key('foo."bar".baz')
    assert_equal ['foo', 'bar.baz'],                Findyml.parse_key('foo."bar.baz"')
    assert_equal ['foo', 'bar.baz', 'qux'],         Findyml.parse_key("foo.'bar.baz'.qux")
    assert_equal ['foo', 'bar baz', 'qux'],         Findyml.parse_key("foo.'bar baz'.qux")
    assert_equal ['foo', '"bar baz"', 'qux'],       Findyml.parse_key("foo.'\"bar baz\"'.qux")
    assert_equal ['foo', "bar'bar", "baz'", 'qux'], Findyml.parse_key("foo.bar'bar.baz'.qux")
    assert_equal ['foo', 'bar"bar', 'baz"', 'qux'], Findyml.parse_key('foo.bar"bar.baz".qux')

    assert_equal [:*, 'foo', 'bar'],     Findyml.parse_key(".foo.bar")
    assert_equal ['foo', 'bar', :*],     Findyml.parse_key("foo.bar.")
    assert_equal [:*, 'foo', 'bar', :*], Findyml.parse_key(".foo.bar.")

    assert_raises { Findyml.parse_key("foo.'bar") }
    assert_raises { Findyml.parse_key("foo.'bar.baz") }
  end

  def find
    assert_find_yaml 'foo.bar',               'example.yml:13'
    assert_find_yaml 'foo.multiline',         'example.yml:61'
    assert_find_yaml 'another_top_level_key', 'example.yml:67'
  end

  def test_find_multiple_files
    assert_find_yaml 'also',                 'another_example.yml:1', 'example.yml:8'
    assert_find_yaml 'also.in_another',      'another_example.yml:2', 'example.yml:9'
    assert_find_yaml 'also.in_another.file', 'another_example.yml:3', 'example.yml:10'
    assert_find_yaml 'qux.norf',             'another_example.yml:6'
  end

  def test_not_found
    refute_find_yaml 'does.not.exist'
  end

  def test_quoted_keys
    assert_find_yaml '"foo"',         'example.yml:12'
    assert_find_yaml '"foo".bar',     'example.yml:13'
    assert_find_yaml '"foo"',         'example.yml:12'
    assert_find_yaml 'foo."bar"',     'example.yml:13'
    assert_find_yaml 'foo."bar".baz', 'example.yml:14'

    assert_find_yaml "'foo'",         'example.yml:12'
    assert_find_yaml "'foo'.bar",     'example.yml:13'
    assert_find_yaml "foo.'bar'",     'example.yml:13'
    assert_find_yaml "foo.'bar'.baz", 'example.yml:14'

    assert_find_yaml "foo.wierdness.'Funny key'",              'example.yml:19'
    assert_find_yaml "foo.wierdness.'Funny Key with : in it'", 'example.yml:20'
    assert_find_yaml "foo.wierdness.'Funny Key with . in it'", 'example.yml:21'
    assert_find_yaml "foo.wierdness.'asdf.qwer'",              'example.yml:22'

    refute_find_yaml "foo.wierdness.asdf.qwer"
  end

  def test_non_string_keys
    assert_find_yaml 'foo.wierdness.0',            'example.yml:27'
    assert_find_yaml 'foo.wierdness.yes',          'example.yml:28'
    assert_find_yaml 'foo.wierdness.2020-01-01',   'example.yml:29'
    assert_find_yaml 'foo.wierdness.:symbol',      'example.yml:30'
    assert_find_yaml 'foo.wierdness.:',            'example.yml:31'
    assert_find_yaml 'foo.wierdness.::',           'example.yml:32'
    assert_find_yaml 'foo.wierdness.:::',          'example.yml:33'
    assert_find_yaml 'foo.wierdness.[1,2,3]',      'example.yml:34'
    assert_find_yaml 'foo.wierdness."{foo: bar}"', 'example.yml:35'
  end

  def test_arrays
    assert_find_yaml 'foo.array.0', 'example.yml:37'
    assert_find_yaml 'foo.array.1', 'example.yml:38'
    assert_find_yaml 'foo.array.2', 'example.yml:39'

    refute_find_yaml 'foo.array.3'

    assert_find_yaml 'foo.arrays_of_objects.0.foo', 'example.yml:41'
    assert_find_yaml 'foo.arrays_of_objects.1.foo', 'example.yml:43'
    assert_find_yaml 'foo.arrays_of_objects.1.bar', 'example.yml:44'

    refute_find_yaml 'foo.arrays_of_objects.3.foo'
  end

  def test_alias
    assert_find_yaml 'foo.aliased.alias_key',         'example.yml:5(54)'
    assert_find_yaml 'foo.aliased.another_alias_key', 'example.yml:6(54)'

    assert_find_yaml 'foo.inherit_alias.alias_key',         'example.yml:5(56)'
    assert_find_yaml 'foo.inherit_alias.another_alias_key', 'example.yml:6(56)'
    assert_find_yaml 'foo.inherit_alias.another_key',       'example.yml:57'

    assert_find_yaml 'foo.override_alias.alias_key',         'example.yml:60'
    assert_find_yaml 'foo.override_alias.another_alias_key', 'example.yml:6(59)'

    assert_find_yaml 'foo.alias_another_alias.alias_key',         'example.yml:5(55)(61)'
    assert_find_yaml 'foo.alias_another_alias.another_alias_key', 'example.yml:6(55)(61)'
    assert_find_yaml 'foo.alias_another_alias.another_key',       'example.yml:57(61)'

    assert_find_yaml 'foo.alias_override_alias.alias_key',         'example.yml:60(62)'
    assert_find_yaml 'foo.alias_override_alias.another_alias_key', 'example.yml:6(58)(62)'

    assert_find_yaml 'foo.override_alias_alias.alias_key',         'example.yml:65'
    assert_find_yaml 'foo.override_alias_alias.another_alias_key', 'example.yml:6(55)(64)'
    assert_find_yaml 'foo.override_alias_alias.another_key',       'example.yml:66'
  end

  def test_partial_match
    assert_find_yaml '.bar.baz',            'example.yml:14'
    assert_find_yaml '.in_another_file',    'example.yml:10', 'another_example.yml:3'
    assert_find_yaml '.bar',                'example.yml:13', 'example.yml:42', 'example.yml:44'
    assert_find_yaml '.foo',                'example.yml:41', 'example.yml:43'

    assert_find_yaml 'foo.bar.', 'example.yml:13'

    assert_find_yaml '.bar.', 'example.yml:13'

    refute_find_yaml '.another_top_level_key'
    refute_find_yaml 'foo.bar.baz.'
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
