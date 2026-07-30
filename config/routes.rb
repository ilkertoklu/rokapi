Rails.application.routes.draw do
  root "home#show"

  resource :welcome, only: :show

  resource :signup, only: %i[new create]
  namespace :signup do
    resource :profile, only: %i[new create]
    resource :welcome, only: :show
  end

  resource :session, only: %i[new create destroy]
  namespace :sessions do
    resource :code, only: %i[new create]
    resource :resend, only: :create
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
