require 'rails_helper'
require 'inheritance_tracking'

describe InheritanceTracking do
  class Class1
    include InheritanceTracking
  end

  class Class2 < Class1; end
  class Class3 < Class1; end

  it "tracks subclasses" do
    expect(Class1.subclasses).to eq([Class2, Class3])
  end

  it "can be temporarily overridden with #with_subclasses" do
    Class1.with_subclasses(Class2) do
      expect(Class1.subclasses).to eq([Class2])
    end
  end
end