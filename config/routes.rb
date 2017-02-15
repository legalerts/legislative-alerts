Rails.application.routes.draw do
  devise_for :users, :controllers => { omniauth_callbacks: 'omniauth_callbacks', registrations: 'registrations',  }
  get '/splash' => 'splash#index'
  root 'splash#index'

  resources :alerts

  post '/alerts/:id/send' => 'alerts#send_mail', as: :send_alert

  get '/search' => 'search#index'
  get '/search/:id' => 'search#show'

  post '/bills/:id/follow' => 'bills#follow'
  post '/bills/:id/unfollow' => 'bills#unfollow'

end
