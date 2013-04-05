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
  model :movie do
    collection :actors, via: :roles
  end
  model :role do
    references :actor
    references :movie
  end
end

describe Redistent::Collection do
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
    let(:model)       { Movie.new(title: "Pulp Fiction") }
    let(:description) { Cinema.config.models[:movie].collections[:actors] }
    before(:each) do
      accessor.write(
        Role.new(character: "Vincent Vega", movie: model, actor: Actor.new(name: "John Travolta")),
        Role.new(character: "Jules Winnfield", movie: model, actor: Actor.new(name: "Samuel Jackson")),
        Role.new(character: "Mia Wallace", movie: model, actor: Actor.new(name: "Uma Thurman"))
      )
    end

    it "can count the number of referrers" do
      expect(collection.count).to eq(3)
    end

    it "can return all the referrers" do
      expect(collection.all.map(&:name).sort).to eq([
        "John Travolta", "Samuel Jackson", "Uma Thurman"
      ])
    end
  end

  context "embedded collection" do
    it "can run custom methods"
  end
end
