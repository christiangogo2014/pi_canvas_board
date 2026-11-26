Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  namespace :api do
    resources :boards, only: %i[index show update destroy] do
      member do
        patch :sort
      end
      resources :columns, only: %i[create update destroy] do
        member do
          patch :reorder
        end
      end
    end
    patch "boards/:board_id/sessions/:id/move", to: "sessions#move", as: :move_board_session
    get "boards/:board_id/sessions/:id/notes", to: "card_notes#index", as: :session_notes
    get "boards/:board_id/sessions/:id/conversation", to: "sessions#conversation", as: :session_conversation
    post "boards/:board_id/sessions/:id/notes", to: "card_notes#create", as: :create_session_note
    patch "notes/:id", to: "card_notes#update", as: :card_note
    delete "notes/:id", to: "card_notes#destroy"
    get "attachments/:id/download", to: "card_notes#download", as: :card_note_download
    post "rescan", to: "sessions#rescan"
  end

  # SPA fallback: the frontend is built into public/ by the Docker build.
  root "spa#index"
  get "*path", to: "spa#index", defaults: { format: :html }
end
