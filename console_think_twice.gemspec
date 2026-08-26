# frozen_string_literal: true

require_relative "lib/console_think_twice/version"

Gem::Specification.new do |spec|
  spec.name = "console_think_twice"
  spec.version = ConsoleThinkTwice::VERSION
  spec.authors = ["Agustin Gomez"]
  spec.email = ["57372662+agomezcampero@users.noreply.github.com"]

  spec.summary = "Ask for confirmation before destructive Active Record calls in a console."
  spec.description = "Prompts before destroy, destroy!, delete, destroy_all and delete_all when they are " \
    "called from a Rails console, so a stray User.destroy_all cannot wipe production. " \
    "Pass force: true to skip the prompt."
  spec.homepage = "https://github.com/agomezcampero/console-think-twice"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
end
