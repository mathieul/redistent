require "redistent/version"

module Redistent
  RedistentError = Class.new(StandardError)
  ConfigError    = Class.new(RedistentError)
  ModelNotFound  = Class.new(RedistentError)
end

require "redistent/core_extensions"
require "redistent/config"
require "redistent/writer"
require "redistent/reader"
require "redistent/eraser"
require "redistent/accessor"
