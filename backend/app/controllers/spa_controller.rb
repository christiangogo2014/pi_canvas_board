# Serves the built frontend SPA (public/index.html) for any non-API path,
# enabling client-side routing.
class SpaController < ApplicationController
  def index
    index_html = Rails.public_path.join("index.html")
    if index_html.exist?
      render file: index_html, layout: false, content_type: "text/html"
    else
      render plain: "Frontend not built. Run the frontend build first.", status: :not_found
    end
  end
end
