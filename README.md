# Gridauth

Grid card two-factor authentication for Rails 8+ applications that use the
built-in authentication generator (`bin/rails generate authentication`). It
does not use Devise.

A grid card is a small table of random characters, with lettered columns and
numbered rows, that the user prints or saves:

```
     A   B   C   D   E   F   G   H   I   J
 1   7K  QF  M3  ...
 2   ...
```

After the usual email and password form, the user is asked for the characters
in a few cells, for example **B3**, **F1** and **J4**. No session is created
until those answers are correct.

## Features

- **One card per user**, generated with `SecureRandom`. The database stores
  only per-cell HMAC-SHA256 digests, so the card can't be read back from it.
- **Enrollment**: the user issues a card, views or prints it, and activates it
  by answering a challenge from the new card. This proves they saved it.
- **Rotation**: issuing a new card leaves the current one working until the
  new one is activated. Then the old card is revoked. Cards can be due for
  rotation by age (`rotation_period`), by number of sign-ins
  (`rotate_after_uses`), or both. Rotation can be required (`enforce_rotation`).
- **Sign-in challenge** after the password step, with:
  - challenge cells that stay fixed until answered correctly, so repeated
    sign-ins can't be used to "shop" for cells an attacker knows
  - constant-time comparison of every cell
  - a lockout after repeated failures, plus Rails `rate_limit`
  - a time limit for the second step
  - `reset_session` on both steps to prevent session fixation
- **Optional enforcement**: every user can be required to enroll
  (`enforce_enrollment`).
- **Generators**: the install generator wires everything up. The views
  generator copies the views into your app so you can customize them.
- **I18n**: every message is in `config/locales/en.yml`.

## Requirements

- Rails 8.0 or later
- Ruby 3.2 or later
- An app that already ran `bin/rails generate authentication` (`User`,
  `Session`, `Current` and the `Authentication` concern)

## Installation

```ruby
# Gemfile
gem "gridauth"
```

```sh
bundle install
bin/rails generate gridauth:install
bin/rails db:migrate
```

The install generator:

1. creates `config/initializers/gridauth.rb`
2. creates the `gridauth_grid_cards` migration
3. adds `has_grid_card` to `app/models/user.rb`
4. adds `include Gridauth::Authentication` to `ApplicationController`, after
   `include Authentication`
5. changes `SessionsController#create` from

   ```ruby
   start_new_session_for user
   redirect_to after_authentication_url
   ```

   to

   ```ruby
   start_grid_card_challenge_for user
   ```

6. adds `gridauth_routes` to `config/routes.rb`

If your `SessionsController` has been customized, the generator prints a
message and you make step 5 by hand. Users without an active card still sign
in with just their password.

Then give signed-in users a link to their card settings:

```erb
<%= link_to "Two-factor authentication", gridauth_grid_card_path %>
```

## Routes

`gridauth_routes` draws the routes straight into your app's route set (like
`devise_for`), so the pages render in your layout and your route helpers work
there. To use a different URL prefix, call `gridauth_routes path: "two-factor"`.

| Helper | Request | Purpose |
| --- | --- | --- |
| `new_gridauth_challenge_path` | `GET /gridauth/challenge/new` | Challenge form shown after the password step |
| `gridauth_challenge_path` | `POST /gridauth/challenge` | Check the answers and create the session |
| `gridauth_challenge_path` | `DELETE /gridauth/challenge` | Cancel the sign-in |
| `gridauth_grid_card_path` | `GET /gridauth/card` | Card status, enrollment and rotation |
| `gridauth_grid_card_path` | `POST /gridauth/card` | Issue a new pending card |
| `print_gridauth_grid_card_path` | `GET /gridauth/card/print` | Printable view of the pending card |
| `activate_gridauth_grid_card_path` | `POST /gridauth/card/activate` | Activate the pending card |
| `discard_gridauth_grid_card_path` | `DELETE /gridauth/card/discard` | Discard the pending card |
| `gridauth_grid_card_path` | `DELETE /gridauth/card` | Turn grid card authentication off |

## How it works

### Sign-in

1. `SessionsController#create` checks the password, then calls
   `start_grid_card_challenge_for(user)`.
2. If the user has an active card, Gridauth resets the Rails session and keeps
   a short-lived "pending sign-in" (the user id and a timestamp) in it. It
   then redirects to the challenge. The user is **not** signed in yet: no
   `Session` record, no `session_id` cookie.
3. The challenge page shows an empty grid with the requested cells
   highlighted, plus one input per cell.
