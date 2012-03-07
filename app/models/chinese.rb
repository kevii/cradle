class Chinese < ActiveRecord::Base
	self.abstract_class = true
	# establish_connection :chinese

	def self.merge_user(merge_user_id, old_user_id)
		ActiveRecord::Base.connection.execute("update cn_lexemes set created_by=#{merge_user_id} where created_by=#{old_user_id};")
		ActiveRecord::Base.connection.execute("update cn_lexemes set modified_by=#{merge_user_id} where modified_by=#{old_user_id};")
    ActiveRecord::Base.connection.execute("update cn_synthetics set modified_by=#{merge_user_id} where modified_by=#{old_user_id};")
	end
end

