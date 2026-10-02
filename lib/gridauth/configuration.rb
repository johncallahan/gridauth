module Gridauth
  class Configuration
    # Name of the model that represents an account (generated as `User` by
    # `bin/rails generate authentication`).
    attr_accessor :user_class

    # Controller the engine's controllers inherit from. It must include the
    # app's `Authentication` concern.
    attr_accessor :parent_controller

    # Route helper (on `main_app`) for the username and password form.
    attr_accessor :sign_in_route

    # Card layout: rows are numbered 1..rows, columns are lettered A..
    attr_accessor :rows, :columns

    # Number of characters printed in each cell and the characters used.
    attr_accessor :cell_length, :alphabet

    # When false, answers are upcased before comparison.
    attr_accessor :case_sensitive

    # Number of cells the user must answer on each challenge.
    attr_accessor :challenge_size

    # How long a user has, after entering a correct password, to answer the
    # grid card challenge before having to sign in again.
    attr_accessor :challenge_timeout

    # Consecutive wrong answers before the card is locked, and for how long.
    attr_accessor :max_failed_attempts, :lockout_period

    # A card is due for rotation once it is this old (nil to disable) ...
    attr_accessor :rotation_period
    # ... or once it has been used for this many sign-ins (nil to disable).
    attr_accessor :rotate_after_uses

    # Require every user to set up a grid card before using the app.
    attr_accessor :enforce_enrollment

    # Block the app until a card that is due for rotation has been replaced.
    attr_accessor :enforce_rotation

    # Require the account password to activate a new card or disable 2FA.
    attr_accessor :require_password_for_changes

    # Allow users to turn grid card authentication off themselves.
    attr_accessor :allow_disable

    # Attribute of the user printed on the card.
    attr_accessor :user_label_attribute

    # Controller paths that are never redirected by the enrollment/rotation
    # policy (sign out and password reset must keep working).
    attr_accessor :policy_exempt_controllers

    # Secret used to HMAC card cell values. Defaults to a key derived from
    # the application's secret_key_base. Rotating it invalidates all cards.
    attr_writer :secret_key

    def initialize
      @user_class = "User"
      @parent_controller = "ApplicationController"
      @sign_in_route = :new_session_path
      @rows = 5
      @columns = 10
      @cell_length = 2
      @alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
      @case_sensitive = false
      @challenge_size = 3
      @challenge_timeout = 5.minutes
      @max_failed_attempts = 5
      @lockout_period = 15.minutes
      @rotation_period = 180.days
      @rotate_after_uses = nil
      @enforce_enrollment = false
      @enforce_rotation = false
      @require_password_for_changes = true
      @allow_disable = true
      @user_label_attribute = :email_address
      @policy_exempt_controllers = %w[sessions passwords]
      @secret_key = nil
    end

    def secret_key
      @secret_key ||= Rails.application.key_generator.generate_key("gridauth/grid-card-cells", 32)
    end
  end
end
