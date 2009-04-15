class AddJpPropertyExplanationField < ActiveRecord::Migration
	RAILS_ENV="development"

  def self.up
  	add_column :jp_properties, :explanation, :string
  end

  def self.down
  	remove_column :jp_properties, :explanation
  end
end
