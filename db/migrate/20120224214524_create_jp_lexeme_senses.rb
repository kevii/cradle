class CreateJpLexemeSenses < ActiveRecord::Migration
  def self.up
    create_table :jp_lexeme_senses do |t|
      t.column :jp_lexeme_ref_id, :ubigint
      t.text :text
      t.integer :category
      t.integer :lock_version

      t.timestamps
    end
    add_index :jp_lexeme_senses, :jp_lexeme_ref_id
  end

  def self.down
    drop_table :jp_lexeme_senses
  end
end

