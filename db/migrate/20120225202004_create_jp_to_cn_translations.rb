class CreateJpToCnTranslations < ActiveRecord::Migration
  def self.up
    create_table :jp_to_cn_translations do |t|
      t.column :jp_sense_ref_id, :ubigint
      t.column :cn_sense_ref_id, :ubigint
      t.integer :lock_version
      t.timestamps
    end
    add_index :jp_to_cn_translations, :jp_sense_ref_id
    add_index :jp_to_cn_translations, :cn_sense_ref_id
  end

  def self.down
    drop_table :jp_to_cn_translations
  end
end

