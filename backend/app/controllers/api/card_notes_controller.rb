module Api
  # Card timeline: description (one per session), comments, attachments.
  # GET    .../sessions/:pi_id/notes        → timeline
  # POST   .../sessions/:pi_id/notes        → add note (JSON or multipart with file)
  # PATCH  /api/notes/:id                   → edit body
  # DELETE /api/notes/:id                   → remove note (attachments lose their file)
  class CardNotesController < ApplicationController
    before_action :set_session, only: %i[index create]

    # GET → session info + notes timeline
    def index
      render json: {
        session: session_json(@session),
        notes: @session.card_notes.timeline.map { |n| note_json(n) }
      }
    end

    def create
      note = if params[:file].present?
               filename = AttachmentStore.save(@session.pi_id, params[:file])
               @session.card_notes.create!(kind: "attachment", attachment_filename: filename)
             elsif params[:kind] == "description"
               @session.card_notes.find_or_initialize_by(kind: "description")
                                  .tap { |n| n.update!(body: params[:body]) }
             else
               @session.card_notes.create!(kind: params[:kind] || "comment", body: params[:body])
             end
      render json: note_json(note), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.message, status: :unprocessable_entity)
    end

    def update
      note = CardNote.find(params[:id])
      note.update!(body: params[:body])
      render json: note_json(note)
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.message, status: :unprocessable_entity)
    end

    def destroy
      note = CardNote.find(params[:id])
      AttachmentStore.delete(note.pi_id, note.attachment_filename) if note.attachment?
      note.destroy
      head :no_content
    end

    def download
      note = CardNote.find(params[:id])
      path = AttachmentStore.path_for(note.pi_id, note.attachment_filename)
      return render_json_error("file missing", status: :not_found) unless File.exist?(path)

      send_file path, filename: note.attachment_filename, disposition: "attachment"
    end

    private

    def set_session
      @session = SessionRecord.find_by!(pi_id: params[:id])
    end

    def note_json(n)
      {
        id: n.id, kind: n.kind, body: n.body,
        attachment_filename: n.attachment_filename,
        attachment_url: n.attachment? ? "/api/attachments/#{n.id}/download" : nil,
        created_at: n.created_at.utc.iso8601
      }
    end

    def session_json(s)
      {
        pi_id: s.pi_id, name: s.name, preview: s.preview, model: s.model,
        tokens: s.tokens, cost: s.cost.to_f,
        created_at_session: s.created_at_session&.utc&.iso8601,
        updated_at_session: s.updated_at_session&.utc&.iso8601
      }
    end
  end
end
