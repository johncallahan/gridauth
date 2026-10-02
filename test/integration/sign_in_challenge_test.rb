require "test_helper"

class SignInChallengeTest < ActionDispatch::IntegrationTest
  setup { @user = users(:alice) }

  test "users without a grid card sign in with just their password" do
    sign_in_with_password(@user)

    assert_redirected_to root_url
    assert signed_in?
  end

  test "users with a grid card must answer the challenge before a session is created" do
    card, grid = create_active_card(@user)

    assert_no_difference -> { @user.sessions.count } do
      sign_in_with_password(@user)
    end
    assert_redirected_to new_gridauth_challenge_path
    assert_not signed_in?

    get root_path
    assert_redirected_to new_session_path

    get new_gridauth_challenge_path
    assert_response :success
    card.reload.challenge_cells.each do |cell|
      assert_select "input[name=?][maxlength=?]", "cells[#{cell}]", card.cell_length.to_s
      assert_select "td.gridauth-highlight", count: card.challenge_cells.size
    end
    assert_select "nav a[href=?]", root_path, text: "Home" # host layout route helpers work on engine pages

    assert_difference -> { @user.sessions.count }, 1 do
      post gridauth_challenge_path, params: { cells: answers_for(card, grid) }
    end
    assert_redirected_to root_url
    assert signed_in?
    assert_equal 1, card.reload.use_count

    follow_redirect!
    assert_response :success
  end

  test "returns to the originally requested page after the challenge" do
    card, grid = create_active_card(@user)

    get gridauth_grid_card_path
    assert_redirected_to new_session_path

    sign_in_fully(@user, card, grid)
    assert_redirected_to gridauth_grid_card_url
  end

  test "wrong answers are rejected and the same cells are asked again" do
    card, grid = create_active_card(@user)
    sign_in_with_password(@user)
    get new_gridauth_challenge_path
    cells = card.reload.challenge_cells

    post gridauth_challenge_path, params: { cells: wrong_answers_for(card, grid) }
    assert_redirected_to new_gridauth_challenge_path
    assert_equal "That doesn't match your grid card. Please try again.", flash[:alert]
    assert_not signed_in?

    sign_in_with_password(@user)
    get new_gridauth_challenge_path
    assert_equal cells, card.reload.challenge_cells
  end

  test "locks the card after repeated failures" do
    with_config(max_failed_attempts: 2) do
      card, grid = create_active_card(@user)
      sign_in_with_password(@user)
      get new_gridauth_challenge_path

      2.times { post gridauth_challenge_path, params: { cells: wrong_answers_for(card, grid) } }
      assert_match(/locked/, flash[:alert])

      post gridauth_challenge_path, params: { cells: answers_for(card, grid) }
      assert_not signed_in?

      get new_gridauth_challenge_path
      assert_select "p.gridauth-alert", /locked until/
      assert_select "input[name^=cells]", count: 0
    end
  end

  test "the pending sign-in expires" do
    card, grid = create_active_card(@user)
    sign_in_with_password(@user)
    get new_gridauth_challenge_path

    travel Gridauth.config.challenge_timeout + 1.second do
      post gridauth_challenge_path, params: { cells: answers_for(card, grid) }
      assert_redirected_to new_session_path
      assert_not signed_in?
    end
  end

  test "the challenge page requires a password sign-in first" do
    create_active_card(@user)

    get new_gridauth_challenge_path
    assert_redirected_to new_session_path
  end

  test "cancelling the challenge discards the pending sign-in" do
    create_active_card(@user)
    sign_in_with_password(@user)

    delete gridauth_challenge_path
    assert_redirected_to new_session_path

    get new_gridauth_challenge_path
    assert_redirected_to new_session_path
  end

  test "a revoked card no longer gates sign-in" do
    create_active_card(@user)
    sign_in_with_password(@user)
    @user.revoke_grid_cards!

    get new_gridauth_challenge_path
    assert_redirected_to new_session_path
    assert_not signed_in?
  end

  test "sends users to replace a card that is due for rotation" do
    with_config(rotate_after_uses: 1) do
      card, grid = create_active_card(@user)
      sign_in_fully(@user, card, grid)

      assert_redirected_to gridauth_grid_card_path
      assert signed_in?
    end
  end
end

class GridauthParameterFilterTest < ActiveSupport::TestCase
  test "grid card answers are filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("cells" => { "A1" => "7K" })["cells"]
  end
end
