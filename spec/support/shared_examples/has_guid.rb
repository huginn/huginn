require 'rails_helper'

shared_examples_for HasGuid do
  it "gets created before_save, but only if it's not present" do
    instance = new_instance
    expect(instance.guid).to be_nil
    instance.save!
    expect(instance.guid).not_to be_nil

    expect { instance.save! }.not_to change { instance.reload.guid }
  end
end
