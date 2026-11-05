require "open3"

class Understudy < RubyLLM::Protocol
  def complete(messages, **, &)
    content = +""

    Open3.popen2({ "NARRATOR_MODEL" => model.id }, command) do |stdin, stdout, process|
      stdin.write request(messages).to_json
      stdin.close

      stdout.each_line do |line|
        content << line
        yield RubyLLM::Chunk.new(role: :assistant, content: line, model_id: model.id) if block_given?
      end

      raise RubyLLM::ServerError, "#{command} exited with #{process.value.exitstatus}" unless process.value.success?
    end

    RubyLLM::Message.new(role: :assistant, content: content, model: model.id, cost: RubyLLM::Cost.new(total: 0))
  end

  private
    def command
      Rails.configuration.x.narrator_command or raise RubyLLM::ConfigurationError, "No narrator command to run"
    end

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
