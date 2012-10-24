require 'stringio'
class FilelessIO < StringIO
  attr_accessor :original_filename
end
