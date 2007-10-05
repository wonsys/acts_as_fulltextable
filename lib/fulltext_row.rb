class FulltextRow < ActiveRecord::Base
  belongs_to  :fulltextable,
              :polymorphic => true
  validates_presence_of   :fulltextable_type, :fulltextable_id
  validates_uniqueness_of :fulltextable_id,
                          :scope => :fulltextable_type
  # Performs full-text search.
  # It takes four options:
  # * limit: maximum number of rows to return (use 0 for all). Defaults to 10.
  # * offset: offset to apply to query. Defaults to 0.
  # * active_record: wether a ActiveRecord objects should be returned or an Array of [class_name, id]
  # * only: limit search to these classes. Defaults to all classes. (should be a symbol or an Array of symbols)
  #
  def self.search(query, options = {})
    default_options = {:limit => 10, :offset => 0, :active_record => true}
    options = default_options.merge(options)
    options[:offset] = 0 if options[:offset] < 0
    options[:limit] = 10 if options[:limit] < 0
    options[:limit] = nil if options[:limit] == 0
    options[:only] = [options[:only]] unless options[:only].nil? || options[:only].is_a?(Array)
    options[:only] = options[:only].map {|o| o.to_s.camelize}.uniq.compact unless options[:only].nil?

    rows = raw_search(query, options[:only], options[:limit], options[:offset])
    if options[:active_record]
      types = {}
      rows.each {|r| types.include?(r.fulltextable_type) ? (types[r.fulltextable_type] << r.fulltextable_id) : (types[r.fulltextable_type] = [r.fulltextable_id])}
      objects = {}
      types.each {|k, v| objects[k] = Object.const_get(k).find(v)}
      objects.each {|k, v| v.sort! {|x, y| types[k].index(x.id) <=> types[k].index(y.id)}}
      result = []
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
  #
  def self.raw_search(query, only, limit, offset)
    unless only.nil? || only.empty?
      only_condition = " AND fulltextable_type IN (#{only.map {|c| (/\A\w+\Z/ === c.to_s) ? "'#{c.to_s}'" : nil}.uniq.compact.join(',')})"
    else
      only_condition = ''
    end
    query.gsub!(/(\S+)/, '\1*')
    self.find(:all,
              :conditions => [("match(value) against(? in boolean mode)" + only_condition), query],
              :select => "fulltext_rows.*, #{sanitize_sql(["match(`value`) against(? in boolean mode) AS relevancy", query])}",
              :limit => limit,
              :offset => offset,
              :order => 'relevancy DESC, value ASC')
  end
end