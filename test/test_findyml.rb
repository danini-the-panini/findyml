# frozen_string_literal: true

require "test_helper"

class TestFindyml < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Findyml::VERSION
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

    assert_equal ['foo', :splat, 'baz'], Findyml.parse_key('foo.*.baz')
    assert_equal ['foo', '*', 'baz'],    Findyml.parse_key('foo."*".baz')
    assert_equal ['foo', '*', 'baz'],    Findyml.parse_key("foo.'*'.baz")
    assert_equal ['foo', 'bar', '*'],    Findyml.parse_key("foo.bar.'*'")

    assert_equal [:splat, 'foo', 'bar'],         Findyml.parse_key(".foo.bar")
    assert_equal ['foo', 'bar', :splat],         Findyml.parse_key("foo.bar.")
    assert_equal ['foo', 'bar', :splat],         Findyml.parse_key("foo.bar.*")
    assert_equal [:splat, 'foo', 'bar', :splat], Findyml.parse_key(".foo.bar.")
    assert_equal [:splat, 'foo', 'bar', :splat], Findyml.parse_key("*.foo.bar.*")

    assert_raises { Findyml.parse_key("foo.'bar") }
    assert_raises { Findyml.parse_key("foo.'bar.baz") }
  end

  def test_key_match
    assert_key_match 'foo', 'foo'

    refute_key_match 'foo', 'bar'


    assert_key_match 'foo.bar',     'foo.bar'
    assert_key_match 'foo.bar.baz', 'foo.bar.baz'

    refute_key_match 'foo.bar', 'foo.baz'
    refute_key_match 'foo.bar', 'foz.bar'
    refute_key_match 'foo.bar', 'foo.bar.baz'


    assert_key_match '.bar',  'foo.bar'
    assert_key_match '*.bar', 'foo.bar'

    refute_key_match '*.bar', 'foo.bar.baz'

    assert_key_match 'foo.',  'foo.bar'
    assert_key_match 'foo.*', 'foo.bar'

    refute_key_match 'foo.*', 'foz.bar'
    refute_key_match 'foo.*', 'a.foo.bar'
    refute_key_match 'foo.*', 'foo'


    assert_key_match 'foo.*.baz',             'foo.bar.baz'
    assert_key_match 'foo.*.wat',             'foo.bar.baz.qux.norf.wat'
    assert_key_match 'foo.*.qux.*.wat',       'foo.bar.baz.qux.norf.wat'
    assert_key_match 'foo.*.baz.qux.*.wat',   'foo.bar.baz.qux.norf.wat'
    assert_key_match 'foo.*.baz.qux.*.wat',   'foo.bar.baz.x.baz.qux.norf.wat'

    refute_key_match 'foo.*.baz',       'foo.baz' # TODO: questionable, should we do ** to allow this?
    refute_key_match 'foo.*.baz',       'foo.bar.baz.qux'
    refute_key_match 'foo.*.baz',       'a.foo.bar.baz'
    refute_key_match 'foo.*.qux.*.wat', 'foo.bar.baz.quux.norf.wat'
  end

  def test_munch
    assert_equal Findyml.munch(%w[a], %w[a]), %w[]
    assert_equal Findyml.munch(%w[a b], %w[a]), %w[b]
    assert_equal Findyml.munch(%w[a b a b c d], %w[a b]), %w[a b c d]
    assert_equal Findyml.munch(%w[a b a b c d], %w[a b c]), %w[d]

    assert_nil Findyml.munch(%w[], %w[b])
    assert_nil Findyml.munch(%w[a], %w[b])
    assert_nil Findyml.munch(%w[a], %w[a b])
    assert_nil Findyml.munch(%w[a b], %w[a b c])
    assert_nil Findyml.munch(%w[a b a b c d], %w[a b d])
    assert_nil Findyml.munch(%w[a b a b c], %w[a b c d])
  end

  def test_find
    assert_find_yaml 'foo.bar',               ['example.yml', 9]
    assert_find_yaml 'foo.multiline',         ['example.yml', 50]
    assert_find_yaml 'another_top_level_key', ['example.yml', 56]
  end

  def test_find_multiple_files
    assert_find_yaml 'also',                 ['another_example.yml', 1], ['example.yml', 4]
    assert_find_yaml 'also.in_another',      ['another_example.yml', 2], ['example.yml', 5]
    assert_find_yaml 'also.in_another.file', ['another_example.yml', 3], ['example.yml', 6]
    assert_find_yaml 'qux.norf',             ['another_example.yml', 6]
  end

  def test_not_found
    refute_find_yaml 'does.not.exist'
  end

  def test_quoted_keys
    assert_find_yaml '"foo"',         ['example.yml', 8]
    assert_find_yaml '"foo".bar',     ['example.yml', 9]
    assert_find_yaml '"foo"',         ['example.yml', 8]
    assert_find_yaml 'foo."bar"',     ['example.yml', 9]
    assert_find_yaml 'foo."bar".baz', ['example.yml', 10]

    assert_find_yaml "'foo'",         ['example.yml', 8]
    assert_find_yaml "'foo'.bar",     ['example.yml', 9]
    assert_find_yaml "foo.'bar'",     ['example.yml', 9]
    assert_find_yaml "foo.'bar'.baz", ['example.yml', 10]

    assert_find_yaml "foo.wierdness.'Funny key'",              ['example.yml', 15]
    assert_find_yaml "foo.wierdness.'Funny key with : in it'", ['example.yml', 16]
    assert_find_yaml "foo.wierdness.'Funny key with . in it'", ['example.yml', 17]
    assert_find_yaml "foo.wierdness.'asdf.qwer'",              ['example.yml', 18]

    refute_find_yaml "foo.wierdness.asdf.qwer"
  end

  def test_non_string_keys
    assert_find_yaml 'foo.wierdness.0',           ['example.yml', 23]
    assert_find_yaml 'foo.wierdness.yes',         ['example.yml', 24]
    assert_find_yaml 'foo.wierdness.2020-01-01',  ['example.yml', 25]
    assert_find_yaml 'foo.wierdness.:symbol',     ['example.yml', 26]
    assert_find_yaml 'foo.wierdness.:',           ['example.yml', 27]
    assert_find_yaml 'foo.wierdness.::',          ['example.yml', 28]
    assert_find_yaml 'foo.wierdness.:::',         ['example.yml', 29]
    assert_find_yaml 'foo.wierdness.[1,2,3]',     ['example.yml', 30]
    assert_find_yaml 'foo.wierdness."{foo:bar}"', ['example.yml', 31]
  end

  def test_arrays
    assert_find_yaml 'foo.array.0', ['example.yml', 33]
    assert_find_yaml 'foo.array.1', ['example.yml', 34]
    assert_find_yaml 'foo.array.2', ['example.yml', 35]

    refute_find_yaml 'foo.array.3'

    assert_find_yaml 'foo.arrays_of_objects.0.foo', ['example.yml', 37]
    assert_find_yaml 'foo.arrays_of_objects.1.foo', ['example.yml', 39]
    assert_find_yaml 'foo.arrays_of_objects.1.bar', ['example.yml', 40]

    refute_find_yaml 'foo.arrays_of_objects.3.foo'
  end

  def test_alias
    assert_find_yaml 'foo_aliases.aliased.alias_key',         ['aliases.yml', 2, 6]
    assert_find_yaml 'foo_aliases.aliased.another_alias_key', ['aliases.yml', 3, 6]

    assert_find_yaml 'foo_aliases.inherit_alias.alias_key',         ['aliases.yml', 2, 8]
    assert_find_yaml 'foo_aliases.inherit_alias.another_alias_key', ['aliases.yml', 3, 8]
    assert_find_yaml 'foo_aliases.inherit_alias.another_key',       ['aliases.yml', 9]

    assert_find_yaml 'foo_aliases.override_alias.alias_key',         ['aliases.yml', 12]
    assert_find_yaml 'foo_aliases.override_alias.another_alias_key', ['aliases.yml', 3, 11]

    assert_find_yaml 'foo_aliases.alias_another_alias.alias_key',         ['aliases.yml', 2, 8, 13]
    assert_find_yaml 'foo_aliases.alias_another_alias.another_alias_key', ['aliases.yml', 3, 8, 13]
    assert_find_yaml 'foo_aliases.alias_another_alias.another_key',       ['aliases.yml', 9, 13]

    assert_find_yaml 'foo_aliases.alias_override_alias.alias_key',         ['aliases.yml', 12, 14]
    assert_find_yaml 'foo_aliases.alias_override_alias.another_alias_key', ['aliases.yml', 3, 11, 14]

    assert_find_yaml 'foo_aliases.override_alias_alias.alias_key',         ['aliases.yml', 17]
    assert_find_yaml 'foo_aliases.override_alias_alias.another_alias_key', ['aliases.yml', 3, 8, 16]
    assert_find_yaml 'foo_aliases.override_alias_alias.another_key',       ['aliases.yml', 18]
  end

  def test_partial_match
    assert_find_yaml '.bar.baz',            ['example.yml', 10]
    assert_find_yaml '.in_another.file',    ['another_example.yml', 3], ['example.yml', 6]
    assert_find_yaml '.bar',                ['example.yml', 9], ['example.yml', 38], ['example.yml', 40]
    assert_find_yaml '.foo',                ['example.yml', 37], ['example.yml', 39]
    assert_find_yaml '*.bar.baz',           ['example.yml', 14]
    assert_find_yaml '*.in_another_file',   ['another_example.yml', 3], ['example.yml', 10]
    assert_find_yaml '*.bar',               ['example.yml', 13], ['example.yml', 42], ['example.yml', 44]
    assert_find_yaml '*.foo',               ['example.yml', 41], ['example.yml', 43]

    assert_find_yaml 'foo.bar.',  ['example.yml', 13]
    assert_find_yaml 'foo.bar.*', ['example.yml', 13]

    assert_find_yaml '.bar.',   ['example.yml', 13]
    assert_find_yaml '*.bar.*', ['example.yml', 13]

    assert_find_yaml 'foo.*.baz', ['example.yml', 14]
    assert_find_yaml 'foo.*.bar', ['example.yml', 42], ['example.yml', 44]

    assert_find_yaml '*.f.g.h',         ['example.yml', 82]
    assert_find_yaml 'a.b.c.*.f.g.h',   ['example.yml', 82]
    assert_find_yaml 'a.*.d.e.*.h',     ['example.yml', 82]
    assert_find_yaml 'a.*.d.e.f.*',     ['example.yml', 80]

    assert_find_yaml 'FOO.BAR.QUX.FOO.BAR.BAZ.QUX', ['example.yml', 90]
    assert_find_yaml '*.BAR.BAZ.QUX',               ['example.yml', 90]
    assert_find_yaml '*.BAR.BAZ.*',                 ['example.yml', 89]
    assert_find_yaml '*.BAR.*',                     ['example.yml', 85], ['example.yml', 89]

    refute_find_yaml '.another_top_level_key'
    refute_find_yaml 'foo.bar.baz.'

    refute_find_yaml '*.another_top_level_key'
    refute_find_yaml 'foo.bar.baz.*'
  end

  private

  def assert_find_yaml(key, *expected, base: File.join(__dir__, 'yaml'))
    actual_results = Findyml.find(key, base).map { |k| [k.file, k.line, *k.alias_path.map{_1.start_line+1}] }
    expected_results = expected.map { |file, line, *aliases| [File.join(base, file), line, *aliases] }


    assert_equal expected_results, actual_results
  end

  def refute_find_yaml(key, base: File.join(__dir__, 'yaml'))
    results = []
    Findyml.find(key, base) { results << _1 }

    assert_empty results
  end

  def assert_key_match(query, path)
    assert Findyml.key_match?(Findyml.parse_key(path), Findyml.parse_key(query))
  end

  def refute_key_match(query, path)
    refute Findyml.key_match?(Findyml.parse_key(path), Findyml.parse_key(query))
  end
end
