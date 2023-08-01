# Findyml

Search for yaml keys across multiple files

Even wondered where that i18n locale was defined but your project is massive and legacy and has multiple competing inconsistent standards of organisation? Let findyml ease your pain by finding that key for you!

## Installation

    $ gem install findyml

## Usage

```sh
findyml [path] key
```

Example:

```sh
findyml config/locales en.activerecord.attributes
# config/locales/active_record.en.yml
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/danini-the-panini/findyml.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
