require 'active_support/descendants_tracker'
require 'active_fedora/errors'
require 'active_fedora/log_subscriber'

module ActiveFedora
  # This class ties together many of the lower-level modules, and
  # implements something akin to an ActiveRecord-alike interface to
  # fedora. If you want to represent a fedora object in the ruby
  # space, this is the class you want to extend.
  #
  class Base
    extend ActiveModel::Naming
    extend ActiveSupport::DescendantsTracker
    extend LdpCache::ClassMethods

    include Core
    include Identifiable
    include Persistence
    include Indexing
    include Scoping
    include ActiveModel::Conversion
    include Callbacks
    include Validations
    extend Querying
    include Associations
    include AutosaveAssociation
    include NestedAttributes
    include Reflection
    include Serialization

    include AttachedFiles
    include FedoraAttributes
    include AttributeMethods
    include Attributes
    include Versionable
    include LoadableFromJson
    include Schema
    include Pathing
  end

  ActiveSupport.run_load_hooks(:active_fedora, Base)
end
