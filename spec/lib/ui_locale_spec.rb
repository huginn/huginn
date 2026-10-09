require "rails_helper"

describe UiLocale do
  describe ".ensure_available!" do
    it "uses English by default" do
      expect(I18n.default_locale).to eq(:en)
      expect { described_class.ensure_available! }.not_to raise_error
    end

    it "accepts a locale that has translations" do
      I18n.backend.store_translations(:xx, { hello: "Hello" })

      expect { described_class.ensure_available!(:xx) }.not_to raise_error
    ensure
      I18n.reload!
    end

    it "rejects a locale without translations" do
      expect { described_class.ensure_available!(:zz) }
        .to raise_error(ArgumentError, /LOCALE is set to "zz".*ADDITIONAL_GEMS/m)
    end
  end
end
