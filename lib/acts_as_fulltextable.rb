# ActsAsFulltextable
#
# 2008-03-07
# Patched by Artūras Šlajus <x11@arturaz.net> for will_paginate support
require "fulltext_row"

module ActsAsFulltextable
  module ClassMethods
    # Makes a model searchable.
    # Takes a list of fields to use to create the index. It also take an option (:check_for_changes,
    # which defaults to true) to tell the engine wether it should check if the value of a given
    # instance has changed before it actually updates the associated fulltext row.
    # If option :parent_id is not nulled, it is used as the field to be used as the parent of the record,
    # which is useful if you want to limit your queries to a scope.
    #
    def acts_as_fulltextable(*attr_names)
      configuration = { :check_for_changes => true, :parent_id => nil }
      configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)
      configuration[:fields] = attr_names.flatten.uniq.compact
      write_inheritable_attribute 'fulltext_options', configuration
      extend  FulltextableClassMethods
      include FulltextableInstanceMethods
      self.send('after_create', :create_fulltext_record)
      self.send('after_update', :update_fulltext_record)
      self.send('has_one', :fulltext_row, :as => :fulltextable, :dependent => :delete)
    end
  end
  
  module FulltextableClassMethods
    def fulltext_options
      read_inheritable_attribute('fulltext_options')
    end
    def fulltext_fields
      read_inheritable_attribute('fulltext_options')[:fields]
    end

    # Performs full-text search for objects of this class.
    # It takes three options:
    # * limit: maximum number of rows to return. Defaults to 10.
    # * offset: offset to apply to query. Defaults to 0.
    # * page: only available with will_paginate plugin installed.
    # * active_record: wether a ActiveRecord objects should be returned or an Array of [class_name, id]
    #
    def find_fulltext(query, options = {})
      default_options = {:active_record => true}
      options = default_options.merge(options)
      unless options[:page]
        options = {:limit => 10, :offset => 0}.merge(options)
      end
      options[:only] = self.to_s.underscore.to_sym # Only look for object belonging to this class

      FulltextRow.search(query, options)
    end
  end
  
  def self.included(receiver)
    receiver.extend(ClassMethods)
  end
  
  module FulltextableInstanceMethods
    # Creates the fulltext_row record for self
    #
    def create_fulltext_record
      FulltextRow.create(:fulltextable_type => self.class.to_s, :fulltextable_id => self.id, :value => self.fulltext_value, :parent_id => self.parent_id_value)
    end
    
    # Returns the parent_id value or nil if it wasn't set.
    #
    def parent_id_value
      self.class.fulltext_options[:parent_id].nil? ? nil : self.send(self.class.fulltext_options[:parent_id])
    end
    
    # Updates self's fulltext_row record
    #
    def update_fulltext_record
      if self.class.fulltext_options[:check_for_changes]
        row = FulltextRow.find_by_fulltextable_type_and_fulltextable_id(self.class.to_s, self.id)
        # It should never happen, but just in case we haven't got a row for the record, yet, create it instead of updating it.
        if row.nil?
          self.create_fulltext_record
          return
        end
      end
      FulltextRow.update_all(["value = ?, parent_id = ?", self.fulltext_value, self.parent_id_value], ["fulltextable_type = ? AND fulltextable_id = ?", self.class.to_s, self.id]) if !(self.class.fulltext_options[:check_for_changes]) || (row.value != self.fulltext_value) || (self.parent_id_value != row.parent_id)
    end
    
    # Returns self's value created by concatenating fulltext fields for its class
    #
    def fulltext_value
      self.class.fulltext_fields.map {|f| self.send(f)}.join("\n")
    end
  end
end

ActiveRecord::Base.send :include, ActsAsFulltextable
