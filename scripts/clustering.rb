#!/usr/bin/env ruby

def computeDist(d,g1,g2)
  max=0
  g1.each do |f1|
    g2.each do |f2|
      max=[max,D[[f1,f2]]].max
    end
  end
  return max
end

def extractbest(d,g)
  m=-1
  res=nil
  g.each do |el|    
    t=0
    g.each do |el2| 
      t+=D[[el,el2]]
    end
    if t>m
      m=t
      res=el
    end
  end
  return res
end

def extractlast(d,g)
  m=-1
  res=nil
  g.each do |el|    
    base=el.split("_")[1].to_i #el.gsub(/\.c(pp)?/, "").gsub("sub","").to_i
    if base>m
      res=el
      m=base
    end
  end
  return res
end



files=Dir.glob("*.c*")

str=`sherlock -t 15 *.c*`

#puts "done"
D=Hash.new(0)

c=0
str.each_line do |s|
  a=s.sub(":","").sub("\%","").split(" ")
  D[[a[0],a[2]]]=a[3].to_i;
  D[[a[2],a[0]]]=a[3].to_i;
  c=c+1
end

groups=[]

files.each do |f|
  groups << [f]
end

#puts c

while true
  m=-1
  p=nil
#  puts "ciclo"
  groups.combination(2).each do |g1,g2|
    d=computeDist(D,g1,g2)
    if(d>m)
      m=d
      p=[g1,g2]
    end
  end
  if m<20
    break
  end
  groups.delete(p[0])
  groups.delete(p[1])
  groups << (p[0]+p[1])
end


groups.each do |g|
  puts extractlast(D,g)
end
