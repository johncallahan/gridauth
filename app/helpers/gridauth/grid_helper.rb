module Gridauth
  module GridHelper
    # Accessible description of a cell key, e.g. "B3" => "column B, row 3".
    def gridauth_cell_description(cell)
      column, row = cell.to_s.match(/\A([A-Z])(\d+)\z/)&.captures
      t("gridauth.cell_description", column:, row:)
    end

    def gridauth_user_label(user)
      attribute = Gridauth.config.user_label_attribute
      user.public_send(attribute) if attribute && user.respond_to?(attribute)
    end

    def gridauth_styles
      render "gridauth/shared/styles"
    end
  end
end
