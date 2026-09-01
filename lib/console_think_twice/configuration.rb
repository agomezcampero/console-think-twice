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

    # Classes the guard leaves alone. Bookkeeping tables that are cleared as a matter of
    # routine — `SolidCache::Entry`, say — are noise to be asked about, and being asked
    # about them teaches you to answer y without reading. Takes names or classes, and a
    # subclass of a listed class is ignored too.
    #
    # Names are compared rather than resolved, so a class can be listed before it is
    # autoloaded, or listed in an initializer shared by apps that do not all have it.
    def ignored_classes=(classes)
      @ignored_classes = Array(classes).map(&:to_s)
    end

    def ignored_classes
      @ignored_classes ||= []
    end

    def ignores?(model)
      return false if ignored_classes.empty?

      inheritance_chain(model).any? { |name| ignored_classes.include?(name) }
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

    # Shown in the prompt to make the stakes obvious, e.g. "in production". Defaults to the
    # Rails environment; assigning any value at all — nil and false included — wins over that,
    # so the label can be turned off as well as changed.
    def label
      return @label if defined?(@label)

      ::Rails.env.to_s if defined?(::Rails) && ::Rails.respond_to?(:env)
    end

    private

    # The model's own name and the names of the models it inherits from, so that ignoring a
    # class ignores its subclasses. Stops at Active Record itself, which every model shares.
    def inheritance_chain(model)
      Enumerator.produce(model, &:superclass)
        .take_while { |klass| klass && klass != ::ActiveRecord::Base }
        .map(&:name)
    end
  end
end
