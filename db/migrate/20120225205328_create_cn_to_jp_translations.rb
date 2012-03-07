class CreateCnToJpTranslations < ActiveRecord::Migration
  ActiveRecord::Base.establish_connection :chinese
  def self.up
    create_table :cn_to_jp_translations do |t|
      t.column :cn_sense_ref_id, :ubigint
      t.column :jp_sense_ref_id, :ubigint
      t.integer :lock_version

      t.timestamps
    end
    add_index :cn_to_jp_translations, :cn_sense_ref_id
    add_index :cn_to_jp_translations, :jp_sense_ref_id
  end

  def self.down
    drop_table :cn_to_jp_translations
  end
end

