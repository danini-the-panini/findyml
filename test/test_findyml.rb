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

  def test_find
    out, err = capture_io do
      Findyml.find('foo.bar', File.join(__dir__, 'yaml'))
    end

    assert_equal File.join(__dir__, 'yaml', 'another_example.yml').to_s, out.lines[0].chomp
    assert_equal File.join(__dir__, 'yaml', 'example.yml').to_s, out.lines[1].chomp
    assert_empty err
  end
end
