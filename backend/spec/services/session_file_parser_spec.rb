require "rails_helper"
require "tempfile"

RSpec.describe SessionFileParser do
  let(:header_ts) { "2026-10-20T15:36:25.814Z" }
  let(:later_ts)  { "2026-10-20T16:02:00.000Z" }

  def write_session(entries)
    Tempfile.create(["session_", ".jsonl"]) do |f|
      entries.each { |e| f.puts(e.to_json) }
      f.flush
      described_class.new(f.path).call
    end
  end

  def header(id = "01a159f4-test")
    { "type" => "session", "version" => 3, "id" => id,
      "timestamp" => header_ts, "cwd" => "/Users/chr/projects/conversa" }
  end

  def user_message(text, ts: header_ts)
    { "type" => "message", "id" => "m#{rand(1000)}", "parentId" => nil, "timestamp" => ts,
      "message" => { "role" => "user", "content" => [{ "type" => "text", "text" => text }],
                     "timestamp" => ts } }
  end

  def assistant_message(ts:, total_tokens: 100, cost: 0.01, model: "glm-5.3-flash")
    { "type" => "message", "id" => "a#{rand(1000)}", "parentId" => nil, "timestamp" => ts,
      "message" => {
        "role" => "assistant", "api" => "zai", "provider" => "zai", "model" => model,
        "content" => [{ "type" => "text", "text" => "ok" }],
        "usage" => { "input" => 50, "output" => 50, "cacheRead" => 0, "cacheWrite" => 0,
                     "totalTokens" => total_tokens,
                     "cost" => { "input" => cost, "output" => 0, "cacheRead" => 0,
                                 "cacheWrite" => 0, "total" => cost } },
        "stopReason" => "stop", "timestamp" => ts } }
  end

  it "parses id, timestamps, name, preview, model, tokens and cost" do
    result = write_session([
      header,
      { "type" => "model_change", "timestamp" => header_ts, "provider" => "zai",
        "modelId" => "glm-5.3-flash" },
      user_message("fix the login redirect"),
      assistant_message(ts: later_ts, total_tokens: 1500, cost: 0.0234),
      { "type" => "session_info", "id" => "s1", "parentId" => nil,
        "timestamp" => later_ts, "name" => "Add Bitbucket Remote Origin" }
    ])

    expect(result.pi_id).to eq("01a159f4-test")
    expect(result.name).to eq("Add Bitbucket Remote Origin")
    expect(result.preview).to eq("fix the login redirect")
    expect(result.model).to eq("glm-5.3-flash")
    expect(result.tokens).to eq(1500)
    expect(result.cost).to eq(0.0234)
    expect(result.created_at_session).to eq(Time.iso8601(header_ts))
    expect(result.updated_at_session).to eq(Time.iso8601(later_ts))
  end

  it "uses the header timestamp as updated_at when no later entry exists" do
    result = write_session([header])
    expect(result.updated_at_session).to eq(Time.iso8601(header_ts))
  end

  it "takes the last session_info name" do
    result = write_session([
      header,
      { "type" => "session_info", "id" => "s1", "parentId" => nil,
        "timestamp" => header_ts, "name" => "First name" },
      { "type" => "session_info", "id" => "s2", "parentId" => nil,
        "timestamp" => later_ts, "name" => "Renamed" }
    ])
    expect(result.name).to eq("Renamed")
  end

  it "truncates long previews" do
    result = write_session([header, user_message("a" * 300)])
    expect(result.preview.length).to eq(SessionFileParser::PREVIEW_MAX)
    expect(result.preview).to end_with("...")
  end

  it "handles string-content user messages" do
    result = write_session([
      header,
      { "type" => "message", "id" => "m1", "parentId" => nil, "timestamp" => header_ts,
        "message" => { "role" => "user", "content" => "plain string prompt" } }
    ])
    expect(result.preview).to eq("plain string prompt")
  end

  it "returns nil for a file without a session header" do
    expect(write_session([user_message("orphan")])).to be_nil
  end

  it "skips malformed lines without failing" do
    Tempfile.create(["session_", ".jsonl"]) do |f|
      f.puts("not json {{{")
      f.puts(header.to_json)
      f.flush
      expect(described_class.new(f.path).call.pi_id).to eq("01a159f4-test")
    end
  end

  it "sums cost across assistant messages" do
    result = write_session([
      header,
      assistant_message(ts: header_ts, cost: 0.01),
      assistant_message(ts: later_ts, cost: 0.02)
    ])
    expect(result.cost).to eq(0.03)
    expect(result.tokens).to eq(200)
  end
end
