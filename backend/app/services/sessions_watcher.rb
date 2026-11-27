# Watches the mounted pi sessions tree; on add/change → incremental upsert,
# on removal → record cleanup, all followed by a Turbo broadcast so open
# boards update live. Polling mode because Docker macOS mounts do not emit
# inotify events.
class SessionsWatcher
  def initialize(scanner: SessionScanner.new)
    @scanner = scanner
    @listener = nil
  end

  def start
    require "listen"

    @listener = Listen.to(@scanner.root.to_s,
                          only: /\.jsonl\z/,
                          force_polling: true,
                          latency: 2) do |modified, added, removed|
      Thread.new do
        handle_changes(modified, added, removed)
      end
    end.start
    Rails.logger.info("[SessionsWatcher] watching #{@scanner.root}")
    @listener
  end

  def stop
    @listener&.stop
  end

  private

  def handle_changes(modified, added, removed)
    changed_projects = []

    (added + modified).each do |path|
      begin
        result = @scanner.upsert_file(path)
      rescue StandardError => e
        Rails.logger.warn("[SessionsWatcher] upsert failed for #{path}: #{e.class}: #{e.message}")
        next
      end
      next unless result

      changed_projects << result[:session].project_dir
    end

    removed.each do |path|
      result = @scanner.remove_file(path)
      next unless result

      changed_projects << File.basename(File.dirname(path))
    end

    changed_projects.uniq.compact.each { |dir| broadcast_refresh(dir) }
  end

  # Notify all open boards for this project so the SPA refetches.
  def broadcast_refresh(project_dir)
    ActionCable.server.broadcast("board:#{project_dir}", { "event" => "refresh" })
  end
end
