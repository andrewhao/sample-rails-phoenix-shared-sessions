Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  root to: 'pages#root'

  mount JasmineRails::Engine => '/specs' if defined?(JasmineRails)
end
