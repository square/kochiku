class CommandStubber
  include RSpec::Mocks::ExampleMethods

  attr_accessor :executed_commands, :fake_command_output

  def initialize
    @executed_commands = []
    @fake_command_output = "fake command output"

    # Always stub to prevent executing git commands.
    stub_capture2e
  end

  def create_stubbed_process_status(exitstatus = 0)
    double(
      exitstatus: exitstatus,
      success?: exitstatus == 0
    )
  end

  def stub_capture2e_failure(fail_on_cmd)
    allow(Open3).to receive(:capture2e) do |*cmd|
      # cmd is an Array in the format: [{'env' => 'variable'}, 'echo baz']
      # where the hash with environment variables is optional
      @executed_commands << cmd
      exitstatus =
        if fail_on_cmd && cmd.any? { |a| a.is_a?(String) && a.start_with?(fail_on_cmd) }
          1
        else
          0
        end
      [@fake_command_output, create_stubbed_process_status(exitstatus)]
    end
  end

  def stub_capture2e
    stub_capture2e_failure(nil)
  end

  def check_cmd_executed(expected_cmd)
    found = @executed_commands.any? do |commands|
      commands.any? { |cmd| cmd =~ /^#{expected_cmd}.*/ }
    end
    raise Exception, "Failed to find #{expected_cmd} in executed commands" unless found
  end
end
