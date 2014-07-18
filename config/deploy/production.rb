# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Server that is running the Kochiku Rails app
server 'kochiku.example.com', user: 'kochiku', roles: %w{web app db worker}
