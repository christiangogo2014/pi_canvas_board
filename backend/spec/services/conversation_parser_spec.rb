require "rails_helper"

RSpec.describe ConversationParser do
  let(:path) { File.join(Dir.mktmpdir, "session.jsonl") }

  def entries_to_file(entries)
    File.write(path, entries.map(&:to_json).join("\n") << "\n")
  end

  let(:entries) do
    [
      { "type" => "session", "id" => "root", "timestamp" => "2026-01-01T00:00:00.000Z", "cwd" => "/x" },
      { "type" => "message", "id" => "m1", "parentId" => "root", "timestamp" => "2026-01-01T00:00:01.000Z",
        "message" => { "role" => "user", "content" => [{ "type" => "text", "text" => "fix the login" }], "timestamp" => 0 } },
      { "type" => "message", "id" => "m2", "parentId" => "m1", "timestamp" => "2026-01-01T00:00:02.000Z",
        "message" => { "role" => "assistant", "model" => "glm", "stopReason" => "stop",
                       "content" => [{ "type" => "thinking", "thinking" => "hmm" },
                                     { "type" => "text", "text" => "on it" },
                                     { "type" => "toolCall", "id" => "t1", "name" => "read", "arguments" => { "path" => "/x" } }],
                       "usage" => { "totalTokens" => 100, "cost" => { "total" => 0.01 } }, "timestamp" => 0 } },
      # branch A (active, latest)
      { "type" => "message", "id" => "m3a", "parentId" => "m2", "timestamp" => "2026-01-01T00:00:03.000Z",
        "message" => { "role" => "user", "content" => [{ "type" => "text", "text" => "try approach A" }], "timestamp" => 0 } },
      # branch B (abandoned)
      { "type" => "message", "id" => "m3b", "parentId" => "m2", "timestamp" => "2026-01-01T00:00:04.000Z",
        "message" => { "role" => "user", "content" => [{ "type" => "text", "text" => "try approach B" }], "timestamp" => 0 } },
      { "type" => "session_info", "id" => "si", "parentId" => "m3a", "timestamp" => "2026-01-01T00:00:05.000Z", "name" => "Fix login" }
    ]
  end

  before { entries_to_file(entries) }

  it "builds displayable nodes with id/parent/role/text" do
    result = described_class.new(path).call
    ids = result[:nodes].map { |n| n[:id] }
    expect(ids).to include("m1", "m2", "m3a", "m3b", "si")
    expect(result[:nodes].map { |n| n[:role] }).to include("user", "assistant", "event")
    m1 = result[:nodes].find { |n| n[:id] == "m1" }
    expect(m1[:parent_id]).to eq("root")
    expect(m1[:text]).to eq("fix the login")
  end

  it "extracts assistant text and tool calls, ignoring thinking blocks" do
    m2 = described_class.new(path).call[:nodes].find { |n| n[:id] == "m2" }
    expect(m2[:text]).to eq("on it")
    expect(m2[:tool_calls]).to eq([{ name: "read", arguments: '{"path":"/x"}' }])
    expect(m2[:tokens]).to eq(100)
    expect(m2[:cost]).to eq(0.01)
    expect(m2[:model]).to eq("glm")
  end

  it "marks the active path walking back from the last entry" do
    result = described_class.new(path).call
    by_id = result[:nodes].index_by { |n| n[:id] }
    # last entry is session_info si → path: si, m3a, m2, m1 (root header not displayed)
    expect(by_id["m3a"][:active]).to be(true)
    expect(by_id["m2"][:active]).to be(true)
    expect(by_id["m3b"][:active]).to be(false)
  end

  it "skips undisplayable entry types" do
    entries_to_file(entries + [{ "type" => "thinking_level_change", "id" => "t", "parentId" => nil, "timestamp" => "2026-01-01T00:00:06.000Z", "thinkingLevel" => "low" }])
    ids = described_class.new(path).call[:nodes].map { |n| n[:id] }
    expect(ids).not_to include("t")
  end

  it "truncates long text" do
    long = "x" * 10_000
    entries_to_file([
      entries.first,
      { "type" => "message", "id" => "big", "parentId" => "root", "timestamp" => "2026-01-01T00:00:07.000Z",
        "message" => { "role" => "user", "content" => [{ "type" => "text", "text" => long }], "timestamp" => 0 } }
    ])
    node = described_class.new(path).call[:nodes].find { |n| n[:id] == "big" }
    expect(node[:text].length).to eq(ConversationParser::MAX_TEXT)
  end
end
