# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"
gem "rspec", "~> 3.13"
# Only the spec suite needs a database; the gem itself guards Active Record calls
# whatever adapter the host app uses.
gem "sqlite3", ">= 2.1"
gem "standard", "~> 1.0"
