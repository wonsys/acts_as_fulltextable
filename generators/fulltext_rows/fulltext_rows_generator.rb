class FulltextRowsGenerator < Rails::Generator::Base
  attr_accessor :models
  def initialize(*runtime_args)
    super(*runtime_args)
    @models = args.map {|m| Object.const_get(m.camelize) rescue nil}.compact.uniq
  end

  def manifest
    record do |m|
      m.migration_template("migration.rb", 'db/migrate',
                           :assigns => { :models => @models },
                           :migration_file_name => "create_fulltext_rows")
    end
  end

protected
  def banner
    "Usage: #{$0} #{spec.name} [model1 model2 model3 ...]" 
  end
end
