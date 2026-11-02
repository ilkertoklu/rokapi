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
    closing = structure_end
    closing && JSON.parse(@buffer[structure_start..closing])
  rescue JSON::ParserError => error
    raise Narrator::MalformedResponse, error.message
  end

  def prose
    @buffer[0...block_start].sub(/`+\z/, "").strip
  end

  private
    def block_start
      @buffer.index(FENCE) || @buffer.rindex(/^\{/) || @buffer.length
    end

    def structure_start
      @buffer.index("{", block_start)
    end

    def structure_end
      return unless (start = structure_start)

      depth = 0
      quoted = escaped = false

      @buffer[start..].each_char.with_index(start) do |char, index|
        if quoted
          if escaped then escaped = false
          elsif char == "\\" then escaped = true
          elsif char == '"' then quoted = false
          end
        elsif char == '"' then quoted = true
        elsif char == "{" then depth += 1
        elsif char == "}"
          depth -= 1
          return index if depth.zero?
        end
      end

      nil
    end
end
