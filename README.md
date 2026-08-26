# console_think_twice

[![CI](https://github.com/agomezcampero/console-think-twice/actions/workflows/ci.yml/badge.svg)](https://github.com/agomezcampero/console-think-twice/actions/workflows/ci.yml)

Confirm before you destroy. `console_think_twice` intercepts destructive Active Record
calls made from a console and asks first, so a stray `User.destroy_all` in production
costs you a keystroke instead of a database.

```
>> User.first.destroy!

This will permanently destroy User #1 in production.
Cascades to: sessions, comments
Confirm? (y/N) n
ConsoleThinkTwice::Aborted: Aborted. Nothing was destroyed.

>> User.destroy_all

This will permanently destroy 200 Users in production.
Cascades to: sessions, comments
Confirm? (y/N) y
=> [#<User id: 1, ...>, ...]

>> User.first.destroy!(force: true)
=> #<User id: 2, ...>
```

## Installation

```ruby
gem "console_think_twice"
```

Not on RubyGems yet — until it is, point at the repository:

```ruby
gem "console_think_twice", github: "agomezcampero/console-think-twice"
```

In a Rails app that is all — a railtie installs the guard from the `console` hook, which
runs for `rails console` only. Web requests, background jobs and `rails runner` are
untouched, and the gem never patches anything until a console actually boots.

Outside Rails, call `ConsoleThinkTwice.install!` once your models are loaded.

## What is guarded

| Call | Prompt |
| --- | --- |
| `record.destroy`, `record.destroy!` | `This will permanently destroy User #1.` |
| `record.delete` | `This will permanently delete, skipping callbacks, User #1.` |
| `Model.destroy_all`, `relation.destroy_all`, `company.users.destroy_all` | `This will permanently destroy 200 Users.` |
| `Model.delete_all`, `relation.delete_all` | `This will permanently delete, skipping callbacks, 200 Users.` |

`Model.destroy(id)`, `destroy_by` and `delete_by` route through those methods, so they are
covered too.

Anything other than `y`/`yes` raises `ConsoleThinkTwice::Aborted`, which also stops a
loop like `users.each(&:destroy!)` on the first refusal rather than asking 200 times.

Every guarded method takes `force: true` to skip the prompt.

### One prompt per call

A `dependent: :destroy` cascade destroys child records, and `destroy_all` destroys its
records one at a time — both would otherwise prompt again for every record. Nested prompts
are suppressed for the duration of a confirmed call, so you are asked exactly once.

### Nobody to ask

When the input stream is not a terminal — piped input, a script fed to `rails console` —
there is no one to answer, so the guard refuses the call instead of assuming yes. Pass
`force: true` for destructive calls that are meant to run unattended.

## Configuration

```ruby
ConsoleThinkTwice.configure do |config|
  config.enabled = Rails.env.production?      # default: true, unless CONSOLE_THINK_TWICE is 0/false/no/off
  config.label = "production (europe)"        # shown in the prompt; defaults to Rails.env
  config.affirmative_answers = %w[y yes si]   # default: %w[y yes]
  config.interactive = true                   # default: auto-detected from config.input.tty?
  config.input = $stdin
  config.output = $stdout
end
```

Set `CONSOLE_THINK_TWICE=0` in the environment to turn the guard off without touching
code. `ConsoleThinkTwice.disable!` turns it off for the rest of the current session.

## Development

```bash
bundle install
bundle exec rake        # specs and linter
bundle exec rspec
bundle exec standardrb
```

## License

MIT. See [LICENSE](LICENSE).
