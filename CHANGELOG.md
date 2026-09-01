# Changelog

## [Unreleased]

### Added

- `config.ignored_classes` leaves the classes you name unguarded, for tables that are
  cleared as a matter of routine — `SolidCache::Entry`, say. Takes names or classes,
  covers subclasses, and compares names rather than resolving them, so a class that is not
  loaded, or not in this app at all, can be listed.

## [0.2.0] - 2026-08-26

### Fixed

- Active Record's own destroys no longer prompt. A record marked `_destroy` by
  `accepts_nested_attributes_for`, and the record a `has_one` assignment discards, were
  asked about as though they had been typed — and asked from inside the enclosing call's
  transaction, holding it and its locks open until somebody answered. Calls you type are
  still guarded, including inside `transaction { ... }` and in a `--sandbox` console.
- `collection.destroy(record, other)` asks once for the whole call rather than once per
  record, and asks before the transaction is opened rather than inside it.
- A blank `config.label` is left out of the prompt instead of printed. `false` rendered as
  `"... Author #1false."`, and there was no way to turn the label off under Rails, where an
  unset label falls back to `Rails.env`.
- `config.enabled` takes effect when it changes, rather than only at `install!` time.
- A forced call no longer counts the records it was told not to ask about, so
  `destroy_all(force: true)` on a large table skips a needless `SELECT COUNT(*)`.
- A confirmed call stays confirmed inside a fiber. Suppression used `Thread.current[]`,
  which is fiber-local, so a destroy reached through an Enumerator prompted again.

### Changed

- `collection.delete(record)` is no longer guarded. It was only ever caught in passing, by
  the guard on the record destroy underneath it, and what it means depends on the
  association: without `dependent: :destroy` it unlinks the record rather than destroying
  it, so the prompt could describe a permanent delete that was not one.

### Added

- `ConsoleThinkTwice.enable!`, the counterpart to `disable!`.
- CI runs the suite against every supported Active Record, not only the newest.

## [0.1.0] - 2026-08-26

Initial release.

- Confirmation prompts for `destroy`, `destroy!` and `delete` on a record, and for
  `destroy_all` and `delete_all` on a relation or `has_many` collection.
- `force: true` on any guarded call skips the prompt.
- A railtie arms the guard from the Rails `console` hook, leaving web requests, jobs and
  `rails runner` untouched.
- Nested prompts are suppressed for the duration of a confirmed call, so a
  `dependent: :destroy` cascade asks once rather than once per record.
- A declined call raises `ConsoleThinkTwice::Aborted`, stopping a loop on the first refusal.
- Non-interactive input refuses rather than assuming yes.
- Configurable via `ConsoleThinkTwice.configure`, or turned off with `CONSOLE_THINK_TWICE=0`.

[Unreleased]: https://github.com/agomezcampero/console-think-twice/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/agomezcampero/console-think-twice/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/agomezcampero/console-think-twice/releases/tag/v0.1.0
