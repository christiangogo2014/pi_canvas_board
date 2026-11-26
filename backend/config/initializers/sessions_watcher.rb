# Boot-time full scan, then start the background watcher.
# Runs after initialization so models and Turbo are ready.
Rails.application.config.after_initialize do
  next unless File.directory?(SessionScanner.new.root.to_s)

  begin
    SessionScanner.new.full_scan
    SessionsWatcher.new.start
  rescue StandardError => e
    Rails.logger.warn("[SessionsWatcher] failed to start: #{e.class}: #{e.message}")
  end
end
