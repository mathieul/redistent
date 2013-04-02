require "spec_helper"
require "music_classes"
require "redis_helper"

describe Redistent::Eraser do
  include RedisHelper

  let(:key)       { Nest.new("eraser", redis) }
  let(:eraser)    { Redistent::Eraser.new(key, config.models) }
  let(:model) { Band.new(uid: "12") }

  it "deletes the uid key" do
    redis.sadd("eraser:Band:all", "12")
    eraser.erase(model)
    expect(redis.smembers("eraser:Band:all")).to be_empty
  end

  it "deletes the attributes key" do
    redis.set("eraser:Band:12", BSON.serialize({}).to_s)
    eraser.erase(model)
    expect(redis.get("eraser:Band:12")).to be_nil
  end

  it "deletes the index keys for each reference" do
    redis.sadd("eraser:Musician:indices:band_uid:007", "42")
    james = Musician.new(uid: "42", persisted_attributes: {band_uid: "007"})
    eraser.erase(james)
    expect(redis.smembers("eraser:Musician:indices:band_uid:007")).to be_empty
  end
end
