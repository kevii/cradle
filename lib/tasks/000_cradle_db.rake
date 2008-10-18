namespace :cradle do
  namespace :migrate do
    desc 'migrate cor-jp tables'
    task :jp => :environment do
      config = {}
      ActiveRecord::Base.configurations.each{|key,value|
        unless key == "chinese" or key == "english"
          config = value
          break
        end
      }
      ActiveRecord::Base.establish_connection(config)
      puts "STEP 1: create tables in japanese database"
      ### uses table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table users (
          id               int  unsigned  not null  auto_increment,
          name             varchar(255) not null,
          hashed_password  varchar(255) not null,
          salt             varchar(255),
          group_name       enum('user', 'admin')  not null,
          lock_vertion     int default 0,
          
          primary key (id),
  
          index   index_name   (name),
          index   index_group  (group_name)
        ) ENGINE=INNODB
      ENB
    
      ### jp_lexemes table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_lexemes (
          id                bigint  unsigned  not null,
          surface           varchar(255),
          reading           varchar(255),
          pronunciation     varchar(255),
          base_id           bigint  unsigned  not null,
          root_id           varchar(255),
          pos               int unsigned,
          ctype             int unsigned,
          cform             int unsigned,
          dictionary        text   not null,
          tagging_state     int unsigned  not null,
          log               text,
          created_by        int not null,
          modified_by       int,
          updated_at        timestamp,
          lock_vertion      int default 0,
          
          primary key (id),
  
          index   index_surface         (surface),
          index   index_reading         (reading),
          index   index_pronunciation   (pronunciation),
          index   index_base_id         (base_id),
          index   index_root_id         (root_id),
          index   index_pos             (pos),
          index   index_ctype           (ctype),
          index   index_cform           (cform),
          index   index_tagging_state   (tagging_state),
          index   index_created_by      (created_by),
          index   index_modified_by     (modified_by),
          index   index_updated_at      (updated_at)
        ) ENGINE=INNODB
      ENB
    
      ### jp_synthetics table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_synthetics (
          id                  bigint  unsigned  not null  auto_increment,
          sth_ref_id          bigint  unsigned  not null,
          sth_meta_id         int not null,
          sth_struct          text not null,
          sth_tagging_state   int unsigned  not null,
          log                 text,
          modified_by         int not null,
          updated_at          timestamp,
          lock_vertion        int default 0,
  
          primary key (id),
  
          index   index_ref                (sth_ref_id),
          index   index_meta_id            (sth_meta_id),
          index   index_sth_tagging_state  (sth_tagging_state),
          index   index_modified           (modified_by),
          index   index_updated            (updated_at)
        ) ENGINE=INNODB
      ENB
    
      ### jp_properties table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_properties (
          id                int unsigned  not null  auto_increment,
          property_string   varchar(255)   not null,
          property_cat_id   int unsigned not null,
          parent_id         int,
          seperator         varchar(64) default null,
          value             varchar(255) not null,
          lock_vertion      int default 0,
          
          primary key (id),
          
          index   index_property    (property_string),
          index   index_item        (property_string, property_cat_id),
          index   index_seperator   (seperator),
          index   index_value       (value)
        ) ENGINE=INNODB
      ENB

      ### jp_new_properties table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_new_properties (
          id                int unsigned  not null  auto_increment,
          property_string   varchar(255)   not null,
          human_name        varchar(255)   not null,
          section           enum('lexeme', 'synthetic')  not null,
          type_field        enum('category', 'text', 'time')  not null,
          description       text,
          lock_vertion      int default 0,
          
          primary key (id),
          
          unique  index  index_property (property_string),
          index   index_human_name      (human_name)
        ) ENGINE=INNODB
      ENB

      ### jp_lexeme_new_property_items table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_lexeme_new_property_items (
          id                bigint  unsigned  not null auto_increment,
          property_id       int not null,
          ref_id         bigint  unsigned  not null,
          category          int unsigned,
          text              text,
          time              timestamp NULL DEFAULT 0,
          lock_vertion      int default 0,
          
          primary key (id),
          
          index   index_property   (property_id),
          index   index_lexeme     (ref_id),
          index   index_item       (property_id, ref_id),
          index   index_category   (category),
          index   index_time       (time)
        ) ENGINE=INNODB
      ENB

      ### jp_synthetic_new_property_items table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_synthetic_new_property_items (
          id                bigint  unsigned  not null auto_increment,
          property_id       int not null,
          ref_id            bigint  unsigned  not null,
          category          int unsigned,
          text              text,
          time              timestamp NULL DEFAULT 0,
          lock_vertion      int default 0,
          
          primary key (id),
          
          index   index_property   (property_id),
          index   index_synthetic  (ref_id),
          index   index_item       (property_id, ref_id),
          index   index_category   (category),
          index   index_time       (time)
        ) ENGINE=INNODB
      ENB

      ### jp_ctype_cform_seeds table
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table jp_ctype_cform_seeds (
          id                int  unsigned  not null auto_increment,
          ctype             int  unsigned  not null,
          cform             int  unsigned  not null,
          surface_end       varchar(64),
          reading_end       varchar(64),
          pronunciation_end varchar(64),
          lock_vertion      int default 0,
          
          primary key (id),
          
          index   index_ctype           (ctype),
          index   index_cform           (cform),
          index   index_surface         (surface_end),
          index   index_reading         (reading_end),
          index   index_pronunciation   (pronunciation_end)
        ) ENGINE=INNODB
      ENB
      
      puts "STEP 2: loading initial lexeme properties into database"
      puts "    loading pos into table jp_properties"
      ActiveRecord::Base.connection.execute <<-"ENB"
        TRUNCATE TABLE jp_properties
      ENB
      File.read("#{RAILS_ROOT}/initial_lexeme_property/jp_parts_of_speech").each{|line|
        temp = line.chomp.split("\t")
        begin
          JpProperty.save_property_tree("pos", temp[1..4], "-")
        rescue => ex
          puts ex.message+"\n"
        end
      }
        
      puts "    loading ctype into table jp_properties"
      File.read("#{RAILS_ROOT}/initial_lexeme_property/jp_ctypes").each{|line|
        temp = line.chomp.split("\t")
        begin
          JpProperty.save_property_tree("ctype", temp[1..2], "・")
        rescue => ex
          puts ex.message+"\n"
        end
      }
            
      puts "    loading cform into table jp_properties"
      File.read("#{RAILS_ROOT}/initial_lexeme_property/jp_cforms").each{|line|
        temp = line.chomp.split("\t")
        begin
          JpProperty.save_property_tree("cform", [temp[1]], nil)
        rescue => ex
          puts ex.message+"\n"
        end
      }
            
      puts "    loading tagging_state into table jp_properties"
      File.read("#{RAILS_ROOT}/initial_lexeme_property/jp_tagging_states").each{|line|
        temp = line.chomp.split("\t")
        begin
          JpProperty.save_property_tree("tagging_state", [temp[1]], nil)
        rescue => ex
          puts ex.message+"\n"
        end
      }
            
      puts "    loading sth_tagging_state into table jp_properties"
      File.read("#{RAILS_ROOT}/initial_lexeme_property/jp_synthetic_tagging_states").each{|line|
        temp = line.chomp.split("\t")
        begin
          JpProperty.save_property_tree("sth_tagging_state", [temp[1]], nil)
        rescue => ex
          puts ex.message+"\n"
        end
      }
      
      puts "    loading ctype_cform_seed into table jp_ctype_cform_seeds"
      ActiveRecord::Base.connection.execute <<-"ENB"
              TRUNCATE TABLE jp_ctype_cform_seeds
      ENB
      File.read("#{RAILS_ROOT}/initial_lexeme_property/jp_cform_seeds").each{|line|
        next if (/#/ =~ line) != nil 
        temp = line.split("\s")
        next if temp.size == 0
        ctype_ID = JpProperty.find_item_by_tree_string_or_array("ctype", temp[0]).property_cat_id
        cform_ID = JpProperty.find_item_by_tree_string_or_array("cform", temp[1]).property_cat_id
        surface_end = temp[2]
        reading_end = temp[3]
        if temp[4].blank?
          pronunciation_end = reading_end
        else
          pronunciation_end = temp[4]
        end
        ActiveRecord::Base.connection.execute <<-"ENB"
          insert into jp_ctype_cform_seeds  ( ctype,
                                              cform,
                                              surface_end,
                                              reading_end,
                                              pronunciation_end )
                                      values( #{ctype_ID},
                                              #{cform_ID},
                                              convert("#{surface_end}" using utf8),
                                              convert("#{reading_end}" using utf8),
                                              convert("#{pronunciation_end}" using utf8) )
        ENB
      }
      
      puts "    create initial user"
      @user = User.new({:name=>"cradle", :password=>"matsumoto", :password_confirmation=>"matsumoto", :group_name=>"admin"})
      @user.save
      puts "Finished!"
    end
    
    desc 'migrate cor-cn tables'
    task :cn => :environment do
      config = {}
      ActiveRecord::Base.configurations.each{|key,value|
        if key == "chinese"
          config = value
          break
        end
      }
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.execute <<-"ENB"
        create table cn_lexemes (

        ) ENGINE=INNODB
      ENB
    end
  end
end