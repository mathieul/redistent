require "virtus"
require "bson"

class Band
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
end

class Musician
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  attribute :band, Band
end

class Instrument
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  attribute :type, String
  attribute :musician, Musician
end

class Song
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :title, String
  attribute :popularity, Fixnum
  attribute :band, Band
end

