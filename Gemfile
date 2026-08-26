# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Set ACTIVERECORD_VERSION (e.g. "7.0") to run against an older Active Record than the newest
# one the gemspec allows. CI walks the whole supported range this way. Switching locally means
# re-resolving, so delete Gemfile.lock (it is not checked in) rather than reusing the old one.
activerecord = ENV["ACTIVERECORD_VERSION"].to_s

unless activerecord.empty?
  gem "activerecord", "~> #{activerecord}.0"
  gem "activesupport", "~> #{activerecord}.0"
end

gem "rake", "~> 13.0"
gem "rspec", "~> 3.13"
gem "sqlite3", (activerecord.start_with?("7.0") ? "~> 1.4" : ">= 2.1")
gem "standard", "~> 1.0"
