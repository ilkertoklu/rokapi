require "open3"

class Narrator::Understudy < RubyLLM::Provider
  MODEL = "understudy"

  class Failure < StandardError; end

  class Protocol < RubyLLM::Protocol
    def complete(messages, schema: nil, **, &)
      content = +""

      Open3.popen2(Rails.configuration.x.narrator_command) do |stdin, stdout, process|
        stdin.write request(messages, schema).to_json
        stdin.close

        each_chunk(stdout) do |chunk|
          content << chunk
          yield RubyLLM::Chunk.new(role: :assistant, content: chunk, model_id: MODEL) if block_given?
        end

        raise Failure, "#{Rails.configuration.x.narrator_command} exited with #{process.value.exitstatus}" unless process.value.success?
      end

      RubyLLM::Message.new(role: :assistant, content: content, model: MODEL, cost: RubyLLM::Cost.new(total: 0))
    end

    private
      def request(messages, schema)
        system, conversation = messages.partition { |message| message.role == :system }

        { system: system.map(&:content).join("\n\n").presence, prompt: transcript(conversation),
          schema: schema&.dig(:schema) }
      end

      def transcript(conversation)
        *earlier, latest = conversation
        return latest.content if earlier.empty?

        turns = earlier.map { |message| "<#{message.role}>\n#{message.content}\n</#{message.role}>" }
        "<conversation_so_far>\n#{turns.join("\n")}\n</conversation_so_far>\n\n#{latest.content}"
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

  protocol :understudy, Protocol

  def self.local?
    true
  end

  def api_base
    nil
  end
end
