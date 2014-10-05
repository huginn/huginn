require 'spec_helper'

describe ApplicationHelper do
  describe '#nav_link' do
    it 'returns a nav link' do
      stub(self).current_page?('/things') { false }
      nav = nav_link('Things', '/things')
      a = Nokogiri(nav).at('li:not(.active) > a[href="/things"]')
      expect(a.text.strip).to eq('Things')
    end

    it 'returns a nav link with a glyphicon' do
      stub(self).current_page?('/things') { false }
      nav = nav_link('Things', '/things', glyphicon: 'help')
      expect(nav).to be_html_safe
      a = Nokogiri(nav).at('li:not(.active) > a[href="/things"]')
      expect(a.at('span.glyphicon.glyphicon-help')).to be_a Nokogiri::XML::Element
      expect(a.text.strip).to eq('Things')
    end

    it 'returns an active nav link' do
      stub(self).current_page?('/things') { true }
      nav = nav_link('Things', '/things')
      expect(nav).to be_html_safe
      a = Nokogiri(nav).at('li.active > a[href="/things"]')
      expect(a).to be_a Nokogiri::XML::Element
      expect(a.text.strip).to eq('Things')
    end

    describe 'with block' do
      it 'returns a nav link with menu' do
        stub(self).current_page?('/things') { false }
        stub(self).current_page?('/things/stuff') { false }
        nav = nav_link('Things', '/things') { nav_link('Stuff', '/things/stuff') }
        expect(nav).to be_html_safe
        a0 = Nokogiri(nav).at('li.dropdown.dropdown-hover:not(.active) > a[href="/things"]')
        expect(a0).to be_a Nokogiri::XML::Element
        expect(a0.text.strip).to eq('Things')
        a1 = Nokogiri(nav).at('li.dropdown.dropdown-hover:not(.active) > li:not(.active) > a[href="/things/stuff"]')
        expect(a1).to be_a Nokogiri::XML::Element
        expect(a1.text.strip).to eq('Stuff')
      end

      it 'returns an active nav link with menu' do
        stub(self).current_page?('/things') { true }
        stub(self).current_page?('/things/stuff') { false }
        nav = nav_link('Things', '/things') { nav_link('Stuff', '/things/stuff') }
        expect(nav).to be_html_safe
        a0 = Nokogiri(nav).at('li.dropdown.dropdown-hover.active > a[href="/things"]')
        expect(a0).to be_a Nokogiri::XML::Element
        expect(a0.text.strip).to eq('Things')
        a1 = Nokogiri(nav).at('li.dropdown.dropdown-hover.active > li:not(.active) > a[href="/things/stuff"]')
        expect(a1).to be_a Nokogiri::XML::Element
        expect(a1.text.strip).to eq('Stuff')
      end

      it 'returns an active nav link with menu when on a child page' do
        stub(self).current_page?('/things') { false }
        stub(self).current_page?('/things/stuff') { true }
        nav = nav_link('Things', '/things') { nav_link('Stuff', '/things/stuff') }
        expect(nav).to be_html_safe
        a0 = Nokogiri(nav).at('li.dropdown.dropdown-hover.active > a[href="/things"]')
        expect(a0).to be_a Nokogiri::XML::Element
        expect(a0.text.strip).to eq('Things')
        a1 = Nokogiri(nav).at('li.dropdown.dropdown-hover.active > li:not(.active) > a[href="/things/stuff"]')
        expect(a1).to be_a Nokogiri::XML::Element
        expect(a1.text.strip).to eq('Stuff')
      end
    end
  end

  describe '#yes_no' do
    it 'returns a label "Yes" if any truthy value is given' do
      [true, Object.new].each { |value|
        label = yes_no(value)
        expect(label).to be_html_safe
        expect(Nokogiri(label).text).to eq 'Yes'
      }
    end

    it 'returns a label "No" if any falsy value is given' do
      [false, nil].each { |value|
        label = yes_no(value)
        expect(label).to be_html_safe
        expect(Nokogiri(label).text).to eq 'No'
      }
    end
  end

  describe '#working' do
    before do
      @agent = agents(:jane_website_agent)
    end

    it 'returns a label "Disabled" if a given agent is disabled' do
      stub(@agent).disabled? { true }
      label = working(@agent)
      expect(label).to be_html_safe
      expect(Nokogiri(label).text).to eq 'Disabled'
    end

    it 'returns a label "Missing Gems" if a given agent has dependencies missing' do
      stub(@agent).dependencies_missing? { true }
      label = working(@agent)
      expect(label).to be_html_safe
      expect(Nokogiri(label).text).to eq 'Missing Gems'
    end

    it 'returns a label "Yes" if a given agent is working' do
      stub(@agent).working? { true }
      label = working(@agent)
      expect(label).to be_html_safe
      expect(Nokogiri(label).text).to eq 'Yes'
    end

    it 'returns a label "No" if a given agent is not working' do
      stub(@agent).working? { false }
      label = working(@agent)
      expect(label).to be_html_safe
      expect(Nokogiri(label).text).to eq 'No'
    end
  end

  describe '#icon_for_service' do
    it 'returns a correct icon tag for Twitter' do
      icon = icon_for_service(:twitter)
      expect(icon).to be_html_safe
      elem = Nokogiri(icon).at('i.fa.fa-twitter')
      expect(elem).to be_a Nokogiri::XML::Element
    end

    it 'returns a correct icon tag for GitHub' do
      icon = icon_for_service(:github)
      expect(icon).to be_html_safe
      elem = Nokogiri(icon).at('i.fa.fa-github')
      expect(elem).to be_a Nokogiri::XML::Element
    end

    it 'returns a correct icon tag for other services' do
      icon = icon_for_service(:'37signals')
      expect(icon).to be_html_safe
      elem = Nokogiri(icon).at('i.fa.fa-lock')
      expect(elem).to be_a Nokogiri::XML::Element
    end
  end
end
