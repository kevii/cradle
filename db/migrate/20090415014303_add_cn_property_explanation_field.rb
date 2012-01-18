class AddCnPropertyExplanationField < ActiveRecord::Migration
	RAILS_ENV="chinese"

  def self.up
    config = ActiveRecord::Base.configurations["chinese"]
    ActiveRecord::Base.establish_connection(config)
  	add_column :cn_properties, :explanation, :string
  end

  def self.down
    config = ActiveRecord::Base.configurations["chinese"]
    ActiveRecord::Base.establish_connection(config)
  	remove_column :cn_properties, :explanation
  end
end
