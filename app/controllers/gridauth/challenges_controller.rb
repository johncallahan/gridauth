module Gridauth
  # The second step of signing in: after SessionsController has checked the
  # password, the user answers cells from their grid card here.
  class ChallengesController < ApplicationController
    allow_unauthenticated_access if respond_to?(:allow_unauthenticated_access)

    rate_limit to: 10, within: 3.minutes, only: :create,
      with: -> { redirect_to new_gridauth_challenge_path, alert: t("gridauth.challenges.rate_limited") }

    before_action :load_pending_login, except: :destroy

    def new
      @cells = @card.issue_challenge! unless @card.locked?
    end

    def create
      case @card.verify_challenge(challenge_answers)
      when :success
        complete_sign_in
      when :locked
        redirect_to new_gridauth_challenge_path, alert: t("gridauth.challenges.locked")
      else
        redirect_to new_gridauth_challenge_path, alert: t("gridauth.challenges.invalid")
      end
    end

    def destroy
      session.delete(Gridauth::PENDING_LOGIN_KEY)
      redirect_to sign_in_url, status: :see_other
    end

    private
      def load_pending_login
        pending = session[Gridauth::PENDING_LOGIN_KEY]

        unless pending.is_a?(Hash) && Time.zone.at(pending["started_at"].to_i) > Gridauth.config.challenge_timeout.ago
          return abandon_sign_in(pending ? t("gridauth.challenges.expired") : nil)
        end

        @user = Gridauth.user_class.find_by(id: pending["user_id"])
        @card = @user&.grid_card
        abandon_sign_in(t("gridauth.challenges.expired")) unless @card
      end

      def abandon_sign_in(message)
        session.delete(Gridauth::PENDING_LOGIN_KEY)
        redirect_to sign_in_url, alert: message
      end

      def complete_sign_in
        return_to = after_authentication_url
        reset_session
        start_new_session_for @user
        @card.record_use!

        if @card.rotation_due?
          redirect_to gridauth_grid_card_path, notice: t("gridauth.policy.rotation_required")
        else
          redirect_to return_to
        end
      end
  end
end
