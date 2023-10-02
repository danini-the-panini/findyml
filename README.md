# Findyml

Search for yaml keys across multiple files

Ever wondered where that i18n locale was defined but your project is massive and legacy and has multiple competing inconsistent standards of organisation? Let findyml ease your pain by finding that key for you!

## Installation

```sh
gem install findyml
```

## Usage

```sh
findyml [path] query
```

Outputs all matching keys across all `*.yml` files in the given directory, including line and column number.

(Defaults to current directory if you don't specify a path)

Example:

```sh
findyml config/locales en.activerecord.attributes
# config/locales/active_record.en.yml:3:6
```

You can also do partial matches, by starting/ending with a dot or putting an asterisk (`*`) in place of a key.

```sh
findyml .activerecord.attributes
findyml 'en.*.attributes'
```

(You have to quote the query if you use `*` because your shell will think it is a dir glob)

**NOTE**: if you end with a dot, or the last key is an asterisk, it will return _every single sub key_. i.e. careful if you try `findyml en.` or `findyml en.*`, you will get every line of every english locale file 🙃.

## TODO

- Allow optional keys in query: `foo.[bar,baz].qux` (`qux` key in either `bar` or `baz` parent key)
- Allow negated keys in query: `foo.!bar.baz` (`baz` with any parent but `bar`)
- Partial key matches: `foo.bar_*` (any key starting with `bar_`)
- Allow `*` and `**` like directory globbing.
- Fuzzy matching?
- Find and fix bugs
- Optimisation, caching

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/danini-the-panini/findyml.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
