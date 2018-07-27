require 'rails_helper'
require_relative '../../../db/seeds/seeder'

describe Seeder do
  before do
    stub_puts_to_prevent_spew_in_spec_output
  end

  describe '.seed' do
    it 'imports a default scenario' do
      expect { Seeder.seed }.to change(Agent, :count).by(7)
    end

    it 'creates an admin' do
      expect { Seeder.seed }.to change(User, :count).by(1)
      expect(User.last).to be_admin
    end

    it 'can be run multiple times and exit normally' do
      Seeder.seed
      expect { Seeder.seed }.to raise_error(SystemExit)
    end
  end

  def stub_puts_to_prevent_spew_in_spec_output
    stub(Seeder).puts(anything)
    stub(Seeder).puts
  end
end
