module Gridauth
  # Lets a signed-in user set up, print, rotate and (optionally) disable
  # their grid card.
  class GridCardsController < ApplicationController
    before_action :set_user
    before_action :set_pending_card, only: %i[ show print activate discard ]

    def show
      @card = @user.grid_card
      @grid = new_card_grid
      @cells = @pending_card.issue_challenge! if @grid && !@pending_card.locked?
    end

    # Issues a new pending card. If the user already has an active card it
    # keeps working until the new one is activated (rotation).
    def create
      card, grid = @user.issue_grid_card!
      session[Gridauth::NEW_CARD_KEY] = { "id" => card.id, "values" => grid.to_compact }
      redirect_to gridauth_grid_card_path, notice: t("gridauth.grid_cards.issued")
    end

    def print
      if (@grid = new_card_grid)
        render layout: false
      else
        redirect_to gridauth_grid_card_path, alert: t("gridauth.grid_cards.unavailable")
      end
    end

    # Confirms the user has saved the new card by answering a challenge from
    # it, then makes it the active card and revokes the previous one.
    def activate
      return redirect_to(gridauth_grid_card_path, alert: t("gridauth.grid_cards.unavailable")) unless @pending_card
      return redirect_to(gridauth_grid_card_path, alert: t("gridauth.grid_cards.wrong_password")) unless password_confirmed?(@user)

      case @pending_card.verify_challenge(challenge_answers)
      when :success
        rotated = @user.grid_card_enabled?
        @pending_card.activate!
        session.delete(Gridauth::NEW_CARD_KEY)
        redirect_to gridauth_grid_card_path, notice: t(rotated ? "gridauth.grid_cards.rotated" : "gridauth.grid_cards.activated")
      when :locked
        redirect_to gridauth_grid_card_path, alert: t("gridauth.challenges.locked")
      else
        redirect_to gridauth_grid_card_path, alert: t("gridauth.challenges.invalid")
      end
    end

    def discard
      @pending_card&.destroy!
      session.delete(Gridauth::NEW_CARD_KEY)
      redirect_to gridauth_grid_card_path, notice: t("gridauth.grid_cards.discarded"), status: :see_other
    end

    def destroy
      if !Gridauth.config.allow_disable || Gridauth.config.enforce_enrollment
        redirect_to gridauth_grid_card_path, alert: t("gridauth.grid_cards.disable_not_allowed"), status: :see_other
      elsif !password_confirmed?(@user)
        redirect_to gridauth_grid_card_path, alert: t("gridauth.grid_cards.wrong_password"), status: :see_other
      else
        @user.revoke_grid_cards!
        session.delete(Gridauth::NEW_CARD_KEY)
        redirect_to gridauth_grid_card_path, notice: t("gridauth.grid_cards.disabled"), status: :see_other
      end
    end

    private
      def set_user
        @user = current_grid_card_user
      end

      def set_pending_card
        @pending_card = @user.pending_grid_card
      end

      # The plaintext of the pending card, available only in the browser
      # session that issued it.
      def new_card_grid
        stored = session[Gridauth::NEW_CARD_KEY]
        return unless @pending_card && stored.is_a?(Hash) && stored["id"] == @pending_card.id

        Grid.from_compact(stored["values"], rows: @pending_card.row_count, columns: @pending_card.column_count)
      end
  end
end
