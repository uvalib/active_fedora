module ActiveFedora
  class EverythingContainerConnection < SimpleDelegator
    def put(*args)
      result = __getobj__.put(*args) do |req|
        begin
          turtle_result = ::RDF::Reader.for(:ttl).new(args.last, validate: true)
          statements = turtle_result.to_a
          if statements.length > 0
            rdf_subject = ::RDF::URI.new(args.first)
            g = ::RDF::Graph.new
            g << statements
            results = g.query([rdf_subject, ::RDF.type, nil])
            if results.objects.to_a.include?(::RDF::Vocab::LDP.IndirectContainer)
              req.headers["Link"] = "<http://www.w3.org/ns/ldp#IndirectContainer>;rel=\"type\""
            end
          else
            req.headers["Link"] = "<http://www.w3.org/ns/ldp#Container>;rel=\"type\""
          end
        rescue ::RDF::ReaderError
          req.headers["Link"] = "<http://www.w3.org/ns/ldp#NonRDFSource>;rel=\"type\""
        end
      end
      result
    end
  end
end
