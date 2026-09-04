Rails.application.routes.draw do
  root "home#show"

  resource :welcome, only: :show

  resource :signup, only: %i[new create]
  namespace :signup do
    resource :profile, only: %i[new create]
    resource :welcome, only: :show
  end

  namespace :game_sessions do
    resource :solo, only: %i[new create]
  end

  resources :game_sessions, only: %i[new show] do
    scope module: :game_sessions do
      resource :character, only: %i[new create]
      resource :roll, only: :create
      resource :acknowledgement, only: :create
      resource :narration, only: :create

      resources :choices, only: [] do
        resource :selection, only: :create, module: :choices
      end

      resources :items, only: [] do
        resource :use, only: :create, module: :items
      end
    end
  end

  resource :session, only: %i[new create destroy]
  namespace :sessions do
    resource :code, only: %i[new create]
    resource :resend, only: :create
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
