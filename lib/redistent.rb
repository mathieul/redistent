require "redistent/version"

module Redistent
  RedistentError     = Class.new(StandardError)
  ConfigError        = Class.new(RedistentError)
  CollectionNotFound = Class.new(RedistentError)
  ModelNotFound      = Class.new(RedistentError)
end

require "redistent/core_extensions/string_extensions"
require "redistent/abilities/has_model_keys"
require "redistent/abilities/has_model_descriptions"
require "redistent/config"
require "redistent/writer"
require "redistent/reader"
require "redistent/eraser"
require "redistent/collection"
require "redistent/accessor"
