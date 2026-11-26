require "rails_helper"
require "tmpdir"
require "fileutils"

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

    it "accepts a locale loaded from a configured translation gem" do
      Dir.mktmpdir('huginn-ui-locale-') do |root|
        path = File.join(root, 'config/locales/xx.yml')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "xx:\n  hello: Translated hello\n")
        loaded_specs = Gem.loaded_specs.merge('huginn_test_locale' => double(full_gem_path: root))
        allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
        previous_paths = I18n.load_path.dup
        previous_backend = I18n.backend
        begin
          I18n.backend = I18n::Backend::Simple.new
          I18n.load_path += GemfileHelper.additional_gem_locale_paths('huginn_test_locale')

          expect { described_class.ensure_available!(:xx) }.not_to raise_error
          expect(I18n.t(:hello, locale: :xx)).to eq('Translated hello')
        ensure
          I18n.backend = previous_backend
          I18n.load_path = previous_paths
        end
      end
    end

    it "rejects a locale without translations" do
      expect { described_class.ensure_available!(:zz) }
        .to raise_error(ArgumentError, /LOCALE is set to "zz".*ADDITIONAL_GEMS/m)
    end
  end
end
