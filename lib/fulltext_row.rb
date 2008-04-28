# FulltextRow
#
# 2008-03-07
# Patched by Artūras Šlajus <x11@arturaz.net> for will_paginate support
class FulltextRow < ActiveRecord::Base
  # If FULLTEXT_ROW_TABLE is set, use it as the table name
  begin
    set_table_name FULLTEXT_ROW_TABLE if Object.const_get('FULLTEXT_ROW_TABLE')
  rescue
  end
  belongs_to  :fulltextable,
              :polymorphic => true
  validates_presence_of   :fulltextable_type, :fulltextable_id
  validates_uniqueness_of :fulltextable_id,
                          :scope => :fulltextable_type
  # Performs full-text search.
  # It takes four options:
  # * limit: maximum number of rows to return (use 0 for all). Defaults to 10.
  # * offset: offset to apply to query. Defaults to 0.
  # * page: only available with will_paginate.
  # * active_record: wether a ActiveRecord objects should be returned or an Array of [class_name, id]
  # * only: limit search to these classes. Defaults to all classes. (should be a symbol or an Array of symbols)
  #
  def self.search(query, options = {})
    default_options = {:active_record => true, :parent_id => nil}
    options = default_options.merge(options)
    unless options[:page]
      options = {:limit => 10, :offset => 0}.merge(options)
      options[:offset] = 0 if options[:offset] < 0
      options[:limit] = 10 if options[:limit] < 0
      options[:limit] = nil if options[:limit] == 0
    end
    options[:only] = [options[:only]] unless options[:only].nil? || options[:only].is_a?(Array)
    options[:only] = options[:only].map {|o| o.to_s.camelize}.uniq.compact unless options[:only].nil?

    rows = raw_search(query, options[:only], options[:limit], options[:offset], options[:parent_id], options[:page])
    if options[:active_record]
      types = {}
      rows.each {|r| types.include?(r.fulltextable_type) ? (types[r.fulltextable_type] << r.fulltextable_id) : (types[r.fulltextable_type] = [r.fulltextable_id])}
      objects = {}
      types.each {|k, v| objects[k] = Object.const_get(k).find(v)}
      objects.each {|k, v| v.sort! {|x, y| types[k].index(x.id) <=> types[k].index(y.id)}}

      if defined?(WillPaginate)
        result = WillPaginate::Collection.new(
          rows.current_page,
          rows.per_page,
          rows.total_entries
        )
      else
        result = []
      end

      rows.each {|r| result << objects[r.fulltextable_type].shift}
      return result
    else
      return rows.map {|r| [r.fulltextable_type, r.fulltextable_id]}
    end
  end
  
private
  # Performs a raw full-text search.
  # * query: string to be searched
  # * only: limit search to these classes. Defaults to all classes.
  # * limit: maximum number of rows to return (use 0 for all). Defaults to 10.
  # * offset: offset to apply to query. Defaults to 0.
  # * parent_id: limit query to record with passed parent_id. An Array of ids is fine.
  # * page: overrides limit and offset, only available with will_paginate.
  #
  def self.raw_search(query, only, limit, offset, parent_id = nil, page = nil)
    unless only.nil? || only.empty?
      only_condition = " AND fulltextable_type IN (#{only.map {|c| (/\A\w+\Z/ === c.to_s) ? "'#{c.to_s}'" : nil}.uniq.compact.join(',')})"
    else
      only_condition = ''
    end
    unless parent_id.nil?
      if parent_id.is_a?(Array)
        only_condition += " AND parent_id IN (#{parent_id.join(',')})"
      else
        only_condition += " AND parent_id = #{parent_id.to_i}"
      end
    end

    query = query.gsub(/(\S+)/, '\1*')
    search_options = {
      :conditions => [("match(value) against(? in boolean mode)" + only_condition), query],
      :select => "fulltext_rows.*, #{sanitize_sql(["match(`value`) against(? in boolean mode) AS relevancy", query])}",
      :order => 'relevancy DESC, value ASC'
    }

    if defined?(WillPaginate)
      self.paginate(:all, search_options.merge(:page => page))
    else
      self.find(:all, search_options.merge(:limit => limit, :offset => offset))
    end
  end
end
