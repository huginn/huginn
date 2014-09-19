require 'spec_helper'

describe Location do
  let(:location) {
    Location.new(
      lat: BigDecimal.new('2.0'),
      lng: BigDecimal.new('3.0'),
      radius: 300,
      speed: 2,
      course: 30)
  }

  it "converts values to Float" do
    expect(location.lat).to equal 2.0
    expect(location.lng).to equal 3.0
    expect(location.radius).to equal 300.0
    expect(location.speed).to equal 2.0
    expect(location.course).to equal 30.0
  end

  it "provides hash-style access to its properties with both symbol and string keys" do
    expect(location[:lat]).to equal 2.0
    expect(location['lat']).to equal 2.0
  end

  it "does not allow hash-style assignment" do
    expect {
      location[:lat] = 2.0
    }.to raise_error
  end

  it "ignores invalid values" do
    location2 = Location.new(
      lat: 2,
      lng: 3,
      radius: -1,
      speed: -1,
      course: -1)
    expect(location2.radius).to be_nil
    expect(location2.speed).to be_nil
    expect(location2.course).to be_nil
  end

  it "considers a location empty if either latitude or longitude is missing" do
    expect(Location.new.empty?).to be_truthy
    expect(Location.new(lat: 2, radius: 1).present?).to be_falsy
    expect(Location.new(lng: 3, radius: 1).present?).to be_falsy
  end
end
