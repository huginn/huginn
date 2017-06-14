require 'rails_helper'

describe ApplicationHelper do
  describe '#icon_tag' do
    it 'returns a Glyphicon icon element' do
      icon = icon_tag('glyphicon-help')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('span.glyphicon.glyphicon-help')).to be_a Nokogiri::XML::Element
    end

    it 'returns a Glyphicon icon element with an addidional class' do
      icon = icon_tag('glyphicon-help', class: 'text-info')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('span.glyphicon.glyphicon-help.text-info')).to be_a Nokogiri::XML::Element
    end

    it 'returns a FontAwesome icon element' do
      icon = icon_tag('fa-copy')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('i.fa.fa-copy')).to be_a Nokogiri::XML::Element
    end

    it 'returns a FontAwesome icon element' do
      icon = icon_tag('fa-copy', class: 'text-info')
      expect(icon).to be_html_safe
      expect(Nokogiri(icon).at('i.fa.fa-copy.text-info')).to be_a Nokogiri::XML::Element
    end
  end

  describe '#nav_link' do
    it 'returns a nav link' do
      stub(self).current_page?('/things') { false }
      nav = nav_link('Things', '/things')
      a = Nokogiri(nav).at('li:not(.active) > a[href="/things"]')
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

  describe '#omniauth_provider_icon' do
    it 'returns a correct icon tag for Twitter' do
      icon = omniauth_provider_icon(:twitter)
      expect(icon).to be_html_safe
      elem = Nokogiri(icon).at('i.fa.fa-twitter')
      expect(elem).to be_a Nokogiri::XML::Element
    end

    it 'returns a correct icon tag for GitHub' do
      icon = omniauth_provider_icon(:github)
      expect(icon).to be_html_safe
      elem = Nokogiri(icon).at('i.fa.fa-github')
      expect(elem).to be_a Nokogiri::XML::Element
    end

    it 'returns a correct icon tag for other services' do
      icon = omniauth_provider_icon(:'37signals')
      expect(icon).to be_html_safe
      elem = Nokogiri(icon).at('i.fa.fa-lock')
      expect(elem).to be_a Nokogiri::XML::Element
    end
  end

  describe '#highlighted?' do
    it 'understands hl=6-8' do
      stub(params).[](:hl) { '6-8' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [6, 7, 8]
    end

    it 'understands hl=1,3-4,9' do
      stub(params).[](:hl) { '1,3-4,9' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [1, 3, 4, 9]
    end

    it 'understands hl=8-' do
      stub(params).[](:hl) { '8-' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [8, 9, 10]
    end

    it 'understands hl=-2' do
      stub(params).[](:hl) { '-2' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [1, 2]
    end

    it 'understands hl=-' do
      stub(params).[](:hl) { '-' }
      expect((1..10).select { |i| highlighted?(i) }).to eq [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end

    it 'is OK with no hl' do
      stub(params).[](:hl) { nil }
      expect((1..10).select { |i| highlighted?(i) }).to be_empty
    end
  end
end
