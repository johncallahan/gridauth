require "test_helper"

class GridCardManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in_with_password(@user)
  end

  test "requires a signed-in user" do
    delete session_path
    get gridauth_grid_card_path
    assert_redirected_to new_session_path
  end

  test "enrolling: issue, view, print and activate a card" do
    get gridauth_grid_card_path
    assert_select "button", "Set up a grid card"

    post gridauth_grid_card_path
    assert_redirected_to gridauth_grid_card_path
    card = @user.pending_grid_card
    grid = new_card_grid(card)

    get gridauth_grid_card_path
    assert_response :success
    assert_select "table.gridauth-table td", text: grid["A1"]
    assert_select "input[name^=cells]", count: Gridauth.config.challenge_size

    get print_gridauth_grid_card_path
    assert_response :success
    assert_select "h1", "Grid card #{card.serial}"
    assert_select "td", text: grid["J5"]

    post activate_gridauth_grid_card_path, params: { cells: answers_for(card, grid), password: "password" }
    assert_redirected_to gridauth_grid_card_path
    assert card.reload.active?
    assert_nil session[Gridauth::NEW_CARD_KEY]

    get print_gridauth_grid_card_path
    assert_redirected_to gridauth_grid_card_path
  end

  test "activation requires the password and correct answers" do
    post gridauth_grid_card_path
    card = @user.pending_grid_card
    grid = new_card_grid(card)
    get gridauth_grid_card_path

    post activate_gridauth_grid_card_path, params: { cells: answers_for(card, grid), password: "wrong" }
    assert_equal "Your password was incorrect.", flash[:alert]
    assert card.reload.pending?

    post activate_gridauth_grid_card_path, params: { cells: wrong_answers_for(card, grid), password: "password" }
    assert card.reload.pending?
    assert_not @user.grid_card_enabled?
  end

  test "rotating: the old card works until the new one is activated" do
    old_card, old_grid = create_active_card(@user)

    post gridauth_grid_card_path
    new_card = @user.pending_grid_card
    new_grid = new_card_grid(new_card)
    assert_equal old_card, @user.grid_card

    get gridauth_grid_card_path
    post activate_gridauth_grid_card_path, params: { cells: answers_for(new_card, new_grid), password: "password" }
    assert_equal "Your new grid card is active. The previous card no longer works.", flash[:notice]
    assert old_card.reload.revoked?

    delete session_path
    sign_in_with_password(@user)
    get new_gridauth_challenge_path
    assert_select "p", /#{new_card.serial}/

    old_card_answers = new_card.reload.challenge_cells.to_h { |cell| [ cell, old_grid[cell] ] }
    post gridauth_challenge_path, params: { cells: old_card_answers } unless old_card_answers == answers_for(new_card, new_grid)
    assert_not signed_in?

    post gridauth_challenge_path, params: { cells: answers_for(new_card, new_grid) }
    assert signed_in?
  end

  test "the new card's plaintext is only shown in the session that issued it" do
    post gridauth_grid_card_path
    card = @user.pending_grid_card

    open_session do |other|
      other.post session_path, params: { email_address: @user.email_address, password: "password" }
      other.get gridauth_grid_card_path
      other.assert_select "h2", "New card pending"
      other.assert_select "table.gridauth-table", count: 0

      other.get print_gridauth_grid_card_path
      other.assert_redirected_to gridauth_grid_card_path
    end

    assert card.reload.pending?
  end

  test "discarding a pending card" do
    post gridauth_grid_card_path
    delete discard_gridauth_grid_card_path

    assert_nil @user.pending_grid_card
    assert_nil session[Gridauth::NEW_CARD_KEY]
  end

  test "disabling grid card authentication requires the password" do
    create_active_card(@user)

    delete gridauth_grid_card_path, params: { password: "wrong" }
    assert @user.grid_card_enabled?

    delete gridauth_grid_card_path, params: { password: "password" }
    assert_not @user.grid_card_enabled?
  end

  test "disabling can be turned off" do
    create_active_card(@user)

    with_config(allow_disable: false) do
      delete gridauth_grid_card_path, params: { password: "password" }
      assert @user.grid_card_enabled?
    end
  end

  test "enforced enrollment sends users without a card to set one up" do
    with_config(enforce_enrollment: true) do
      get root_path
      assert_redirected_to gridauth_grid_card_path

      get gridauth_grid_card_path
      assert_response :success

      delete session_path
      assert_redirected_to new_session_path

      sign_in_with_password(@user)
      assert_redirected_to gridauth_grid_card_path
    end
  end

  test "enforced rotation blocks the app until the card is replaced" do
    create_active_card(@user)

    with_config(enforce_rotation: true, rotation_period: 1.day) do
      get root_path
      assert_response :success

      travel 2.days do
        get root_path
        assert_redirected_to gridauth_grid_card_path

        post gridauth_grid_card_path
        card = @user.pending_grid_card
        grid = new_card_grid(card)
        get gridauth_grid_card_path
        post activate_gridauth_grid_card_path, params: { cells: answers_for(card, grid), password: "password" }

        get root_path
        assert_response :success
      end
    end
  end

  private
    def new_card_grid(card)
      stored = session[Gridauth::NEW_CARD_KEY]
      assert_equal card.id, stored["id"]
      Gridauth::Grid.from_compact(stored["values"], rows: card.row_count, columns: card.column_count)
    end
end
