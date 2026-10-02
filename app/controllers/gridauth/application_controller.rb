module Gridauth
  class ApplicationController < Gridauth.config.parent_controller.to_s.constantize
    helper Gridauth::GridHelper

    skip_before_action :enforce_grid_card_policy, raise: false

    private
      def current_grid_card_user
        Current.session&.user
      end

      def sign_in_url
        public_send(Gridauth.config.sign_in_route)
      end

      # Hash of cell => answer submitted by the challenge form fields.
      def challenge_answers
        params.permit(cells: {}).fetch(:cells, {}).to_h
      end

      def password_confirmed?(user)
        return true unless Gridauth.config.require_password_for_changes

        params[:password].present? && user.authenticate(params[:password]).present?
      end
  end
end
