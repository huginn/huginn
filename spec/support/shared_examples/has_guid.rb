require 'spec_helper'

shared_examples_for HasGuid do
  it "gets created before_save, but only if it's not present" do
    instance = new_instance
    instance.guid.should be_nil
    instance.save!
    instance.guid.should_not be_nil

    lambda { instance.save! }.should_not change { instance.reload.guid }
  end
end
