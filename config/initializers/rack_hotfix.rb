# TODO: Can be removed after updating to rack 1.3.0
# this removes the warning: regexp match /.../n against to UTF-8 string warnings
module Rack
  module Utils
    def escape(s)
      CGI.escape(s.to_s)
    end
    def unescape(s)
      CGI.unescape(s)
    end
  end
end