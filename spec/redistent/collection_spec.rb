require "spec_helper"
require "virtus"
require "bson"

class Actor
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
end

class Ability
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
end

class Movie
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :title, String
end

class Role
  include Virtus
  attr_accessor :uid, :persisted_attributes
  attribute :character, String
  attribute :actor, Actor
  attribute :movie, Movie
end

class Cinema
  include Redistent::Accessor
  model :actor
  model :movie
  model :role do
    references :actor
    references :movie
  end
end

describe Redistent::Collection do
  let(:key)        { Nest.new("eraser", redis) }
  let(:accessor)   { Cinema.new(redis_config) }
  let(:collection) { Redistent::Collection.new(accessor, model, description) }

  context "referenced collection" do
    let(:model)       { Actor.new(name: "Daniel Craig") }
    let(:description) { Cinema.config.models[:actor].collections[:roles] }
    before(:each) do
      accessor.write(
        Role.new(character: "James Bond", actor: model),
        Role.new(character: "Mikael Blomkvist", actor: model),
        Role.new(character: "Jake Lonergan", actor: model)
      )
    end

    it "can count the number of referrers" do
      expect(collection.count).to eq(3)
    end

    it "can return all the referrers" do
      expect(collection.all.map(&:character).sort).to eq([
        "Jake Lonergan", "James Bond", "Mikael Blomkvist"
      ])
    end
  end

  context "indirect referenced collection" do
    it "can count the number of referrers"
    it "can return all the referrers"
  end

  context "embedded collection" do
    it "can run custom methods"
  end
end
