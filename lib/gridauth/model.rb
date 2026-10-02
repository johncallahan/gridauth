module Gridauth
  # Adds the `has_grid_card` macro to Active Record models.
  #
  #   class User < ApplicationRecord
  #     has_secure_password
  #     has_many :sessions, dependent: :destroy
  #     has_grid_card
  #   end
  module Model
    def has_grid_card
      has_many :grid_cards, class_name: "Gridauth::GridCard", foreign_key: :user_id,
        inverse_of: :user, dependent: :delete_all

      include InstanceMethods
    end

    module InstanceMethods
      # The card currently used to sign in, if any.
      def grid_card
        grid_cards.active.order(activated_at: :desc).first
      end

      # A card that has been issued but not yet confirmed by the user.
      def pending_grid_card
        grid_cards.pending.order(created_at: :desc).first
      end

      def grid_card_enabled?
        grid_cards.active.exists?
      end

      # Issues a new pending card (replacing any other pending card) and
      # returns `[card, grid]`, where `grid` is the only copy of the plaintext.
      # The current card, if any, keeps working until the new one is activated.
      def issue_grid_card!
        Gridauth::GridCard.issue_for!(self)
      end

      # Revokes every card, e.g. when an administrator resets a lost card.
      def revoke_grid_cards!
        transaction do
          grid_cards.pending.delete_all
          grid_cards.active.find_each(&:revoke!)
        end
      end
    end
  end
end
