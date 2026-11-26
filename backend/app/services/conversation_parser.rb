# Parses a pi session JSONL file into a visual-navigable conversation tree:
# nodes (id/parent_id), roles, text, tool calls, usage, plus the active path
# (walk back from the last entry, which is the current leaf).
class ConversationParser
  MAX_TEXT = 6000
  MAX_ARGS = 200

  Node = Data.define(:id, :parent_id, :type, :role, :text, :model, :tokens, :cost,
                     :tool_calls, :error, :timestamp, :meta)

  def initialize(path)
    @path = path
  end

  def call
    nodes = []
    last_id = nil

    File.foreach(@path) do |line|
      entry = JSON.parse(line) rescue next
      id = entry["id"]
      last_id = id if id
      nodes << build_node(entry) if displayable?(entry)
    end

    active_ids = active_path(nodes, last_id)
    { nodes: nodes.map { |n| n.to_h.merge(active: active_ids.include?(n.id)) },
      active_node_id: last_id }
  end

  private

  def displayable?(entry)
    %w[message session_info compaction branch_summary].include?(entry["type"])
  end

  def build_node(entry)
    case entry["type"]
    when "message"
      message_node(entry)
    when "session_info"
      Node.new(entry["id"], entry["parentId"], "session_info", "event",
               "renamed → #{entry["name"]}", nil, nil, nil, nil, [], entry["timestamp"],
               { name: entry["name"] })
    when "compaction", "branch_summary"
      Node.new(entry["id"], entry["parentId"], entry["type"], "event",
               entry["summary"].to_s[0, MAX_TEXT], nil, nil, nil, nil, [], entry["timestamp"], {})
    end
  end

  def message_node(entry)
    m = entry["message"] || {}
    usage = m["usage"] || {}
    role = m["role"]

    if role == "assistant"
      blocks = m["content"] || []
      text = blocks.filter_map { |b| b["text"] if b.is_a?(Hash) && b["type"] == "text" }.join("\n")
      tool_calls = blocks.filter_map do |b|
        next unless b.is_a?(Hash) && b["type"] == "toolCall"
        { name: b["name"], arguments: b["arguments"].to_json[0, MAX_ARGS] }
      end
    else
      text = extract_text(m["content"])
      tool_calls = []
    end

    Node.new(
      entry["id"], entry["parentId"], "message", role,
      text[0, MAX_TEXT], m["model"],
      usage["totalTokens"], usage.dig("cost", "total"),
      tool_calls, m["errorMessage"],
      entry["timestamp"], {}
    )
  end

  def extract_text(content)
    case content
    when String then content
    when Array
      content.filter_map { |b| b["text"] if b.is_a?(Hash) && b["type"] == "text" }.join("\n")
    else
      ""
    end.to_s
  end

  # Walk from the last entry back through parentId links → ids on the
  # currently active branch.
  def active_path(nodes, last_id)
    by_id = nodes.index_by(&:id)
    active = Set.new
    cursor = by_id[last_id]
    while cursor
      active << cursor.id
      cursor = by_id[cursor.parent_id]
    end
    active
  end
end
