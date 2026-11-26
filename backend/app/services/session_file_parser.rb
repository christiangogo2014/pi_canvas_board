# Streams one pi session JSONL file and extracts card-relevant data
# without loading the whole file into memory.
#
# Session format (v3): https://docs.pi.dev — every line is JSON with a
# "type" field. Relevant entry types:
#   session      -> header: id, timestamp, cwd
#   session_info -> session display name (may appear multiple times; last wins)
#   message      -> user (first one = preview) and assistant (usage/model)
class SessionFileParser
  Result = Data.define(:pi_id, :name, :preview, :model, :tokens, :cost,
                       :created_at_session, :updated_at_session)

  PREVIEW_MAX = 120

  def initialize(path)
    @path = path
  end

  def call
    pi_id = nil
    header_ts = nil
    name = nil
    preview = nil
    model = nil
    tokens = 0
    cost = 0.0
    max_ts = nil

    File.foreach(@path) do |line|
      entry = JSON.parse(line) rescue next
      ts = entry["timestamp"]
      max_ts = ts if ts && (max_ts.nil? || ts > max_ts)

      case entry["type"]
      when "session"
        pi_id = entry["id"]
        header_ts = entry["timestamp"]
      when "session_info"
        name = entry["name"] if entry["name"].present?
      when "message"
        msg = entry["message"]
        next unless msg.is_a?(Hash)

        case msg["role"]
        when "user"
          preview ||= first_text(msg["content"])&.truncate(PREVIEW_MAX)
        when "assistant"
          if (usage = msg["usage"])
            tokens += usage["totalTokens"].to_i
            cost += usage.dig("cost", "total").to_f
          end
          model ||= msg["model"] if msg["model"].present?
        end
      end
    end

    return nil unless pi_id && header_ts

    Result.new(
      pi_id, name, preview, model, tokens, cost.round(6),
      Time.iso8601(header_ts),
      Time.iso8601(max_ts || header_ts)
    )
  end

  private

  def first_text(content)
    case content
    when String
      content
    when Array
      content.filter_map { |c| c["text"] if c.is_a?(Hash) && c["type"] == "text" }.first
    end
  end
end
