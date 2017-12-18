#!/usr/bin/ruby

ids = Dir.glob("*")
ids.each do |i|
    ids.each do |j|
    if(i<j) then

          str = "sherlock -t 0 #{i}/sub#{i}* #{j}/sub#{j}* | grep sub#{i}_ | grep sub#{j}_ | awk {'print $4,$1,$3'} | sort -n | tail -n 1"

          res=`#{str}`.chomp
          puts "#{res} #{i} #{j}"
        end
    end
end
