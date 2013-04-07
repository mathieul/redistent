require "spec_helper"
require "music_classes"
require "redis_helper"

describe Redistent::Eraser do
  include RedisHelper

  let(:key)    { Nest.new("eraser", redis) }
  let(:eraser) { Redistent::Eraser.new(key, config.models) }
  let(:model)  { MusicClasses::Band.new(uid: "12") }
  before(:each) { config.finalize! }

  it "erases the uid key" do
    redis.sadd("eraser:Band:all", "12")
    eraser.erase(model)
    expect(redis.smembers("eraser:Band:all")).to be_empty
  end

  it "erases the attributes key" do
    redis.set("eraser:Band:12", BSON.serialize({}).to_s)
    eraser.erase(model)
    expect(redis.get("eraser:Band:12")).to be_nil
  end

  it "erases the index keys for each reference" do
    redis.sadd("eraser:Musician:indices:band_uid:007", "42")
    james = MusicClasses::Musician.new(uid: "42", persisted_attributes: {band_uid: "007"})
    eraser.erase(james)
    expect(redis.smembers("eraser:Musician:indices:band_uid:007")).to be_empty
  end

  it "erases the sorted index for each sorted collection", wip: true do
    redis.zadd("eraser:Band:P77:song_uids", 10.0, "RX")
    song = MusicClasses::Song.new(uid: "RX", persisted_attributes: {band_uid: "P77"})
    eraser.erase(song)
    expect(redis.zrange("eraser:Band:P77:song_uids", 0, -1)).to be_empty
  end

  it "erases the refence key for each reference" do
    redis.set("eraser:Musician:42:band_uid", "007")
    james = MusicClasses::Musician.new(uid: "42", persisted_attributes: {band_uid: "007"})
    eraser.erase(james)
    expect(redis.get("eraser:Musician:42:band_uid")).to be_nil
  end
end
