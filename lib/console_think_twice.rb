# frozen_string_literal: true

require "active_record"
require "active_support/core_ext/string/inflections"

require_relative "console_think_twice/version"
require_relative "console_think_twice/configuration"
require_relative "console_think_twice/record_guard"
require_relative "console_think_twice/relation_guard"

# Confirmation prompts for destructive Active Record calls typed into a console.
#
#   >> User.first.destroy!
#   This will permanently destroy User #1 in production.
#   Cascades to: sessions, company_memberships, comments, api_keys.
#   Confirm? (y/N)
#
# Every guarded call takes `force: true` to skip the prompt. In a Rails app the railtie
# installs this on console boot only, so the web app, jobs and `rails runner` are untouched.
module ConsoleThinkTwice
  # Raised when a destructive call is declined, or when there is nobody to ask.
  Aborted = Class.new(StandardError)

  CASCADING_STRATEGIES = %i[destroy destroy_async delete_all].freeze
  SUPPRESSION_KEY = :console_think_twice_suppressed

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def install!
      return false unless configuration.enabled?

      unless @installed
        ActiveRecord::Base.prepend(RecordGuard)
        ActiveRecord::Relation.prepend(RelationGuard)
        ActiveRecord::Associations::CollectionProxy.prepend(RelationGuard)
        @installed = true
      end

      @active = true
      announce
      true
    end

    def disable!
      @active = false
    end

    def active?
      !!@active
    end

    # Confirms the call, then runs it with nested prompts suppressed so that a `dependent:`
    # cascade, or a relation destroying its records one by one, only ever asks once.
    def guard(target, action:, force:)
      return yield if !active? || suppressed?

      count = affected_count(target)
      return yield if count.zero?

      confirm!(target, action, count) unless force
      suppressed { yield }
    end

    private

    def confirm!(target, action, count)
      summary = summarize(target, action, count)
      unless configuration.interactive?
        raise Aborted, "#{summary} No terminal to confirm on — pass `force: true` to proceed."
      end

      output = configuration.output
      output.puts
      output.puts highlight(summary)
      cascades = cascading_associations(model_of(target))
      output.puts "Cascades to: #{cascades.join(", ")}." if cascades.any?
      output.print "Confirm? (y/N) "
      output.flush

      answer = configuration.input.gets.to_s.strip.downcase
      return if configuration.affirmative_answers.include?(answer)

      raise Aborted, "Aborted. Nothing was #{(action == :delete) ? "deleted" : "destroyed"}."
    end

    def summarize(target, action, count)
      verb = (action == :delete) ? "permanently delete, skipping callbacks," : "permanently destroy"

      subject = if target.is_a?(ActiveRecord::Base)
        "#{target.class.name} ##{target.id}"
      else
        model = model_of(target).name
        "#{count} #{(count == 1) ? model : model.pluralize}"
      end

      ["This will #{verb} #{subject}", configuration.label && " in #{configuration.label}", "."].compact.join
    end

    def affected_count(target)
      return target.persisted? ? 1 : 0 if target.is_a?(ActiveRecord::Base)

      target.size
    end

    def model_of(target)
      target.is_a?(ActiveRecord::Base) ? target.class : target.klass
    end

    def cascading_associations(model)
      model.reflect_on_all_associations
        .select { |reflection| CASCADING_STRATEGIES.include?(reflection.options[:dependent]) }
        .map(&:name)
    end

    def suppressed?
      Thread.current[SUPPRESSION_KEY]
    end

    def suppressed
      previous = Thread.current[SUPPRESSION_KEY]
      Thread.current[SUPPRESSION_KEY] = true
      yield
    ensure
      Thread.current[SUPPRESSION_KEY] = previous
    end

    def announce
      return unless configuration.interactive?

      configuration.output.puts highlight(
        "Think twice: destroy and delete calls ask for confirmation. Pass `force: true` to skip."
      )
    end

    def highlight(text)
      output = configuration.output
      (output.respond_to?(:tty?) && output.tty?) ? "\e[1;31m#{text}\e[0m" : text
    end
  end
end

require_relative "console_think_twice/railtie" if defined?(::Rails)
