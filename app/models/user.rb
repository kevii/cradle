require 'digest/sha1'

class User < ActiveRecord::Base
  # mysql table used
  self.table_name = "users"
  
  ######################################################
  ##### table refenrence
  ######################################################
  has_many :created_jp_lexemes, :class_name => "JpLexeme", :foreign_key => "created_by"
  has_many :modified_jp_lexemes, :class_name => "JpLexeme", :foreign_key => "modified_by"
  has_many :modified_jp_synthetics, :class_name => "JpSynthetic", :foreign_key => "modified_by"
  
  
  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :name, :password
  validates_uniqueness_of :name
  
  attr_accessor :password_confirmation
  validates_confirmation_of :password
  
  ######################################################
  ##### callback
  ######################################################
  before_destroy :validate_delete

  ######################################################
  ##### method
  ######################################################
  def self.authenticate(name, password)
    user = self.find_by_name(name)
    if user
      expected_password = encrypted_password(password, user.salt)
      if user.hashed_password != expected_password
        user = nil
      end
    end
    user
  end

  def password
    @password
  end
  
  def password=(pwd)
    @password = pwd
    create_new_salt
    self.hashed_password = User.encrypted_password(self.password, self.salt)
  end

  private
  
  def self.encrypted_password(password, salt)
    string_to_hash = password + "cradle" + salt # 'cradle' makes it harder to guess
    Digest::SHA1.hexdigest(string_to_hash)
  end

  def create_new_salt
    self.salt = self.object_id.to_s + rand.to_s
  end
  
  def validate_delete
    if Thread.current["user_id"] == id
      errors.add_to_base("You cannot delete yourself!")
      return false
    end
    unless (created_jp_lexemes.blank? or modified_jp_lexemes.blank? or modified_jp_synthetics.blank?)
######## jia-l leave for cn
#      (created_cn_lexemes.blank? or modified_cn_lexemes.blank? or modified_cn_synthetics.blank?)
      errors.add_to_base("Please merge this user to other user before deleting!")
      return false
    end
  end
end