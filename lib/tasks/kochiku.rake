namespace :kochiku do
  namespace :slave do
    def system_launch_agent(name, config)
      plist = File.expand_path("~/Library/LaunchAgents/#{name}.plist")
      puts "Installing #{name} LaunchAgent."
      File.open(plist, "w") { |f| f << config }

      system "launchctl unload -w #{plist}"

      puts "Loading new #{name} LaunchAgent..."
      system "chmod a+r #{plist}"
      system "launchctl load -w #{plist}"
      sleep 1
      puts "Restarting #{name}..."
      system "launchctl stop #{name}"
    end

    desc 'Start a Build worker'
    task :start do
        ENV['QUEUES'] ||= "*"
        ENV['VVERBOSE'] ||= "1" if Rails.env.development?
        Rake::Task['resque:work'].invoke
    end

    task :start_daemon do
      pid = fork
      if pid.nil?
        Process.daemon
        Rake::Task['kochiku:slave:start'].invoke
      else
        puts "started kochiku slave"
      end
    end

    task :setup do
      puts "checking out the web repo..."
      tmp_dir = Rails.root.join('tmp', 'build-partition', 'web-cache')
      FileUtils.mkdir_p tmp_dir
      `cd #{tmp_dir} && git clone git@github.com:square/web .`

      puts "adding plist..."

      kochiku_dir = Rails.root

      log_dir = File.join(kochiku_dir, "log")
      FileUtils.mkdir_p(log_dir)

      rvmrc = File.read(File.join(kochiku_dir, ".rvmrc"))
      wanted_rvm = rvmrc.split(" ").grep(/kochiku/).first

      puts "Creating wrapper for fidelius using #{wanted_rvm}"
      `rvm wrapper #{wanted_rvm} kochiku`
      `rvm wrapper #{wanted_rvm} kochiku bundle`

      kochiku_bundle_wrapper = `which kochiku_bundle`.chomp

      # Install launchctl config
      label                 = "com.squareup.kochiku-slave"

      system_launch_agent label, <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>Label</key>                <string>#{label}</string>
          <key>Program</key>              <string>#{kochiku_bundle_wrapper}</string>
          <key>ProgramArguments</key>     <array>
                                          <string>exec</string>
                                          <string>rake</string>
                                          <string>kochiku:slave:start</string>
                                          </array>
          <key>RunAtLoad</key>            <true/>
          <key>WorkingDirectory</key>     <string>#{kochiku_dir}</string>
          <key>KeepAlive</key>            <true/>
          <key>StandardOutPath</key>      <string>#{log_dir}/slave.log</string>
          <key>StandardErrorPath</key>    <string>#{log_dir}/slave-error.log</string>
          <key>LaunchOnlyOnce</key>       <false/>
          <key>EnvironmentVariables</key> <dict>
                                            <key>RAILS_ENV</key> <string>production</string>
                                          </dict>
        </dict>
      </plist>
        XML
      end

    end
  end
end
