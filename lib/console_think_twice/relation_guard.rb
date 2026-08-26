# frozen_string_literal: true

module ConsoleThinkTwice
  module RelationGuard
    def destroy_all(force: false)
      ConsoleThinkTwice.guard(self, action: :destroy, force: force) { super() }
    end

    # CollectionProxy#delete_all takes an optional dependency strategy; Relation#delete_all takes none.
    def delete_all(*args, force: false)
      ConsoleThinkTwice.guard(self, action: :delete, force: force) { super(*args) }
    end
  end
end
