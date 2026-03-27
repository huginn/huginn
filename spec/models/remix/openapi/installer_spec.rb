require 'rails_helper'

describe Remix::Openapi::Installer do
  let(:docset_record) do
    Docset.create!(
      name: 'stripe.com',
      display_name: 'Stripe API',
      identifier: 'openapi:stripe.com',
      source: 'openapi',
      status: 'pending',
      feed_url: 'https://api.apis.guru/v2/specs/stripe.com/2022-11-15/openapi.json'
    )
  end

  let(:installer) { described_class.new(docset_record) }

  # A minimal but realistic OpenAPI 3.0 spec
  let(:openapi_spec) do
    {
      openapi: '3.0.0',
      info: {
        title: 'Stripe API',
        description: 'The Stripe REST API.',
        version: '2022-11-15'
      },
      servers: [{ url: 'https://api.stripe.com' }],
      paths: {
        '/v1/charges' => {
          get: {
            summary: 'List all charges',
            operationId: 'ListCharges',
            description: 'Returns a list of charges you have previously created.',
            tags: ['Charges'],
            parameters: [
              {
                name: 'limit',
                in: 'query',
                required: false,
                description: 'A limit on the number of objects to be returned.',
                schema: { type: 'integer' }
              },
              {
                name: 'customer',
                in: 'query',
                required: false,
                description: 'Only return charges for the customer specified by this customer ID.',
                schema: { type: 'string' }
              }
            ],
            responses: {
              '200' => {
                description: 'Successful response.',
                content: {
                  'application/json' => {
                    schema: { '$ref' => '#/components/schemas/ChargeList' }
                  }
                }
              }
            }
          },
          post: {
            summary: 'Create a charge',
            operationId: 'CreateCharge',
            description: 'Creates a new charge object.',
            tags: ['Charges'],
            requestBody: {
              required: true,
              content: {
                'application/x-www-form-urlencoded' => {
                  schema: {
                    type: 'object',
                    properties: {
                      amount: {
                        type: 'integer',
                        description: 'Amount intended to be collected by this payment.'
                      },
                      currency: {
                        type: 'string',
                        description: 'Three-letter ISO currency code.'
                      }
                    },
                    required: ['amount', 'currency']
                  }
                }
              }
            },
            responses: {
              '200' => {
                description: 'Successful response.',
                content: {
                  'application/json' => {
                    schema: { '$ref' => '#/components/schemas/Charge' }
                  }
                }
              }
            }
          }
        },
        '/v1/charges/{id}' => {
          get: {
            summary: 'Retrieve a charge',
            operationId: 'GetCharge',
            description: 'Retrieves the details of a charge that has previously been created.',
            tags: ['Charges'],
            parameters: [
              {
                name: 'id',
                in: 'path',
                required: true,
                description: 'The identifier of the charge to be retrieved.',
                schema: { type: 'string' }
              }
            ],
            responses: {
              '200' => {
                description: 'Successful response.',
                content: {
                  'application/json' => {
                    schema: { '$ref' => '#/components/schemas/Charge' }
                  }
                }
              }
            }
          }
        },
        '/v1/customers' => {
          get: {
            summary: 'List all customers',
            operationId: 'ListCustomers',
            description: 'Returns a list of your customers.',
            tags: ['Customers'],
            parameters: [],
            responses: {
              '200' => {
                description: 'Successful response.'
              }
            }
          }
        }
      },
      components: {
        schemas: {
          Charge: {
            type: 'object',
            description: 'The Charge object represents a single attempt to move money into your Stripe account.',
            properties: {
              id: { type: 'string', description: 'Unique identifier for the object.' },
              amount: { type: 'integer', description: 'Amount in cents.' },
              currency: { type: 'string', description: 'Three-letter ISO currency code.' },
              status: {
                type: 'string',
                enum: ['succeeded', 'pending', 'failed'],
                description: 'The status of the payment.'
              },
              customer: {
                type: 'string',
                description: 'ID of the customer this charge is for if one exists.',
                nullable: true
              }
            }
          },
          ChargeList: {
            type: 'object',
            description: 'A list of charges.',
            properties: {
              data: {
                type: 'array',
                items: { '$ref' => '#/components/schemas/Charge' },
                description: 'The list of charge objects.'
              },
              has_more: { type: 'boolean', description: 'Whether there are more results.' }
            }
          },
          Customer: {
            type: 'object',
            description: 'Customer objects allow you to perform recurring charges.',
            properties: {
              id: { type: 'string', description: 'Unique identifier for the object.' },
              email: { type: 'string', description: "Customer's email address." },
              name: { type: 'string', description: "Customer's full name.", nullable: true }
            }
          }
        }
      }
    }.deep_stringify_keys
  end

  before do
    # Skip embedding column since MySQL in tests
    allow(DocsetChunk).to receive(:column_names).and_return(
      %w[id docset_id docset_page_id entry_name entry_type content chunk_index token_count created_at updated_at]
    )

    # Mock embedding generation
    allow(Remix::Docset::EmbeddingClient).to receive(:embed_batch) do |texts|
      texts.map { Array.new(Remix::Docset::EmbeddingClient.dimensions, 0.1) }
    end
  end

  describe '#render_endpoint_text' do
    it 'renders a GET endpoint with parameters' do
      operation = openapi_spec.dig('paths', '/v1/charges', 'get')
      text = installer.send(:render_endpoint_text, 'GET', '/v1/charges', operation)

      expect(text).to include('GET /v1/charges')
      expect(text).to include('List all charges')
      expect(text).to include('Returns a list of charges')
      expect(text).to include('limit')
      expect(text).to include('query')
      expect(text).to include('integer')
    end

    it 'renders a POST endpoint with request body' do
      operation = openapi_spec.dig('paths', '/v1/charges', 'post')
      text = installer.send(:render_endpoint_text, 'POST', '/v1/charges', operation)

      expect(text).to include('POST /v1/charges')
      expect(text).to include('Create a charge')
      expect(text).to include('amount')
      expect(text).to include('currency')
      expect(text).to include('required')
    end

    it 'includes path parameters' do
      operation = openapi_spec.dig('paths', '/v1/charges/{id}', 'get')
      text = installer.send(:render_endpoint_text, 'GET', '/v1/charges/{id}', operation)

      expect(text).to include('GET /v1/charges/{id}')
      expect(text).to include('id')
      expect(text).to include('path')
      expect(text).to include('required')
    end
  end

  describe '#render_schema_text' do
    it 'renders a schema with properties' do
      schema = openapi_spec.dig('components', 'schemas', 'Charge')
      text = installer.send(:render_schema_text, 'Charge', schema)

      expect(text).to include('Schema: Charge')
      expect(text).to include('single attempt to move money')
      expect(text).to include('id')
      expect(text).to include('amount')
      expect(text).to include('currency')
      expect(text).to include('status')
    end

    it 'includes enum values' do
      schema = openapi_spec.dig('components', 'schemas', 'Charge')
      text = installer.send(:render_schema_text, 'Charge', schema)

      expect(text).to include('succeeded')
      expect(text).to include('pending')
      expect(text).to include('failed')
    end

    it 'notes nullable properties' do
      schema = openapi_spec.dig('components', 'schemas', 'Charge')
      text = installer.send(:render_schema_text, 'Charge', schema)

      expect(text).to include('nullable')
    end
  end

  describe '#install!' do
    before do
      # Mock the spec download
      allow(installer).to receive(:download_spec).and_return(openapi_spec)
    end

    it 'processes an OpenAPI spec end-to-end' do
      installer.install!

      docset_record.reload
      expect(docset_record.status).to eq('ready')
      expect(docset_record.entry_count).to be > 0
      expect(docset_record.page_count).to be > 0
      expect(docset_record.chunk_count).to be > 0
    end

    it 'creates pages for endpoints' do
      installer.install!

      pages = docset_record.docset_pages
      endpoint_pages = pages.where("entry_type != 'Schema' OR entry_type IS NULL")

      # 4 endpoints: GET /v1/charges, POST /v1/charges, GET /v1/charges/{id}, GET /v1/customers
      expect(endpoint_pages.count).to eq(4)
    end

    it 'creates pages for component schemas' do
      installer.install!

      schema_pages = docset_record.docset_pages.where(entry_type: 'Schema')
      expect(schema_pages.count).to eq(3) # Charge, ChargeList, Customer

      charge_page = schema_pages.find_by("path LIKE '%Charge' OR path = 'schema:Charge'")
      expect(charge_page).not_to be_nil
    end

    it 'creates chunks with content' do
      installer.install!

      chunks = docset_record.docset_chunks
      expect(chunks.count).to be >= 4 # At least one chunk per endpoint/schema

      # Verify chunks have meaningful content
      chunks.each do |chunk|
        expect(chunk.content).to be_present
        expect(chunk.entry_name).to be_present
        expect(chunk.token_count).to be > 0
      end
    end

    it 'stores endpoint text in page text_content' do
      installer.install!

      charge_page = docset_record.docset_pages.find_by(path: 'GET /v1/charges')
      expect(charge_page).not_to be_nil
      expect(charge_page.text_content).to include('List all charges')
      expect(charge_page.title).to be_present
    end

    it 'updates status through pipeline stages' do
      statuses = []
      allow(docset_record).to receive(:update!) do |attrs|
        statuses << attrs[:status] if attrs[:status]
        docset_record.assign_attributes(attrs)
        docset_record.save!(validate: false)
      end

      installer.install!

      expect(statuses).to eq(%w[downloading extracting indexing ready])
    end

    it 'sets status to error on failure' do
      allow(installer).to receive(:download_spec).and_raise(StandardError, 'Download failed')

      expect {
        installer.install!
      }.to raise_error(StandardError, 'Download failed')

      docset_record.reload
      expect(docset_record.status).to eq('error')
      expect(docset_record.error_message).to include('Download failed')
    end

    it 'stores the API version on the docset record' do
      installer.install!

      docset_record.reload
      expect(docset_record.version).to eq('2022-11-15')
    end
  end

  describe '#chunk_text' do
    it 'returns text as single chunk when under limit' do
      text = 'Short text'
      chunks = installer.send(:chunk_text, text, 1000)
      expect(chunks).to eq(['Short text'])
    end

    it 'splits long text into multiple chunks' do
      text = "Sentence one. " * 50
      chunks = installer.send(:chunk_text, text, 50)

      expect(chunks.length).to be > 1
      chunks.each { |c| expect(c.length).to be > 0 }
    end

    it 'handles empty text' do
      chunks = installer.send(:chunk_text, '', 1000)
      expect(chunks).to eq([])
    end
  end

  describe 'spec with no paths' do
    let(:empty_spec) do
      {
        'openapi' => '3.0.0',
        'info' => { 'title' => 'Empty API', 'version' => '1.0' },
        'paths' => {}
      }
    end

    before do
      allow(installer).to receive(:download_spec).and_return(empty_spec)
    end

    it 'handles empty paths gracefully' do
      installer.install!

      docset_record.reload
      expect(docset_record.status).to eq('ready')
      expect(docset_record.entry_count).to eq(0)
    end
  end

  describe 'spec with no components' do
    let(:no_components_spec) do
      {
        'openapi' => '3.0.0',
        'info' => { 'title' => 'Simple API', 'version' => '1.0' },
        'paths' => {
          '/health' => {
            'get' => {
              'summary' => 'Health check',
              'description' => 'Returns OK if service is healthy.',
              'responses' => { '200' => { 'description' => 'OK' } }
            }
          }
        }
      }
    end

    before do
      allow(installer).to receive(:download_spec).and_return(no_components_spec)
    end

    it 'handles specs without components' do
      installer.install!

      docset_record.reload
      expect(docset_record.status).to eq('ready')
      expect(docset_record.page_count).to eq(1)
    end
  end
end
