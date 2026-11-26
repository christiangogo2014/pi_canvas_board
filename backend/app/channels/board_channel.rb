# Subscribed by the SPA: streams refresh notifications for one project's
# board. Frontend subscribes with the raw project dir, e.g.
# "--Users-chr-conversa--"; broadcasts target "board:<dir>".
class BoardChannel < ApplicationCable::Channel
  def subscribed
    stream_from("board:#{params[:project_dir]}")
  end
end
