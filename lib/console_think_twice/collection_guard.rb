# frozen_string_literal: true

module ConsoleThinkTwice
  # Guards the collection methods that name their records, rather than describing them with a
  # scope. Prepended to CollectionProxy only: ActiveRecord::Relation has a `destroy` of its own
  # that takes an id and means something different.
  module CollectionGuard
    # `books.destroy(a, b)` destroys the records it is handed one at a time. Asking here rather
    # than once per record keeps it to a single prompt, and keeps the prompt outside the
    # transaction Active Record opens to do the work.
    def destroy(*records, force: false)
      ConsoleThinkTwice.guard(self, action: :destroy, force: force, count: records.size) do
        super(*records)
      end
    end
  end
end
