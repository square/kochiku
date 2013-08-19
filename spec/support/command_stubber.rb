class CommandStubber
  attr_accessor :executed_commands, :fake_command_output

  def initialize
    @executed_commands = []
    @fake_command_output = "fake command output"

    # Always stub to prevent executing git commands.
    stub_capture2e
  end

  def create_stubbed_process_status(exitstatus=0)
    obj = Object.new
    obj.stub(:exitstatus).and_return(exitstatus)
    obj.stub(:success?).and_return(exitstatus == 0)
    obj
  end

  def stub_capture2e_failure(fail_on_cmd)
    Open3.stub(:capture2e) do |*cmd|
      @executed_commands << cmd
      exitstatus = 0
      if fail_on_cmd && cmd.any? { |a| a =~ /^#{fail_on_cmd}/ }
        exitstatus = 1
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
