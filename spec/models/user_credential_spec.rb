require 'spec_helper'

describe UserCredential do
  describe "validation" do
    it {should validate_uniqueness_of(:credential_name).scoped_to(:user_id)}
  end
  describe "mass assignment" do
    it {should allow_mass_assignment_of :credential_name}

    it {should allow_mass_assignment_of :credential_value}

    it {should allow_mass_assignment_of :user_id}
  end
end
