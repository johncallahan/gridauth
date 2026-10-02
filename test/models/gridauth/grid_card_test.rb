require "test_helper"

class Gridauth::GridCardTest < ActiveSupport::TestCase
  setup { @user = users(:alice) }

  test "issuing a card stores digests, not plaintext" do
    card, grid = @user.issue_grid_card!

    assert card.pending?
    assert_match(/\A[A-Z2-9]{4}-[A-Z2-9]{4}\z/, card.serial)
    assert_equal grid.cell_keys.sort, card.cell_digests.keys.sort
    assert card.cell_digests.values.all? { |digest| digest.match?(/\A\h{64}\z/) }
  end

  test "issuing a card replaces other pending cards but keeps the active one" do
    active, = create_active_card(@user)
    first_pending, = @user.issue_grid_card!
    second_pending, = @user.issue_grid_card!

    assert_not Gridauth::GridCard.exists?(first_pending.id)
    assert_equal second_pending, @user.pending_grid_card
    assert_equal active, @user.grid_card
  end

  test "a challenge stays the same until answered correctly" do
    card, grid = create_active_card(@user)
    cells = card.issue_challenge!

    assert_equal Gridauth.config.challenge_size, cells.size
    assert_equal cells, card.issue_challenge!

    assert_equal :invalid, card.verify_challenge(wrong_answers_for(card, grid))
    assert_equal cells, card.reload.issue_challenge!

    assert_equal :success, card.verify_challenge(answers_for(card, grid))
    assert_empty card.reload.challenge_cells
  end

  test "answers are normalized for case and whitespace" do
    card, grid = create_active_card(@user)
    card.issue_challenge!
    answers = answers_for(card, grid).to_h { |cell, value| [ cell.downcase, " #{value.downcase} " ] }

    assert_equal :success, card.verify_challenge(answers)
  end

  test "partially correct and missing answers fail" do
    card, grid = create_active_card(@user)
    card.issue_challenge!
    answers = answers_for(card, grid)

    assert_equal :invalid, card.verify_challenge(answers.merge(answers.keys.first => "!!"))
    assert_equal :invalid, card.verify_challenge(answers.except(answers.keys.last))
    assert_equal :invalid, card.verify_challenge(nil)
  end

  test "locks after too many failures, then unlocks after the lockout period" do
    with_config(max_failed_attempts: 3, lockout_period: 10.minutes) do
      card, grid = create_active_card(@user)
      card.issue_challenge!

      2.times { assert_equal :invalid, card.verify_challenge(wrong_answers_for(card, grid)) }
      assert_equal :locked, card.verify_challenge(wrong_answers_for(card, grid))
      assert card.reload.locked?
      assert_equal :locked, card.verify_challenge(answers_for(card, grid))

      travel 11.minutes do
        assert_not card.reload.locked?
        assert_equal :success, card.verify_challenge(answers_for(card, grid))
      end
    end
  end

  test "activating a new card revokes the old one" do
    old_card, = create_active_card(@user)
    new_card, = @user.issue_grid_card!
    new_card.activate!

    assert old_card.reload.revoked?
    assert_not_nil old_card.revoked_at
    assert_equal new_card, @user.grid_card
  end

  test "rotation is due by age or by number of uses" do
    card, = create_active_card(@user)
    assert_not card.rotation_due?

    with_config(rotation_period: 30.days) do
      travel(31.days) { assert card.rotation_due? }
    end

    with_config(rotation_period: nil, rotate_after_uses: 2) do
      2.times { card.record_use! }
      assert card.rotation_due?
    end
  end

  test "digests depend on the secret key" do
    card, grid = create_active_card(@user)
    card.issue_challenge!

    with_config(secret_key: "a different secret") do
      assert_equal :invalid, card.verify_challenge(answers_for(card, grid))
    end
  end

  test "revoke_grid_cards! disables grid card sign-in" do
    create_active_card(@user)
    @user.issue_grid_card!
    @user.revoke_grid_cards!

    assert_not @user.grid_card_enabled?
    assert_nil @user.pending_grid_card
  end
end
