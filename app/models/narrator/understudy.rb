require "open3"

class Narrator::Understudy < RubyLLM::Provider
  MODEL = "understudy"

  class Protocol < RubyLLM::Protocol
    def complete(messages, **, &)
      content = +""

      Open3.popen2(Rails.configuration.x.narrator_command) do |stdin, stdout, process|
        stdin.write request(messages).to_json
        stdin.close

        stdout.each_line do |line|
          content << line
          yield RubyLLM::Chunk.new(role: :assistant, content: line, model_id: MODEL) if block_given?
        end

        raise RubyLLM::ServerError, "#{Rails.configuration.x.narrator_command} exited with #{process.value.exitstatus}" unless process.value.success?
      end

      RubyLLM::Message.new(role: :assistant, content: content, model: MODEL, cost: RubyLLM::Cost.new(total: 0))
    end

    private
      def request(messages)
        system, conversation = messages.partition { |message| message.role == :system }

        { system: system.map(&:content).join("\n\n").presence, prompt: transcript(conversation) }
      end

      def transcript(conversation)
        *earlier, latest = conversation
        return latest.content if earlier.empty?

        turns = earlier.map { |message| "<#{message.role}>\n#{message.content}\n</#{message.role}>" }
        "<conversation_so_far>\n#{turns.join("\n")}\n</conversation_so_far>\n\n#{latest.content}"
      end
  end

  protocol :understudy, Protocol

  def self.local? = true

  def api_base = nil
end
