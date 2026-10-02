require "rails/generators"
require "rails/generators/active_record"

module Gridauth
  module Generators
    # Wires grid card 2FA into an app that uses `bin/rails generate authentication`.
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :user_class, type: :string, default: "User", desc: "Model that signs in"
      class_option :path, type: :string, default: "gridauth", desc: "URL path prefix for the grid card pages"

      def create_initializer
        template "initializer.rb", "config/initializers/gridauth.rb"
      end

      def create_grid_cards_migration
        migration_template "create_gridauth_grid_cards.rb", "db/migrate/create_gridauth_grid_cards.rb"
      end

      def add_to_user_model
        path = File.join("app/models", "#{options[:user_class].underscore}.rb")
        if File.exist?(File.join(destination_root, path))
          inject_into_class path, options[:user_class].demodulize, "  has_grid_card\n"
        else
          say_status :skip, "#{path} not found; add `has_grid_card` to your user model", :yellow
        end
      end

      def add_to_application_controller
        path = "app/controllers/application_controller.rb"
        content = File.read(File.join(destination_root, path))
        return if content.include?("Gridauth::Authentication")

        if content.match?(/^\s*include Authentication\n/)
          inject_into_file path, "  include Gridauth::Authentication\n", after: /^\s*include Authentication\n/
        else
          say_status :skip, "Authentication concern not found in #{path}. Run `bin/rails generate authentication` first", :red
        end
      end

      SIGN_IN_PATTERN = /start_new_session_for(\(| )user\)?\n\s*redirect_to after_authentication_url/

      def update_sessions_controller
        path = "app/controllers/sessions_controller.rb"
        full_path = File.join(destination_root, path)
        content = File.exist?(full_path) ? File.read(full_path) : ""

        if content.match?(SIGN_IN_PATTERN)
          gsub_file path, SIGN_IN_PATTERN, "start_grid_card_challenge_for user"
        elsif !content.include?("start_grid_card_challenge_for")
          say_status :manual, "In SessionsController#create, replace `start_new_session_for user` and " \
            "`redirect_to after_authentication_url` with `start_grid_card_challenge_for user`", :yellow
        end
      end

      def add_routes
        route options[:path] == "gridauth" ? "gridauth_routes" : %(gridauth_routes path: "#{options[:path]}")
      end

      def show_next_steps
        say <<~MSG

          Grid card 2FA installed. Next:

            1. bin/rails db:migrate
            2. Link signed-in users to the card page: gridauth_grid_card_path
            3. Review config/initializers/gridauth.rb

        MSG
      end

      private
        def users_table
          options[:user_class].tableize.tr("/", "_")
        end

        def primary_key_type
          type = Rails.application&.config&.generators&.options&.dig(:active_record, :primary_key_type)
          type ? ", type: :#{type}" : ""
        end
    end
  end
end
