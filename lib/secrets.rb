require 'yaml'

# Exposes secrets that typically live in a secrets YAML, managed by Keywhiz
module Secrets
  extend self

  def secret(name, file, path)
    instance_variable_set("@#{name}", get_secret(file, path))

    send(:define_method, name) do
      instance_variable_get("@#{name}")
    end
  end

  def get_secret(file, path)
    path.reduce(file_hash(file)) do |hash, key|
      if hash.is_a?(Hash) && hash.has_key?(key)
        hash.fetch(key)
      else
        raise "Path does not exist: #{path} #{file.inspect}"
      end
    end
  end

  def file_hash(file)
    path = [server_path, laptop_path].map do |p|
      File.join(p, file)
    end.detect { |f| File.exists?(f) }
    if path
      YAML.load_file(path)
    else
      raise "File does not exist: #{file}"
    end
  end

  def laptop_path
    raise "Trying to use dev secrets"
    Rails.root.join(*%w(config dev_secrets))
  end

  def server_path
    File.join("/app/kochiku/secrets")
  end

  secret :github_oauth, 'kochiku-github.yaml', %w(oauth)
end
