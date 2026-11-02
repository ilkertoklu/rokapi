require "open3"

class Narrator::Understudy
  MODEL = "understudy"

  class Failure < StandardError; end

  def initialize(command)
    @command = command
  end

  def with_instructions(text, append: false, **)
    @instructions = append ? [ @instructions, text ].compact.join("\n\n") : text
    self
  end

  def with_schema(schema)
    @schema = (schema.is_a?(Class) ? schema.new : schema).to_json_schema.except("$schema", "title")
    self
  end

  def ask(prompt)
    content = +""

    Open3.popen2(@command) do |stdin, stdout, process|
      stdin.write request(prompt)
      stdin.close

      each_chunk(stdout) do |chunk|
        content << chunk
        yield RubyLLM::Chunk.new(role: :assistant, content: chunk) if block_given?
      end

      raise Failure, "#{@command} exited with #{process.value.exitstatus}" unless process.value.success?
    end

    RubyLLM::Message.new(role: :assistant, content: content, model: MODEL, cost: RubyLLM::Cost.new(total: 0))
  end

  private
    def request(prompt)
      { system: @instructions, prompt: prompt, schema: @schema }.to_json
    end

    def each_chunk(io)
      pending = "".b

      loop do
        pending << io.readpartial(4096)
        text, pending = split_after_last_character(pending)
        yield text unless text.empty?
      rescue EOFError
        break
      end

      yield pending.force_encoding(Encoding::UTF_8).scrub unless pending.empty?
    end

    def split_after_last_character(bytes)
      cut = (0..[ 3, bytes.bytesize ].min).find { |cut| utf8(bytes.byteslice(0, bytes.bytesize - cut)).valid_encoding? }
      return [ utf8(bytes).scrub, "".b ] if cut.nil?

      [ utf8(bytes.byteslice(0, bytes.bytesize - cut)), bytes.byteslice(bytes.bytesize - cut, cut) ]
    end

    def utf8(bytes)
      bytes.dup.force_encoding(Encoding::UTF_8)
    end
end
