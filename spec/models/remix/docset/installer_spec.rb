require 'rails_helper'
require 'tmpdir'
require 'fileutils'

describe Remix::Docset::Installer do
  let(:docset_record) do
    Docset.create!(
      name: 'TestDocset',
      display_name: 'Test Docset',
      identifier: 'com.test.docset',
      source: 'official',
      status: 'pending',
      feed_url: 'https://example.com/TestDocset.xml'
    )
  end

  let(:installer) { described_class.new(docset_record) }

  # Build a minimal docset structure on disk for testing
  let(:docset_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(docset_dir) if File.exist?(docset_dir) }

  def create_test_docset_structure(dir)
    bundle_dir = File.join(dir, 'TestDocset.docset', 'Contents')
    docs_dir = File.join(bundle_dir, 'Resources', 'Documents')
    FileUtils.mkdir_p(docs_dir)

    # Info.plist
    File.write(File.join(bundle_dir, 'Info.plist'), <<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleIdentifier</key>
        <string>com.test.docset</string>
        <key>CFBundleName</key>
        <string>Test Docset</string>
        <key>DocSetPlatformFamily</key>
        <string>test</string>
        <key>isDashDocset</key>
        <true/>
      </dict>
      </plist>
    XML

    # SQLite search index
    db_path = File.join(bundle_dir, 'Resources', 'docSet.dsidx')
    db = SQLite3::Database.new(db_path)
    db.execute('CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)')
    db.execute('CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)')
    db.execute("INSERT INTO searchIndex(name, type, path) VALUES ('Array', 'Class', 'Array.html')")
    db.execute("INSERT INTO searchIndex(name, type, path) VALUES ('Array.push', 'Method', 'Array.html#push')")
    db.execute("INSERT INTO searchIndex(name, type, path) VALUES ('String', 'Class', 'String.html')")
    db.execute("INSERT INTO searchIndex(name, type, path) VALUES ('String.length', 'Method', 'String.html#length')")
    db.close

    # HTML documents
    File.write(File.join(docs_dir, 'Array.html'), <<~HTML)
      <html><head><title>Array</title></head>
      <body>
        <h1>Array</h1>
        <p>An ordered collection of elements.</p>
        <a name="//apple_ref/cpp/Method/push" class="dashAnchor"></a>
        <h2 id="push">push</h2>
        <p>Adds one or more elements to the end of the array.</p>
        <code>array.push(element1, element2)</code>
      </body></html>
    HTML

    File.write(File.join(docs_dir, 'String.html'), <<~HTML)
      <html><head><title>String</title></head>
      <body>
        <h1>String</h1>
        <p>A sequence of characters.</p>
        <a name="//apple_ref/cpp/Method/length" class="dashAnchor"></a>
        <h2 id="length">length</h2>
        <p>Returns the number of characters in the string.</p>
      </body></html>
    HTML

    dir
  end

  def create_test_archive(dir)
    create_test_docset_structure(dir)
    archive_path = File.join(dir, 'TestDocset.tgz')
    system('tar', '-czf', archive_path, '-C', dir, 'TestDocset.docset')
    archive_path
  end

  describe '#parse_plist' do
    it 'extracts plist metadata' do
      create_test_docset_structure(docset_dir)
      bundle = File.join(docset_dir, 'TestDocset.docset')

      result = installer.send(:parse_plist, bundle)

      expect(result[:identifier]).to eq('com.test.docset')
      expect(result[:name]).to eq('Test Docset')
      expect(result[:platform_family]).to eq('test')
    end
  end

  describe '#read_search_index' do
    it 'reads all entries from the SQLite index' do
      create_test_docset_structure(docset_dir)
      bundle = File.join(docset_dir, 'TestDocset.docset')

      entries = installer.send(:read_search_index, bundle)

      expect(entries.length).to eq(4)
      names = entries.map { |e| e[:name] }
      expect(names).to include('Array', 'Array.push', 'String', 'String.length')
    end

    it 'includes type and path for each entry' do
      create_test_docset_structure(docset_dir)
      bundle = File.join(docset_dir, 'TestDocset.docset')

      entries = installer.send(:read_search_index, bundle)
      array_entry = entries.find { |e| e[:name] == 'Array' }

      expect(array_entry[:type]).to eq('Class')
      expect(array_entry[:path]).to eq('Array.html')
    end
  end

  describe '#extract_text' do
    it 'extracts readable text from HTML' do
      html = '<html><body><h1>Title</h1><p>Some text</p><script>var x = 1;</script></body></html>'
      text = installer.send(:extract_text, html)

      expect(text).to include('Title')
      expect(text).to include('Some text')
      expect(text).not_to include('var x')
    end
  end

  describe '#chunk_text' do
    it 'returns the text as a single chunk when under limit' do
      text = 'Short text'
      chunks = installer.send(:chunk_text, text, 1000)
      expect(chunks).to eq(['Short text'])
    end

    it 'splits text into chunks when over the token limit' do
      # ~4 chars per token, so 100 tokens = ~400 chars
      text = "Sentence one. " * 50 # ~700 chars = ~175 tokens
      chunks = installer.send(:chunk_text, text, 50)

      expect(chunks.length).to be > 1
      chunks.each do |chunk|
        expect(chunk.length).to be > 0
      end
    end

    it 'handles empty text' do
      chunks = installer.send(:chunk_text, '', 1000)
      expect(chunks).to eq([])
    end
  end

  describe '#estimate_tokens' do
    it 'approximates token count from text length' do
      text = 'Hello world' # 11 chars
      tokens = installer.send(:estimate_tokens, text)
      expect(tokens).to be_between(2, 4)
    end
  end

  describe '#extract_section' do
    it 'extracts full page text when no anchor in path' do
      html = '<html><body><h1>Title</h1><p>Content here</p></body></html>'
      entry = { name: 'Title', type: 'Class', path: 'page.html' }

      section = installer.send(:extract_section, html, entry)
      expect(section).to include('Content here')
    end

    it 'extracts section text when anchor is in path' do
      html = <<~HTML
        <html><body>
          <h1>Main</h1>
          <p>Intro text</p>
          <h2 id="push">push</h2>
          <p>Push method docs</p>
          <h2 id="pop">pop</h2>
          <p>Pop method docs</p>
        </body></html>
      HTML
      entry = { name: 'push', type: 'Method', path: 'Array.html#push' }

      section = installer.send(:extract_section, html, entry)
      expect(section).to include('Push method docs')
    end
  end

  describe '#install!' do
    before do
      # Mock the download step — provide a pre-built archive
      archive_path = create_test_archive(docset_dir)
      allow(installer).to receive(:download_archive).and_return(archive_path)

      # Mock embedding generation
      allow(Remix::Docset::EmbeddingClient).to receive(:embed_batch) do |texts|
        texts.map { Array.new(Remix::Docset::EmbeddingClient.dimensions, 0.1) }
      end

      # Skip the vector column since we're on MySQL in tests
      allow(DocsetChunk).to receive(:column_names).and_return(
        %w[id docset_id docset_page_id entry_name entry_type content chunk_index token_count created_at updated_at]
      )
    end

    it 'processes a docset archive end-to-end' do
      installer.install!

      docset_record.reload
      expect(docset_record.status).to eq('ready')
      expect(docset_record.entry_count).to eq(4)
      expect(docset_record.page_count).to be >= 2
      expect(docset_record.chunk_count).to be >= 2
    end

    it 'creates docset pages from HTML documents' do
      installer.install!

      pages = docset_record.docset_pages
      expect(pages.count).to be >= 2

      array_page = pages.find_by(path: 'Array.html')
      expect(array_page).not_to be_nil
      expect(array_page.title).to be_present
      expect(array_page.html_content).to include('Array')
      expect(array_page.text_content).to be_present
    end

    it 'creates chunks from entries' do
      installer.install!

      chunks = docset_record.docset_chunks
      expect(chunks.count).to be >= 2

      entry_names = chunks.pluck(:entry_name)
      expect(entry_names).to include('Array')
    end

    it 'sets status to error on failure' do
      allow(installer).to receive(:download_archive).and_raise(StandardError, 'Download failed')

      expect {
        installer.install!
      }.to raise_error(StandardError, 'Download failed')

      docset_record.reload
      expect(docset_record.status).to eq('error')
      expect(docset_record.error_message).to include('Download failed')
    end

    it 'updates status through the pipeline stages' do
      statuses = []
      allow(docset_record).to receive(:update!) do |attrs|
        statuses << attrs[:status] if attrs[:status]
        docset_record.assign_attributes(attrs)
        docset_record.save!(validate: false)
      end

      installer.install!

      expect(statuses).to eq(%w[downloading extracting indexing ready])
    end
  end
end
