module ActiveFedora
  module FinderMethods
    # Returns the first records that was found.
    #
    # @example
    #  Person.where(name_t: 'Jones').first
    #    => #<Person @id="foo:123" @name='Jones' ... >
    def first
      if loaded?
        @records.first
      else
        @first ||= limit(1).to_a[0]
      end
    end

    # Returns the last record sorted by id.  ID was chosen because this mimics
    # how ActiveRecord would achieve the same behavior.
    #
    # @example
    #  Person.where(name_t: 'Jones').last
    #    => #<Person @id="foo:123" @name='Jones' ... >
    def last
      if loaded?
        @records.last
      else
        @last ||= order('id desc').limit(1).to_a[0]
      end
    end

    # Returns an Array of objects of the Class that +find+ is being
    # called on
    #
    # @param[String,Hash] args either an id or a hash of conditions
    # @option args [Integer] :rows when :all is passed, the maximum number of rows to load from solr
    # @option args [Boolean] :cast when true, examine the model and cast it to the first known cModel
    def find(*args)
      return to_a.find { |*block_args| yield(*block_args) } if block_given?
      options = args.extract_options!
      options = options.dup
      cast = if @klass == ActiveFedora::Base && !options.key?(:cast)
               true
             else
               options.delete(:cast)
             end
      if options[:sort]
        # Deprecate sort sometime?
        sort = options.delete(:sort)
        options[:order] ||= sort if sort.present?
      end

      if options.present?
        options = args.first unless args.empty?
        Deprecation.warn(ActiveFedora::Base, "Calling .find with a hash has been deprecated and will not be allowed in active-fedora 10.0. Use .where instead")
        options = { conditions: options }
        apply_finder_options(options)
      else
        raise ArgumentError, "#{self}.find() expects an id. You provided `#{args.inspect}'" unless args.is_a? Array
        find_with_ids(args, cast)
      end
    end

    # Gives a record (or N records if a parameter is supplied) without any implied
    # order. The order will depend on the database implementation.
    # If an order is supplied it will be respected.
    #
    #   Person.take # returns an object fetched by SELECT * FROM people LIMIT 1
    #   Person.take(5) # returns 5 objects fetched by SELECT * FROM people LIMIT 5
    #   Person.where(["name LIKE '%?'", name]).take
    def take(limit = nil)
      limit ? limit(limit).to_a : find_take
    end

    def find_take
      if loaded?
        @records.first
      else
        @take ||= limit(1).to_a.first
      end
    end

    # Returns true if object having the id or matching the conditions exists in the repository
    # Returns false if param is false (or nil)
    # @param[ActiveFedora::Base, String, Hash] object, id or hash of conditions
    # @return[boolean]
    def exists?(conditions)
      conditions = conditions.id if Base === conditions
      return false unless conditions
      case conditions
      when Hash
        search_with_conditions(conditions, rows: 1).present?
      when String
        find(conditions).present?
      else
        raise ArgumentError, "`conditions' argument must be ActiveFedora::Base, String, or Hash: #{conditions.inspect}"
      end
    rescue ActiveFedora::ObjectNotFoundError, Ldp::Gone
      false
    end

    # Returns a solr result matching the supplied conditions
    # @param[Hash,String] conditions can either be specified as a string, or
    # hash representing the query part of an solr statement. If a hash is
    # provided, this method will generate conditions based simple equality
    # combined using the boolean AND operator.
    # @param [Hash] options
    # @option opts [Array] :sort a list of fields to sort by
    # @option opts [Array] :rows number of rows to return
    def search_with_conditions(conditions, opts = {})
      # set default sort to created date ascending
      opts[:sort] = @klass.default_sort_params unless opts.include?(:sort)
      SolrService.query(create_query(conditions), opts)
    end

    # Returns a single solr hit matching the given id
    # @param [String] id document id
    # @param [Hash] opts
    def search_by_id(id, opts = {})
      opts[:rows] = 1
      result = search_with_conditions({ id: id }, opts)

      if result.empty?
        raise ActiveFedora::ObjectNotFoundError, "Object #{id} not found in solr"
      end

      result.first
    end

    # @deprecated
    def find_with_conditions(*args)
      Deprecation.warn(ActiveFedora::Base, '.find_with_conditions is deprecated and will be removed in active-fedora 10.0; use .search_with_conditions instead')
      search_with_conditions(*args)
    end

    # Yields the found ActiveFedora::Base object to the passed block
    #
    # @param [Hash] conditions the conditions for the solr search to match
    # @param [Hash] opts
    # @option opts [Boolean] :cast (true) when true, examine the model and cast it to the first known cModel
    def find_each(conditions = {}, opts = {})
      cast = opts.delete(:cast)
      search_in_batches(conditions, opts.merge(fl: ActiveFedora.id_field)) do |group|
        group.each do |hit|
          begin
            yield(load_from_fedora(hit[ActiveFedora.id_field], cast))
          rescue Ldp::Gone
            ActiveFedora::Base.logger.error "Although #{hit[ActiveFedora.id_field]} was found in Solr, it doesn't seem to exist in Fedora. The index is out of synch." if ActiveFedora::Base.logger
          end
        end
      end
    end

    # Yields each batch of solr records that was found by the find +options+ as
    # an array. The size of each batch is set by the <tt>:batch_size</tt>
    # option; the default is 1000.
    #
    # Returns a solr result matching the supplied conditions
    # @param[Hash] conditions solr conditions to match
    # @param[Hash] options
    # @option opts [Array] :sort a list of fields to sort by
    # @option opts [Array] :rows number of rows to return
    #
    # @example
    #  Person.search_in_batches('age_t'=>'21', {:batch_size=>50}) do |group|
    #  group.each { |person| puts person['name_t'] }
    #  end
    def search_in_batches(conditions, opts = {})
      opts[:q] = create_query(conditions)
      opts[:qt] = @klass.solr_query_handler
      # set default sort to created date ascending
      opts[:sort] = @klass.default_sort_params unless opts[:sort].present?

      batch_size = opts.delete(:batch_size) || 1000
      select_path = ActiveFedora::SolrService.select_path

      counter = 0
      loop do
        counter += 1
        response = ActiveFedora::SolrService.instance.conn.paginate counter, batch_size, select_path, params: opts
        docs = response["response"]["docs"]
        yield docs
        break unless docs.has_next?
      end
    end

    # @deprecated
    def find_in_batches(*args)
      Deprecation.warn(ActiveFedora::Base, '.find_in_batches is deprecated and will be removed in active-fedora 10.0; use .search_in_batches instead')
      search_in_batches(*args)
    end

    # Retrieve the Fedora object with the given id, explore the returned object
    # Raises a ObjectNotFoundError if the object is not found.
    # @param [String] id of the object to load
    # @param [Boolean] cast when true, cast the found object to the class of the first known model defined in it's RELS-EXT
    #
    # @example because the object hydra:dataset1 asserts it is a Dataset (hasModel http://fedora.info/definitions/v4/model#Dataset), return a Dataset object (not a Book).
    #   Book.find_one("hydra:dataset1")
    def find_one(id, cast = nil)
      if where_values.empty?
        load_from_fedora(id, cast)
      else
        conditions = where_values + [ActiveFedora::SolrQueryBuilder.construct_query(ActiveFedora.id_field => id)]
        query = conditions.join(" AND ".freeze)
        to_enum(:find_each, query, {}).to_a.first
      end
    end

    protected

      def load_from_fedora(id, cast)
        raise ActiveFedora::ObjectNotFoundError if id.empty?
        resource = ActiveFedora.fedora.ldp_resource_service.build(klass, id)
        raise ActiveFedora::ObjectNotFoundError if resource.new?
        class_to_load(resource, cast).allocate.init_with_resource(resource) # Triggers the find callback
      end

      def class_to_load(resource, cast)
        if @klass == ActiveFedora::Base && cast == false
          ActiveFedora::Base
        else
          resource_class = has_model_value(resource)
          unless equivalent_class?(resource_class)
            raise ActiveFedora::ActiveFedoraError, "Model mismatch. Expected #{@klass}. Got: #{resource_class}"
          end
          resource_class
        end
      end

      def has_model_value(resource)
        ActiveFedora.model_mapper.classifier(resource).best_model
      end

      def equivalent_class?(other_class)
        other_class <= @klass
      end

      def find_with_ids(ids, cast)
        expects_array = ids.first.is_a?(Array)
        return ids.first if expects_array && ids.first.empty?

        ids = ids.flatten.compact.uniq

        case ids.size
        when 0
          raise ArgumentError, "Couldn't find #{@klass.name} without an ID"
        when 1
          result = find_one(ids.first, cast)
          expects_array ? [result] : result
        else
          find_some(ids, cast)
        end
      end

      def find_some(ids, cast)
        ids.map { |id| find_one(id, cast) }
      end

    private

      # Returns a solr query for the supplied conditions
      # @param[Hash,String,Array] conditions solr conditions to match
      def create_query(conditions)
        build_query(build_where(conditions))
      end

      # @param [Array<String>] conditions
      def build_query(conditions)
        clauses = search_model_clause ? [search_model_clause] : []
        clauses += conditions.reject(&:blank?)
        return "*:*" if clauses.empty?
        clauses.compact.join(" AND ")
      end

      # @param [Hash<Symbol,String>] conditions
      # @return [Array<String>]
      def create_query_from_hash(conditions)
        conditions.map { |key, value| condition_to_clauses(key, value) }.compact
      end

      # @param [Symbol] key
      # @param [String] value
      def condition_to_clauses(key, value)
        SolrQueryBuilder.construct_query([[field_name_for(key), value]])
      end

      # If the key is a property name, turn it into a solr field
      # @param [Symbol] key
      # @return [String]
      def field_name_for(key)
        if @klass.delegated_attributes.key?(key)
          # TODO: Check to see if `key' is a possible solr field for this class, if it isn't try :searchable instead
          ActiveFedora.index_field_mapper.solr_name(key, :stored_searchable, type: :string)
        elsif key == :id
          ActiveFedora.id_field
        else
          key.to_s
        end
      end

      # Return the solr clause that queries for this type of class
      def search_model_clause
        # The concrete class could could be any subclass of @klass or @klass itself
        return if @klass == ActiveFedora::Base
        clauses = ([@klass] + @klass.descendants).map do |k|
          ActiveFedora::SolrQueryBuilder.construct_query_for_rel(has_model: k.to_s)
        end
        clauses.size == 1 ? clauses.first : "(#{clauses.join(' OR ')})"
      end
  end
end
