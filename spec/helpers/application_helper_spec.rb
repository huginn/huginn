require 'spec_helper'

describe ApplicationHelper do
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
