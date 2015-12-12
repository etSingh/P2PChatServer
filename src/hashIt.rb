class HashIt
	
	def self.hashCode(str) #This function generates a hash code of the string it receives 
    	hash=0
    		str.each_byte do |i|
      	hash=hash*31 + i
    	end
    	return hash     
	end

end