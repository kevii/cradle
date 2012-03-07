class CreateCnLexemeSenses < ActiveRecord::Migration
  ActiveRecord::Base.establish_connection :chinese
  def self.up
    create_table :cn_lexeme_senses do |t|
      t.column :cn_lexeme_ref_id, :ubigint
      t.text :text
      t.integer :category
      t.integer :lock_version

      t.timestamps
    end
    add_index :cn_lexeme_senses, :cn_lexeme_ref_id
  end

  def self.down
    drop_table :cn_lexeme_senses
  end
end

