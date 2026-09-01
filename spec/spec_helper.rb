# frozen_string_literal: true

require "active_record"
require "console_think_twice"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :authors, force: true do |t|
    t.string :name
  end

  create_table :books, force: true do |t|
    t.integer :author_id
    t.string :title
    t.string :type
  end

  create_table :publishers, force: true do |t|
    t.string :name
  end

  create_table :logos, force: true do |t|
    t.integer :publisher_id
    t.string :url
  end
end

class Author < ActiveRecord::Base
  has_many :books, dependent: :destroy
  accepts_nested_attributes_for :books, allow_destroy: true
end

class Book < ActiveRecord::Base
  belongs_to :author, optional: true
end

# Single-table inheritance, so that ignoring a class can be shown to cover what inherits it.
class Comic < Book
end

# Kept apart from Author so that the cascade listing there stays about books alone.
class Publisher < ActiveRecord::Base
  has_one :logo, dependent: :destroy
end

class Logo < ActiveRecord::Base
  belongs_to :publisher, optional: true
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
