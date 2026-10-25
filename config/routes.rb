Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "tickets/all", to: "tickets#index"
    get "tickets/open", to: "tickets#open"
    post "tickets/create", to: "tickets#create"

    constraints(id: /\d+/) do
      get "tickets/:id", to: "tickets#show"
      put "tickets/:id/update", to: "tickets#update"
      put "tickets/:id/finish", to: "tickets#finish"
    end
  end

  match "*unmatched", to: "application#route_not_found", via: :all
end
