require 'rails_helper'

describe Location do
  let(:location) {
    Location.new(
      lat: BigDecimal('2.0'),
      lng: BigDecimal('3.0'),
      radius: 300,
      speed: 2,
      course: 30)
  }

  it "converts values to Float" do
    expect(location.lat).to be_a Float
    expect(location.lat).to eq 2.0
    expect(location.lng).to be_a Float
    expect(location.lng).to eq 3.0
    expect(location.radius).to be_a Float
    expect(location.radius).to eq 300.0
    expect(location.speed).to be_a Float
    expect(location.speed).to eq 2.0
    expect(location.course).to be_a Float
    expect(location.course).to eq 30.0
  end

  it "provides hash-style access to its properties with both symbol and string keys" do
    expect(location[:lat]).to be_a Float
    expect(location[:lat]).to eq 2.0
    expect(location['lat']).to be_a Float
    expect(location['lat']).to eq 2.0
  end

  it "has a convenience accessor for combined latitude and longitude" do
    expect(location.latlng).to eq "2.0,3.0"
  end

  it "does not allow hash-style assignment" do
    expect {
      location[:lat] = 2.0
    }.to raise_error(NoMethodError)
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

  it "is droppable" do
    {
      '{{location.lat}}' => '2.0',
      '{{location.latitude}}' => '2.0',
      '{{location.lng}}' => '3.0',
      '{{location.longitude}}' => '3.0',
      '{{location.latlng}}' => '2.0,3.0',
    }.each { |template, result|
      expect(Liquid::Template.parse(template).render('location' => location.to_liquid)).to eq(result),
        "expected #{template.inspect} to expand to #{result.inspect}"
    }
  end
end
