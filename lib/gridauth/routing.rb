module Gridauth
  # Draws the grid card routes into the application's route set, so the
  # engine's pages render inside the app's layout with all of its route
  # helpers available.
  #
  #   Rails.application.routes.draw do
  #     resource :session
  #     gridauth_routes
  #   end
  #
  # Route helpers: new_gridauth_challenge_path, gridauth_challenge_path,
  # gridauth_grid_card_path, print_gridauth_grid_card_path,
  # activate_gridauth_grid_card_path and discard_gridauth_grid_card_path.
  module Routing
    def gridauth_routes(path: "gridauth")
      scope path, module: "gridauth", as: "gridauth" do
        resource :challenge, only: %i[ new create destroy ]

        resource :grid_card, path: "card", only: %i[ show create destroy ] do
          get :print
          post :activate
          delete :discard
        end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.include Gridauth::Routing
