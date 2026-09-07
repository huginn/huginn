require 'rails_helper'
require_relative '../../../db/seeds/seeder'

describe Seeder do
  before do
    stub_puts_to_prevent_spew_in_spec_output
  end

  describe '.seed' do
    before(:each) do
      User.delete_all
      expect(User.count).to eq(0)
    end

    it 'imports a default scenario' do
      expect { Seeder.seed }.to change(Agent, :count).by(7)
    end

    it 'creates an admin' do
      expect { Seeder.seed }.to change(User, :count).by(1)
      expect(User.last).to be_admin
    end

    it 'generates and prints a password when SEED_PASSWORD is not set' do
      ENV['SEED_PASSWORD'] = nil
      expect(Seeder).to receive(:puts).with(/generated password: (\S+)/) { |message|
        password = message[/generated password: (\S+)/, 1]
        expect(User.last.valid_password?(password)).to be_truthy
        expect(password).not_to eq('password')
      }
      Seeder.seed
    end

    it 'uses SEED_PASSWORD when set' do
      ENV['SEED_PASSWORD'] = 'chosen-password'
      expect(Seeder).not_to receive(:puts).with(/generated password/)
      Seeder.seed
      expect(User.last.valid_password?('chosen-password')).to be_truthy
    ensure
      ENV['SEED_PASSWORD'] = nil
    end

    it 'can be run multiple times and exit normally' do
      Seeder.seed
      expect(Seeder).to receive(:exit)
      Seeder.seed
    end
  end

  def stub_puts_to_prevent_spew_in_spec_output
    allow(Seeder).to receive(:puts).with(anything)
    allow(Seeder).to receive(:puts)
  end
end
