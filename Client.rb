require 'socket'

class Client

def initialize(host,port) 
	@s = TCPSocket.new(host, port)
	@clientName
	@chatroom
	@retryJoinReqFlag=0
	puts "log: Starting Session \n"
end

def retryResponse
		puts "Do you want to retry?(y/n)"
		choice=$stdin.gets
		if choice[0]=="y"
			@s.puts "Retrying"
			@retryJoinReqFlag=1
		elsif choice[0]=="n"
            @s.puts "Close the connection"
            @s.close
			abort("Goodbye")
		else
			puts "Invalid choice...try again"
			retryResponse
		end
end

def detectError
	input=@s.gets
	if input[0,5]=="ERROR"
		puts "#{input}#{@s.gets}"
		retryResponse
	else
		puts input
		@detectErrorFlag=1
	end
end

def sendJoinRequest
	puts "Enter a username:"
	@clientName= $stdin.gets
	puts "Enter the name of the chatroom you would like to join"
	@chatroom=$stdin.gets.chomp
	@s.puts "JOIN_CHATROOM:#{@chatroom}\nClient_IP:\nPORT:\nCLIENT_NAME:#{@clientName}"
end

def getJoinResponse
	i=0;
	if @detectErrorFlag==1
		j=3
	else
		j=4
	end
	while i<=j
		puts @s.gets
		i+=1
	end
end

def run
    sendJoinRequest
    detectError
    if @retryJoinReqFlag==1
    	puts "Calling servJoinRequest again"
    	@retryJoinReqFlag=0
    	sendJoinRequest
    end
    getJoinResponse 
	
	while !(@s.closed?) 
    	puts "Say something to Server"
		l=$stdin.gets
		@s.puts l

		if l[0,4]=="HELO"
			puts "From Server: "
			i=0
			while(i<=3)
				lineFromServer=@s.gets
			 	puts "#{lineFromServer}"
			 	i+=1
			end
    	else
	    	lineFromServer=@s.gets
	    	puts "From Server: #{lineFromServer}"
    	end
    end
end

end

if _FILE_=$0

client = Client.new(ARGV[0]||"Localhost",ARGV[1]||5000)
client.run()

end





