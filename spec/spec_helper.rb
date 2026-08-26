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
  end
end

class Author < ActiveRecord::Base
  has_many :books, dependent: :destroy
end

class Book < ActiveRecord::Base
  belongs_to :author, optional: true
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
