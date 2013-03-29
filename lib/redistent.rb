require "redistent/version"

module Redistent
  ConfigError = Class.new(StandardError)
end

require "redistent/core_extensions"
require "redistent/config"
require "redistent/writer"
require "redistent/accessor"
