# console_think_twice

[![Gem Version](https://badge.fury.io/rb/console_think_twice.svg)](https://rubygems.org/gems/console_think_twice)
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

Add it to your Gemfile:

```ruby
gem "console_think_twice"
```

Then `bundle install`. Or:

```bash
bundle add console_think_twice
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
| `company.users.destroy(user, other)` | `This will permanently destroy 2 Users.` |

`Model.destroy(id)`, `destroy_by` and `delete_by` route through those methods, so they are
covered too.

Anything other than `y`/`yes` raises `ConsoleThinkTwice::Aborted`, which also stops a
loop like `users.each(&:destroy!)` on the first refusal rather than asking 200 times.

Every guarded method takes `force: true` to skip the prompt.

### One prompt per call

A `dependent: :destroy` cascade destroys child records, and `destroy_all` destroys its
records one at a time — both would otherwise prompt again for every record. Nested prompts
are suppressed for the duration of a confirmed call, so you are asked exactly once.

### What is not guarded

`update_all`, `upsert_all` and anything run through `connection.execute` are untouched, as is
`collection.delete(record)` — which unlinks the record rather than destroying it, unless the
association says `dependent: :destroy`.

Classes listed in `config.ignored_classes` are not guarded either — see below.

Active Record also destroys records itself, as one step of a call that is about something
else: a record marked `_destroy` by `accepts_nested_attributes_for`, or the old record a
`has_one` assignment discards. Those do not prompt. They are already covered by whatever you
typed to set them off, and they run inside that call's transaction — stopping to ask there
would hold the transaction, and its locks, open until somebody answered. A destroy you type
yourself is always asked about, including inside `transaction { ... }` and in a
`rails console --sandbox`.

### Nobody to ask

When the input stream is not a terminal — piped input, a script fed to `rails console` —
there is no one to answer, so the guard refuses the call instead of assuming yes. Pass
`force: true` for destructive calls that are meant to run unattended.

## Configuration

```ruby
ConsoleThinkTwice.configure do |config|
  config.enabled = Rails.env.production?      # default: true, unless CONSOLE_THINK_TWICE is 0/false/no/off
  config.label = "production (europe)"        # shown in the prompt; defaults to Rails.env,
                                              # set nil or false to leave it out
  config.ignored_classes = %w[SolidCache::Entry]  # left unguarded; default: none
  config.affirmative_answers = %w[y yes si]   # default: %w[y yes]
  config.interactive = true                   # default: auto-detected from config.input.tty?
  config.input = $stdin
  config.output = $stdout
end
```

### Classes to leave alone

Some tables are cleared as a matter of routine — job records, cache entries, whatever your
app treats as scratch. Being asked about those is noise, and noise teaches you to answer `y`
without reading. List them and the guard stays out of the way:

```ruby
config.ignored_classes = %w[SolidCache::Entry SolidQueue::Job]
```

Classes work as well as names, and a subclass of a listed class is ignored too. Names are
compared rather than resolved, so listing a class that this app does not have, or has not
autoloaded yet, is fine.

Set `CONSOLE_THINK_TWICE=0` in the environment to turn the guard off without touching
code. `ConsoleThinkTwice.disable!` turns it off for the rest of the current session and
`ConsoleThinkTwice.enable!` turns it back on; setting `config.enabled` takes effect straight
away too, without reinstalling.

## Development

```bash
bundle install
bundle exec rake        # specs and linter
bundle exec rspec
bundle exec standardrb
```

The guard reads Active Record's own call stack to tell your calls from its, so the suite is
run against every supported Active Record, not just the newest. Delete `Gemfile.lock`, then:

```bash
ACTIVERECORD_VERSION=7.0 bundle install && ACTIVERECORD_VERSION=7.0 bundle exec rspec
```

## License

MIT. See [LICENSE](LICENSE).
