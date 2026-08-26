# frozen_string_literal: true

require "rails/railtie"

module ConsoleThinkTwice
  class Railtie < ::Rails::Railtie
    console { ConsoleThinkTwice.install! }
  end
end
