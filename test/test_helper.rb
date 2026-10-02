# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
require "rails/test_help"

ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
ActiveSupport::TestCase.fixtures :all

module GridauthTestHelpers
  def with_config(**settings)
    previous = settings.keys.index_with { |key| Gridauth.config.public_send(key) }
    settings.each { |key, value| Gridauth.config.public_send("#{key}=", value) }
    yield
  ensure
    previous.each { |key, value| Gridauth.config.public_send("#{key}=", value) }
  end

  def create_active_card(user)
    card, grid = user.issue_grid_card!
    card.activate!
    [ card.reload, grid ]
  end

  def answers_for(card, grid)
    card.reload.challenge_cells.to_h { |cell| [ cell, grid[cell] ] }
  end

  def wrong_answers_for(card, grid)
    card.reload.challenge_cells.to_h { |cell| [ cell, grid[cell].reverse == grid[cell] ? "##" : grid[cell].reverse ] }
  end
end

class ActiveSupport::TestCase
  include GridauthTestHelpers
end

class ActionDispatch::IntegrationTest
  def sign_in_with_password(user, password: "password")
    post session_path, params: { email_address: user.email_address, password: }
  end

  def answer_challenge(card, grid)
    get new_gridauth_challenge_path
    post gridauth_challenge_path, params: { cells: answers_for(card, grid) }
  end

  def sign_in_fully(user, card, grid)
    sign_in_with_password(user)
    answer_challenge(card, grid)
  end

  def signed_in?
    cookies[:session_id].present?
  end
end
