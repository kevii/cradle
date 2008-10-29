#!/usr/bin/env ruby

#You might want to change this
ENV["RAILS_ENV"] ||= "production"

require File.dirname(__FILE__) + "/../../config/environment.rb"

$running = true;
Signal.trap("TERM") do 
  $running = false
end

dump_path_prefix = File.dirname(__FILE__) + "/../../dumped_data/"
backup_interval = 86400  ## in second
backup_time = 3        ## 3 am
backup_copies = 10     ## the number of copies
sleep_time = 600        ## in second
time_suffix_type = 'day'  ## time suffix type:  second or day


last_time = 0
while($running) do
  now_time = Time.now.to_s(:db).split(/-|\s|:/).join('').to_i
  if now_time-last_time>backup_interval and Time.now.hour==backup_time
    if time_suffix_type == 'second'
      backup_time_suffix = now_time.to_s
    elsif time_suffix_type == 'day'
      backup_time_suffix = now_time.to_s.slice(0..7)
    end
    ["japanese", "chinese", "english"].each{|sub_dir|
      whole_path = dump_path_prefix + sub_dir + '/'
      all_file_array = []
      case sub_dir
        when 'japanese'
          db_name = 'cor-jp'
        when 'chinese'
          db_name = 'cor-cn'
        when 'english'
          db_name = 'cor-en'
      end
      Dir.foreach(whole_path){|file| all_file_array<<[whole_path+file, $1] if file=~/^#{db_name}-(\d+)\.sql$/}
      all_file_array = all_file_array.sort{|a,b| a[1].to_i<=>b[1].to_i}.reverse
      FileUtils.rm(all_file_array.last[0]) if all_file_array.size> backup_copies-1
      `mysqldump --opt -ujia-l -prails #{db_name} > #{dump_path_prefix+sub_dir+'/'+db_name+'-'+backup_time_suffix+'.sql'}`
    }
    last_time = now_time
  end
  sleep sleep_time
end