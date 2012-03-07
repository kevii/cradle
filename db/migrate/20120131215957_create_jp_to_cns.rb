class CreateJpToCns < ActiveRecord::Migration
  def self.up
    create_table :jp_to_cns do |t|
      t.column :jp_id, :ubigint
      t.column :cn_id, :ubigint

      t.timestamps
    end
    add_index :jp_to_cns, :jp_id
    add_index :jp_to_cns, :cn_id
  end

  def self.down
    drop_table :jp_to_cns
  end
end

