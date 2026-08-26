# frozen_string_literal: true

module ConsoleThinkTwice
  class Configuration
    DISABLING_ENV_VALUES = %w[0 false no off].freeze

    attr_writer :enabled, :input, :interactive, :label, :output

    # Answers accepted as a confirmation; anything else aborts.
    attr_accessor :affirmative_answers

    def initialize
      @affirmative_answers = %w[y yes]
    end

    def input
      @input || $stdin
    end

    def output
      @output || $stdout
    end

    def enabled?
      return @enabled unless @enabled.nil?

      !DISABLING_ENV_VALUES.include?(ENV["CONSOLE_THINK_TWICE"].to_s.strip.downcase)
    end

    # Whether there is a human on the other end who can answer the prompt. Auto-detected from
    # the input stream unless set, so piped input aborts instead of destroying unattended.
    def interactive?
      return @interactive unless @interactive.nil?

      input.respond_to?(:tty?) && input.tty?
    end

    # Shown in the prompt to make the stakes obvious, e.g. "in production".
    def label
      return @label unless @label.nil?

      ::Rails.env.to_s if defined?(::Rails) && ::Rails.respond_to?(:env)
    end
  end
end
