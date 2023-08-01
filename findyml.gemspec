# frozen_string_literal: true

require_relative "lib/findyml/version"

Gem::Specification.new do |spec|
  spec.name = "findyml"
  spec.version = Findyml::VERSION
  spec.authors = ["Danielle Smith"]
  spec.email = ["code@danini.dev"]

  spec.summary = "Search for yaml keys across multiple files"
  spec.description = "Even wondered where that i18n locale was defined but your project is massive and legacy and has multiple competing inconsistent standards of organisation? Let findyml ease your pain by finding that key for you!"
  spec.homepage = "https://github.com/danini-the-panini/findyml"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/danini-the-panini/findyml"
  spec.metadata["changelog_uri"] = "https://github.com/danini-the-panini/findyml/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # spec.add_dependency "sqlite3", "~> 1.6"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
