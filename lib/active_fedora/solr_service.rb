require 'rsolr'

module ActiveFedora
  class SolrService
    attr_reader :conn

    def initialize(host, args)
      host = 'http://localhost:8080/solr' unless host
      args = { read_timeout: 120, open_timeout: 120 }.merge(args.dup)
      args[:url] = host
      @conn = RSolr.connect args
    end

    class << self
      def register(host = nil, args = {})
        Thread.current[:solr_service] = new(host, args)
      end

      def reset!
        Thread.current[:solr_service] = nil
      end

      def select_path
        ActiveFedora.solr_config.fetch(:select_path, 'select')
      end

      def instance
        # Register Solr

        unless Thread.current[:solr_service]
          register(ActiveFedora.solr_config[:url], ActiveFedora.solr_config)
        end

        raise SolrNotInitialized unless Thread.current[:solr_service]
        Thread.current[:solr_service]
      end

      def get(query, args = {})
        args = args.merge(q: query, qt: 'standard')
        SolrService.instance.conn.get(select_path, params: args)
      end

      def query(query, args = {})
        result = get(query, args)

        result['response']['docs'].map do |doc|
          ActiveFedora::SolrHit.new(doc)
        end
      end

      def delete(id)
        SolrService.instance.conn.delete_by_id(id, params: { 'softCommit' => true })
      end

      # Get the count of records that match the query
      # @param [String] query a solr query
      # @param [Hash] args arguments to pass through to `args' param of SolrService.query (note that :rows will be overwritten to 0)
      # @return [Integer] number of records matching
      def count(query, args = {})
        args = args.merge(rows: 0)
        SolrService.get(query, args)['response']['numFound'].to_i
      end

      # @param [Hash] doc the document to index
      # @param [Hash] params
      #   :commit => commits immediately
      #   :softCommit => commit to memory, but don't flush to disk
      def add(doc, params = {})
        SolrService.instance.conn.add(doc, params: params)
      end

      def commit
        SolrService.instance.conn.commit
      end
    end
  end # SolrService
  class SolrNotInitialized < StandardError; end
end # ActiveFedora
