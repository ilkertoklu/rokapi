class Narrator::Reply
  FENCE = "```"

  def initialize
    @buffer = +""
  end

  def <<(chunk)
    @buffer << chunk
    self
  end

  def structure
    block = json
    block && JSON.parse(block)
  end

  def prose
    closing = closing_fence_at
    closing ? @buffer[(closing + FENCE.length)..].to_s.sub(/#{FENCE}\s*\z/, "").lstrip : ""
  end

  private
    def json
      closing = closing_fence_at
      closing && @buffer[(@buffer.index(FENCE) + FENCE.length)...closing].sub(/\A\s*json/, "")
    end

    def closing_fence_at
      opening = @buffer.index(FENCE)
      opening && @buffer.index(FENCE, opening + FENCE.length)
    end
end
