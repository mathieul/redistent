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
  attribute :score, Integer
  attribute :actor, Actor
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

describe Redistent::Collection do
  let(:accessor_klass) {
    Class.new.tap do |klass|
      klass.send(:include, Redistent::Accessor)
      klass.model :actor
      klass.model :movie do
        collection :actors, via: :roles
      end
      klass.model :role do
        references :actor
        references :movie
      end
    end
  }
  let(:accessor)   { accessor_klass.new(redis_config) }
  let(:collection) { Redistent::Collection.new(accessor, model, description) }

  context "referenced collection" do
    let(:model)       { Actor.new(name: "Daniel Craig") }
    let(:description) { accessor_klass.config.models[:actor].collections[:roles] }
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
    let(:description) { accessor_klass.config.models[:movie].collections[:actors] }
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
    let(:model)       { Actor.new(name: "Ryan Gosling") }
    let(:description) { accessor_klass.config.models[:actor].collections[:abilitys] }

    it "can run custom methods" do
      accessor_klass.model :ability
      accessor_klass.model :actor do
        embeds :abilitys do
          define(:count) { |key| key.scard }
        end
      end
      accessor.write(
        Ability.new(name: "comedy", actor: model),
        Ability.new(name: "drama", actor: model)
      )
      expect(collection.count).to eq(2)
    end

    it "uses a sorted set when using :sort_by option" do
      accessor_klass.model :ability
      accessor_klass.model :actor do
        embeds :abilitys do
          define(:best) { |key| key.zrevrangebyscore("-inf", "+inf", limit: [0, 1]).first }
        end
      end
      accessor.write(
        Ability.new(name: "comedy", score: 9, actor: model),
        Ability.new(name: "drama", score: 10, actor: model),
        Ability.new(name: "musical", score: 8, actor: model)
      )
      expect(collection.best.name).to eq("drama")
    end
  end
end
