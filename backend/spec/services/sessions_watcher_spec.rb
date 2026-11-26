require "rails_helper"

RSpec.describe SessionsWatcher do
  let(:scanner) { instance_double(SessionScanner, root: "/sessions") }
  let(:watcher) { described_class.new(scanner: scanner) }
  let(:project_dir) { "--Users-chr-conversa--" }

  describe "#handle_changes" do
    let(:session) do
      SessionRecord.new(pi_id: "abc", project_dir: project_dir,
                        name: "Live card", file_path: "/sessions/x/y.jsonl")
    end
    let(:card_state) { CardState.new(pi_id: "abc") }

    before do
      allow(ActionCable.server).to receive(:broadcast)
    end

    it "upserts added files and refreshes the board stream" do
      allow(scanner).to receive(:upsert_file)
        .with("/sessions/new.jsonl")
        .and_return({ session: session, card_state: card_state })

      watcher.send(:handle_changes, [], ["/sessions/new.jsonl"], [])

      expect(ActionCable.server).to have_received(:broadcast)
        .with("board:#{project_dir}", hash_including("event" => "refresh"))
    end

    it "removes deleted files and refreshes the board stream" do
      allow(scanner).to receive(:upsert_file).and_return(nil)
      allow(scanner).to receive(:remove_file)
        .with("/sessions/gone.jsonl")
        .and_return({ removed: "xyz", pi_id: "xyz", project_dir: project_dir })

      watcher.send(:handle_changes, [], [], ["/sessions/gone.jsonl"])

      expect(ActionCable.server).to have_received(:broadcast)
        .with("board:#{project_dir}", hash_including("event" => "refresh"))
    end

    it "ignores files the parser cannot read" do
      allow(scanner).to receive(:upsert_file).and_return(nil)
      allow(scanner).to receive(:remove_file).and_return(nil)

      watcher.send(:handle_changes, ["/sessions/broken.jsonl"], [], [])

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it "deduplicates refreshes for multiple changes in one project" do
      allow(scanner).to receive(:upsert_file).and_return(
        { session: session, card_state: card_state })

      watcher.send(:handle_changes, [], ["/sessions/a.jsonl", "/sessions/b.jsonl"], [])

      expect(ActionCable.server).to have_received(:broadcast)
        .with("board:#{project_dir}", hash_including("event" => "refresh")).once
    end
  end
end
