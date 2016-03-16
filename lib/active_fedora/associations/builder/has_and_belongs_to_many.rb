module ActiveFedora::Associations::Builder
  class HasAndBelongsToMany < CollectionAssociation #:nodoc:
    self.macro = :has_and_belongs_to_many

    self.valid_options += [:inverse_of]

    def validate_options
      super
      raise "You must specify a predicate for #{name}" unless options[:predicate]
      raise ArgumentError, "Predicate must be a kind of RDF::URI" unless options[:predicate].is_a?(RDF::URI)
    end
  end
end
