class CreateFulltextRows < ActiveRecord::Migration
  def self.up
    create_table :fulltext_rows, :options => 'ENGINE=MyISAM' do |t|
      t.column :fulltextable_type,  :string,  :null => false, :limit => 50
      t.column :fulltextable_id,    :integer, :null => false
      t.column :value,              :text,    :null => false, :default => ''
      t.column :parent_id,          :integer
    end
    
    [<%= models.join(', ') %>].each do |m|
      m.find(:all).each {|i| i.create_fulltext_record}
    end
    
    execute "CREATE FULLTEXT INDEX fulltext_index ON fulltext_rows (value)"
    add_index :fulltext_rows, :parent_id
    add_index :fulltext_rows, [:fulltextable_type, :fulltextable_id], :unique => true
  end

  def self.down
    drop_table :fulltext_rows
  end
end
