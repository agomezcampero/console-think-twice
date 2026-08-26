# frozen_string_literal: true

require "active_record"
require "active_support/core_ext/string/inflections"

require_relative "console_think_twice/version"
require_relative "console_think_twice/configuration"
require_relative "console_think_twice/record_guard"
require_relative "console_think_twice/relation_guard"
require_relative "console_think_twice/collection_guard"

# Confirmation prompts for destructive Active Record calls typed into a console.
#
#   >> User.first.destroy!
#   This will permanently destroy User #1 in production.
#   Cascades to: sessions, company_memberships, comments, api_keys
#   Confirm? (y/N)
#
# Every guarded call takes `force: true` to skip the prompt. In a Rails app the railtie
# installs this on console boot only, so the web app, jobs and `rails runner` are untouched.
module ConsoleThinkTwice
  # Raised when a destructive call is declined, or when there is nobody to ask.
  Aborted = Class.new(StandardError)

  CASCADING_STRATEGIES = %i[destroy destroy_async delete_all].freeze
  SUPPRESSION_KEY = :console_think_twice_suppressed

  # Source files belonging to Rails itself. Matched on the path rather than resolved from
  # Gem.loaded_specs so that a vendored or git-checkout Rails is recognised too.
  RAILS_SOURCE = %r{/active_(?:record|support|model)/}

  # The Active Record internals that destroy a record as one step of a larger operation:
  # association bookkeeping, autosave, and nested attributes.
  RAILS_INTERNAL_WORK = %r{/active_record/(?:associations/|autosave_association\.rb|nested_attributes\.rb)}

  # This gem's own frames, skipped when looking for the caller of a guarded method.
  GEM_SOURCE = __dir__

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
        # CollectionProxy overrides destroy_all and delete_all rather than inheriting them,
        # so guarding Relation alone would miss every has_many collection.
        ActiveRecord::Relation.prepend(RelationGuard)
        ActiveRecord::Associations::CollectionProxy.prepend(RelationGuard)
        ActiveRecord::Associations::CollectionProxy.prepend(CollectionGuard)
        @installed = true
      end

      @active = true
      announce
      true
    end

    def disable!
      @active = false
    end

    def enable!
      @active = true
    end

    def active?
      !!@active && configuration.enabled?
    end

    # Confirms the call, then runs it with nested prompts suppressed so that a `dependent:`
    # cascade, or a relation destroying its records one by one, only ever asks once.
    #
    # `count` is passed when the caller already knows how many records are involved, which
    # saves a COUNT and is the only way to size a call like `books.destroy(a, b)` that names
    # its records rather than describing them.
    def guard(target, action:, force:, count: nil)
      return yield if !active? || suppressed?

      # Active Record's own work is confirmed by whatever the user typed to set it off, so it
      # runs suppressed rather than merely unguarded: `destroy!` re-enters as `destroy`, and
      # that second hop is dispatched from persistence.rb, where nothing marks it as internal.
      return suppressed { yield } if nested_in_active_record?(target)

      unless force
        count ||= affected_count(target)
        return yield if count.zero?

        confirm!(target, action, count)
      end

      suppressed { yield }
    end

    private

    # True when Active Record itself made this call as one step of an operation already under
    # way: a record being removed by `accepts_nested_attributes_for`, a `has_one` being
    # replaced, a collection destroying the records it was handed. Those run inside the
    # enclosing call's transaction, so prompting would hold that transaction — and its locks —
    # open until somebody answers, and would ask about a record the user never named.
    #
    # Both conditions are required, because neither separates the two cases alone. A destroy
    # typed inside `transaction { ... }`, or into a `--sandbox` console, has a transaction open
    # but is still the user's own call; and `Model.destroy_all` is dispatched from inside
    # Active Record, but only through the delegation in querying.rb rather than through the
    # association and autosave code that does this work.
    def nested_in_active_record?(target)
      return false unless open_transaction?(target)

      dispatch_chain.any? { |path| RAILS_INTERNAL_WORK.match?(path) }
    end

    # The frames Active Record itself put between the caller and us: everything above the first
    # frame that belongs to neither this gem nor Rails, which is the code that made the call.
    # An unrecognisable frame ends the chain, so anything we cannot read is treated as the
    # caller's own and asked about rather than skipped.
    def dispatch_chain
      frames = (caller_locations(1, 50) || []).map { |location| location.path.to_s }
      frames.drop_while { |path| path.start_with?(GEM_SOURCE) }
        .take_while { |path| RAILS_SOURCE.match?(path) }
    end

    def open_transaction?(target)
      model_of(target).connection.open_transactions > 0
    rescue
      false
    end

    def confirm!(target, action, count)
      summary = summarize(target, action, count)
      unless configuration.interactive?
        raise Aborted, "#{summary} No terminal to confirm on — pass `force: true` to proceed."
      end

      output = configuration.output
      output.puts
      output.puts highlight(summary)
      cascades = cascading_associations(model_of(target))
      output.puts "Cascades to: #{cascades.join(", ")}" if cascades.any?
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

      label = configuration.label
      where = (label && !label.to_s.empty?) ? " in #{label}" : ""
      "This will #{verb} #{subject}#{where}."
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

    # Thread-local rather than fiber-local (which is what Thread.current[] gives), so that a
    # confirmed call still counts as confirmed inside an Enumerator or any other fiber.
    def suppressed?
      Thread.current.thread_variable_get(SUPPRESSION_KEY)
    end

    def suppressed
      previous = Thread.current.thread_variable_get(SUPPRESSION_KEY)
      Thread.current.thread_variable_set(SUPPRESSION_KEY, true)
      yield
    ensure
      Thread.current.thread_variable_set(SUPPRESSION_KEY, previous)
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
