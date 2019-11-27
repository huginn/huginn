require 'feedjira'
require 'digest'
require 'mail'

module FeedjiraExtension
  AUTHOR_ATTRS = %i[name email uri]
  LINK_ATTRS = %i[href rel type hreflang title length]
  ENCLOSURE_ATTRS = %i[url type length]

  class Author < Struct.new(*AUTHOR_ATTRS)
    def empty?
      all?(&:nil?)
    end

    def to_json(options = nil)
      each_pair.flat_map { |key, value|
        if value.presence
          case key
          when :email
            "<#{value}>"
          when :uri
            "(#{value})"
          else
            value
          end
        else
          []
        end
      }.join(' ').to_json(options)
    end
  end

  class AtomAuthor < Author
    include SAXMachine

    AUTHOR_ATTRS.each do |attr|
      element attr
    end
  end

  class RssAuthor < Author
    include SAXMachine

    def content=(content)
      @content = content

      begin
        addr = Mail::Address.new(content)
      rescue
        self.name = content
      else
        self.name = addr.name rescue nil
        self.email = addr.address rescue nil
      end
    end

    value :content
  end

  class ITunesRssOwner < Author
    include SAXMachine

    element :'itunes:name', as: :name
    element :'itunes:email', as: :email
  end

  class Enclosure
    include SAXMachine

    ENCLOSURE_ATTRS.each do |attr|
      attribute attr
    end

    def to_json(options = nil)
      ENCLOSURE_ATTRS.each_with_object({}) { |key, hash|
        if value = __send__(key)
          hash[key] = value
        end
      }.to_json(options)
    end
  end

  class AtomLink
    include SAXMachine

    LINK_ATTRS.each do |attr|
      attribute attr
    end

    def empty?
      LINK_ATTRS.all? { |attr|
        __send__(attr).nil?
      }
    end

    def to_json(options = nil)
      LINK_ATTRS.each_with_object({}) { |key, hash|
        if value = __send__(key)
          hash[key] = value
        end
      }.to_json(options)
    end
  end

  class RssLinkElement
    include SAXMachine

    value :href

    def empty?
      !href.is_a?(String)
    end

    def to_json(options = nil)
      case href
      when String
        { href: href }
      else
        # Ignore non-string values, because SaxMachine leaks its
        # internal value :no_buffer when the content of an element
        # is empty.
        {}
      end.to_json(options)
    end
  end

  module HasAuthors
    def self.included(mod)
      mod.module_exec do
        case name
        when /RSS/
          %w[
            itunes:author
            dc:creator
            author
            managingEditor
          ].each do |name|
            sax_config.top_level_elements[name].clear

            elements name, class: RssAuthor, as: :_authors
          end
        else
          elements :author, class: AtomAuthor, as: :_authors
        end

        def authors
          _authors.reject(&:empty?)
        end
      end
    end
  end

  module HasEnclosure
    def self.included(mod)
      mod.module_exec do
        sax_config.top_level_elements['enclosure'].clear

        element :enclosure, class: Enclosure

        def image_enclosure
          case enclosure.try!(:type)
          when %r{\Aimage/}
            enclosure
          end
        end

        def image
          @image ||= image_enclosure.try!(:url)
        end
      end
    end
  end

  module HasLinks
    def self.included(mod)
      mod.module_exec do
        sax_config.top_level_elements['link'].clear
        sax_config.collection_elements['link'].clear

        case name
        when /RSS/
          elements :link, class: RssLinkElement, as: :rss_links

          case name
          when /FeedBurner/
            elements :'atok10:link', class: AtomLink, as: :atom_links

            def _links
              [*rss_links, *atom_links]
            end
          else
            alias_method :_links, :rss_links
          end

          prepend(
            Module.new {
              def url
                super || (alternate_link || links.first).try!(:href)
              end
            }
          )
        when /Atom/
          elements :link, class: AtomLink, as: :_links

          def url
            (alternate_link || links.first).try!(:href)
          end
        end

        def links
          _links.reject(&:empty?)
        end

        def alternate_link
          links.find { |link|
            link.is_a?(AtomLink) &&
              link.rel == 'alternate' &&
              (link.type == 'text/html'|| link.type.nil?)
          }
        end
      end
    end
  end

  module HasTimestamps
    attr_reader :published, :updated

    # Keep the "oldest" publish time found
    def published=(value)
      parsed = parse_datetime(value)
      @published = parsed if !@published || parsed < @published
    end

    # Keep the most recent update time found
    def updated=(value)
      parsed = parse_datetime(value)
      @updated = parsed if !@updated || parsed > @updated
    end

    def date_published
      published.try(:iso8601)
    end

    def last_updated
      (updated || published).try(:iso8601)
    end

    private

    def parse_datetime(string)
      DateTime.parse(string) rescue nil
    end
  end

  module FeedEntryExtensions
    def self.included(mod)
      mod.module_exec do
        include HasAuthors
        include HasEnclosure
        include HasLinks
        include HasTimestamps
      end
    end

    def id
      entry_id || Digest::MD5.hexdigest(content || summary || '')
    end
  end

  module FeedExtensions
    def self.included(mod)
      mod.module_exec do
        include HasAuthors
        include HasEnclosure
        include HasLinks
        include HasTimestamps

        element  :id, as: :feed_id
        element  :generator
        elements :rights
        element  :published
        element  :updated
        element  :icon

        if /RSS/ === name
          element :guid, as: :feed_id
          element :copyright
          element :pubDate, as: :published
          element :'dc:date', as: :published
          element :lastBuildDate, as: :updated
          element :image, value: :url, as: :icon

          def copyright
            @copyright || super
          end

          if /ITunes/ === name
            sax_config.collection_elements['itunes:owner'].clear
            elements :"itunes:owner", as: :_itunes_owners, class: ITunesRssOwner
            private :_itunes_owners

            def itunes_owners
              _itunes_owners.reject(&:empty?)
            end
          end
        else
          element :subtitle, as: :description unless method_defined?(:description)
        end

        sax_config.collection_elements.each_value do |collection_elements|
          collection_elements.each do |collection_element|
            collection_element.accessor == 'entries' &&
              (entry_class = collection_element.data_class).is_a?(Class) or next

            entry_class.send :include, FeedEntryExtensions
          end
        end
      end
    end

    def copyright
      rights.join("\n").presence
    end
  end

  Feedjira.parsers.each do |feed_class|
    feed_class.send :include, FeedExtensions
  end
end
