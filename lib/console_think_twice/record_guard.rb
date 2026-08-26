# frozen_string_literal: true

module ConsoleThinkTwice
  module RecordGuard
    def destroy(force: false)
      ConsoleThinkTwice.guard(self, action: :destroy, force: force) { super() }
    end

    def destroy!(force: false)
      ConsoleThinkTwice.guard(self, action: :destroy, force: force) { super() }
    end

    def delete(force: false)
      ConsoleThinkTwice.guard(self, action: :delete, force: force) { super() }
    end
  end
end
