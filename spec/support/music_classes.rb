require "virtus"
require "bson"

class Band
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  def complete?
    name && name.length > 0
  end
end

class Musician
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  attribute :band, Band
  def complete?
    band && name && name.length > 0
  end
end

class Instrument
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  attribute :type, String
  attribute :musician, Musician
  def complete?
    name && type && musician
  end
end
