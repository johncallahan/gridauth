Rails.application.routes.draw do
  gridauth_routes
  resource :session
  resources :passwords, param: :token
  root "home#index"
end
