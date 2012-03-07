class CreateCnToJps < ActiveRecord::Migration
  ActiveRecord::Base.establish_connection :chinese
  def self.up
    # CnToJp.establish_connection :chinese

    create_table :cn_to_jps do |t|
      t.column :cn_id, :ubigint
      t.column :jp_id, :ubigint

      t.timestamps
    end
    add_index :cn_to_jps, :cn_id
    add_index :cn_to_jps, :jp_id
  end

  def self.down
    # CnToJp.establish_connection :chinese

    drop_table :cn_to_jps
  end
end

