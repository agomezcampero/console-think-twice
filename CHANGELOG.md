# Changelog

## [Unreleased]

## [0.1.0]

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

[Unreleased]: https://github.com/agomezcampero/console-think-twice/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/agomezcampero/console-think-twice/releases/tag/v0.1.0
