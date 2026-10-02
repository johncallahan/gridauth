require "test_helper"
require "generators/gridauth/install/install_generator"

class Gridauth::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests Gridauth::Generators::InstallGenerator
  destination File.expand_path("../../../tmp/generator_test", __dir__)

  setup do
    prepare_destination
    make_dirs %w[app/models app/controllers config]

    File.write(File.join(destination_root, "app/models/user.rb"), <<~RUBY)
      class User < ApplicationRecord
        has_secure_password
      end
    RUBY
    File.write(File.join(destination_root, "app/controllers/application_controller.rb"), <<~RUBY)
      class ApplicationController < ActionController::Base
        include Authentication
      end
    RUBY
    File.write(File.join(destination_root, "app/controllers/sessions_controller.rb"), <<~RUBY)
      class SessionsController < ApplicationController
        def create
          if user = User.authenticate_by(params.permit(:email_address, :password))
            start_new_session_for user
            redirect_to after_authentication_url
          else
            redirect_to new_session_path
          end
        end
      end
    RUBY
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
  end

  test "wires grid card authentication into a Rails 8 authentication app" do
    run_generator

    assert_file "config/initializers/gridauth.rb", /config.user_class = "User"/
    assert_migration "db/migrate/create_gridauth_grid_cards.rb", /create_table :gridauth_grid_cards/
    assert_file "app/models/user.rb", /has_grid_card/
    assert_file "app/controllers/application_controller.rb", /include Authentication\n  include Gridauth::Authentication\n/
    assert_file "app/controllers/sessions_controller.rb" do |content|
      assert_match(/start_grid_card_challenge_for user\n/, content)
      assert_no_match(/start_new_session_for/, content)
    end
    assert_file "config/routes.rb", /gridauth_routes/
  end

  private
    def make_dirs(dirs)
      dirs.each { |dir| FileUtils.mkdir_p(File.join(destination_root, dir)) }
    end
end
