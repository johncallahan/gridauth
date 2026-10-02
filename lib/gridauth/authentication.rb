module Gridauth
  # Include in ApplicationController after the Rails `Authentication` concern:
  #
  #   class ApplicationController < ActionController::Base
  #     include Authentication
  #     include Gridauth::Authentication
  #   end
  #
  # and replace `start_new_session_for user` + `redirect_to after_authentication_url`
  # in SessionsController#create with `start_grid_card_challenge_for user`.
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :enforce_grid_card_policy
      helper_method :grid_card_challenge_pending?
    end

    class_methods do
      # Opts controllers or actions out of the enrollment/rotation policy.
      def skip_grid_card_policy(**options)
        skip_before_action :enforce_grid_card_policy, **options
      end
    end

    private
      # Called once the user's password has been verified. Users with an
      # active grid card are sent to the challenge; no Session is created until
      # they answer it. Users without a card are signed in directly.
      def start_grid_card_challenge_for(user)
        if user.respond_to?(:grid_card_enabled?) && user.grid_card_enabled?
          return_to = session[:return_to_after_authenticating]
          reset_session
          session[:return_to_after_authenticating] = return_to if return_to
          session[Gridauth::PENDING_LOGIN_KEY] = { "user_id" => user.id, "started_at" => Time.current.to_i }
          redirect_to new_gridauth_challenge_path
        else
          start_new_session_for user
          if Gridauth.config.enforce_enrollment
            redirect_to gridauth_grid_card_path, notice: I18n.t("gridauth.policy.enrollment_required")
          else
            redirect_to after_authentication_url
          end
        end
      end

      def grid_card_challenge_pending?
        session[Gridauth::PENDING_LOGIN_KEY].present?
      end

      def enforce_grid_card_policy
        return if Gridauth.config.policy_exempt_controllers.include?(controller_path)
        return unless (user = grid_card_policy_user)

        if Gridauth.config.enforce_enrollment && !user.grid_card_enabled?
          grid_card_policy_redirect I18n.t("gridauth.policy.enrollment_required")
        elsif Gridauth.config.enforce_rotation && user.grid_card&.rotation_due?
          grid_card_policy_redirect I18n.t("gridauth.policy.rotation_required")
        end
      end

      def grid_card_policy_user
        session = respond_to?(:resume_session, true) ? resume_session : Current.session
        user = session&.user
        user if user.respond_to?(:grid_card_enabled?)
      end

      def grid_card_policy_redirect(message)
        if request.format.html?
          redirect_to gridauth_grid_card_path, alert: message
        else
          head :forbidden
        end
      end
  end
end
