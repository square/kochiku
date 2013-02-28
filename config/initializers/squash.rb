Squash::Ruby.configure :api_key  => 'b29ba2c2-3af6-40dc-a961-5edbf4fa41ed',
                       :api_host => 'https://api.squash.square'


module Squash::Ruby
  GUARD_DOG_CONFIG = YAML.load_file(Rails.root.join('config', 'environments', 'production', 'guard_dog.yml')).symbolize_keys

  def self.http_transmit(url, headers, body)
    client = GuardDog::SslClient.new(GUARD_DOG_CONFIG.merge(:uri => url))
    client.post URI.parse(url).path, body, headers.merge('Content-Type' => 'application/json')
  end
end
