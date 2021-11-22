Rails.application.routes.draw do
  root :to => "statistics#index"
  get '/eth', to: 'statistics#eth'
  get '/other', to: 'statistics#other'

  resources :statistics
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
