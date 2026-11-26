class ApplicationController < ActionController::Base
  # JSON API consumed by the separated SPA frontend.
  skip_forgery_protection

  def render_json_error(message, status:)
    render json: { error: message }, status: status
  end
end
