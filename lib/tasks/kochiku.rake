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
      ENV['QUEUES'] ||= "high,partition,ci,developer"
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

    def kochiku_dir
      Rails.root
    end

    def log_dir
      File.join(kochiku_dir, "log")
    end

    desc "Setup a development environment to run a kochiku worker. Use capistrano for remote hosts"
    task :setup do
      tmp_dir = Rails.root.join('tmp', 'build-partition', 'web-cache')
      unless File.exists?(tmp_dir)
        FileUtils.mkdir_p tmp_dir
        `git clone --recurse-submodules git@git.squareup.com:square/web.git #{tmp_dir}`
      end

      FileUtils.mkdir_p(log_dir)
    end

    task :setup_launchctl do
      rvmrc = File.read(File.join(kochiku_dir, ".rvmrc"))
      wanted_rvm = rvmrc.split(" ").grep(/kochiku/).first

      puts "Creating wrapper for kochiku using #{wanted_rvm}"
      `rvm wrapper #{wanted_rvm} kochiku`

      label                = "com.squareup.kochiku-slave"
      kochiku_rake_wrapper = `which kochiku_rake`.chomp

      system_launch_agent label, <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>                <string>#{label}</string>
    <key>Program</key>              <string>#{kochiku_rake_wrapper}</string>
    <key>ProgramArguments</key>     <array>
                                    <string> </string>
                                    <string>kochiku:slave:start</string>
                                    <string>--trace</string>
                                    </array>
    <key>RunAtLoad</key>            <true/>
    <key>WorkingDirectory</key>     <string>/Users/square/kochiku/current</string>
    <key>KeepAlive</key>            <true/>
    <key>StandardOutPath</key>      <string>/Users/square/kochiku/current/slave.log</string>
    <key>StandardErrorPath</key>    <string>/Users/square/kochiku/current/slave-error.log</string>
    <key>LaunchOnlyOnce</key>       <false/>
    <key>EnvironmentVariables</key> <dict>
                                      <key>RAILS_ENV</key> <string>production</string>
                                      <key>PATH</key> <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin</string>
                                    </dict>
  </dict>
</plist>
      XML
    end
  end
end
