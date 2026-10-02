require "gridauth/version"
require "gridauth/configuration"
require "gridauth/grid"
require "gridauth/model"
require "gridauth/routing"
require "gridauth/authentication"
require "gridauth/engine"

# Grid card two-factor authentication for applications using the Rails 8
# authentication generator.
module Gridauth
  # Rails session key holding a login that passed the password check but has
  # not yet answered the grid card challenge.
  PENDING_LOGIN_KEY = :gridauth_pending_login

  # Rails session key holding the plaintext of a freshly issued card so it can
  # be displayed and printed until the user activates it.
  NEW_CARD_KEY = :gridauth_new_card

  class << self
    def table_name_prefix
      "gridauth_"
    end

    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def reset_config!
      @config = Configuration.new
    end

    def user_class
      config.user_class.to_s.constantize
    end
  end
end