4. If the answers are correct, Gridauth resets the session again, calls your
   app's `start_new_session_for`, and redirects to `after_authentication_url`.
   That is the page the user first asked for, or `root_url`. If the card is
   due for rotation, the user goes to the card page instead.

### Enrollment and rotation

1. On `/gridauth/card` the user clicks **Set up a grid card** (or **Replace
   grid card**). A *pending* card is created. Its plaintext is kept only in
   the encrypted session cookie of the browser that issued it, so the user can
   view and print it.
2. The user activates it by entering the requested cells from the new card,
   plus their current password (`require_password_for_changes`).
3. Activation revokes any previous active card and removes the plaintext from
   the session. After that the card can't be shown again. A lost card is
   replaced by rotating, or reset by an administrator.

## Configuration

`config/initializers/gridauth.rb`:

```ruby
Gridauth.configure do |config|
  config.user_class = "User"
  config.parent_controller = "ApplicationController"
  config.sign_in_route = :new_session_path

  config.rows = 5                    # rows 1..5
  config.columns = 10                # columns A..J (max 26)
  config.cell_length = 2             # characters per cell
  config.alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  config.case_sensitive = false

  config.challenge_size = 3          # cells per challenge
  config.challenge_timeout = 5.minutes

  config.max_failed_attempts = 5
  config.lockout_period = 15.minutes

  config.rotation_period = 180.days  # nil to disable
  config.rotate_after_uses = nil     # e.g. 100

  config.enforce_enrollment = false
  config.enforce_rotation = false
  config.policy_exempt_controllers = %w[sessions passwords]

  config.require_password_for_changes = true
  config.allow_disable = true
  config.user_label_attribute = :email_address

  # config.secret_key = Rails.application.credentials.dig(:gridauth, :secret_key)
end
```

With the defaults, each cell has 32² = 1,024 possible values, so guessing a
3-cell challenge has about a 1 in 10⁹ chance. Lockout and rate limiting cap
how many guesses can be made.

### Enforcement

With `enforce_enrollment` or `enforce_rotation` turned on,
`Gridauth::Authentication` adds a `before_action`. For a signed-in user who
needs to act, it redirects HTML requests to the card page and answers other
requests with `403 Forbidden`. To exempt more controllers, add them to
`policy_exempt_controllers` or call this in the controller:

```ruby
skip_grid_card_policy only: :show
```

## Model API

```ruby
user.grid_card            # active Gridauth::GridCard, or nil
user.pending_grid_card    # issued but not yet activated
user.grid_card_enabled?
card, grid = user.issue_grid_card!  # grid is the only plaintext copy
user.revoke_grid_cards!   # e.g. after the user lost their card

card.issue_challenge!     # => ["B3", "F1", "J4"]
card.verify_challenge("B3" => "7K", "F1" => "QF", "J4" => "M3")  # => :success, :invalid or :locked
card.rotation_due?
card.rotation_due_at
card.activate!
card.revoke!
```

You can use `issue_grid_card!` to issue cards from your own code, for example
to mail a printed card. Render `grid` with the
`gridauth/shared/grid` partial.

## Administration

```sh
bin/rails "gridauth:revoke[user@example.com]"   # lost card: back to password-only sign-in
bin/rails gridauth:due                           # list cards due for rotation
```

## Customizing views

```sh
bin/rails generate gridauth:views
```

This copies the templates to `app/views/gridauth`. The pages render in your
application layout. Their small amount of CSS is scoped under `.gridauth` and
uses your Content Security Policy nonce, if you have one configured.

## Security notes

- Cell digests are HMAC-SHA256 with a per-card salt. The key is derived from
  `secret_key_base`, or set with `config.secret_key`. **Changing that key
  invalidates every issued card.**
- A grid card is a "something you have" factor that can be photographed or
  copied. Rotate cards regularly and keep `challenge_size` at 3 or more.
- Anyone who knows a user's password can trigger the lockout, which locks
  that user out temporarily. Tune `max_failed_attempts` and `lockout_period`
  to balance this against brute-force protection.
- The `cells` parameter, which holds challenge answers, is added to
  `filter_parameters`, so answers never reach the logs.
- The plaintext of a pending card lives in the Rails session until
  activation. With the default cookie store, that cookie is encrypted.

## Development

```sh
bundle install
bin/rails test
bin/rubocop
```

`test/dummy` is a Rails app built with `bin/rails generate authentication` and
`bin/rails generate gridauth:install`.

## License

MIT
