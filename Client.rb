require 'socket'

class Client

def initialize(host,port) 
	@s = TCPSocket.new(host, port)
	@clientName
	@chatroom
	@retryJoinReqFlag=0
	@room_ref=Hash.new #room_ref as key, chatroom name as value
	@join_ID
	@join_details=Array.new
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
	lineFromServer=@s.gets
	if lineFromServer[0,5]=="ERROR"
		puts "#{lineFromServer}#{@s.gets}"
		retryResponse
	else
		puts lineFromServer
		@join_details[0]=lineFromServer.slice((lineFromServer.index(':')+1)..lineFromServer.length).chomp
		@detectErrorFlag=1
	end
end

def initialJoinRequest
	puts "Enter a username:"
	@clientName= $stdin.gets
	puts "Enter the name of the chatroom you would like to join"
	@chatroom=$stdin.gets.chomp
	@s.puts "JOIN_CHATROOM:#{@chatroom}\nClient_IP:\nPORT:\nCLIENT_NAME:#{@clientName}"
end

def getJoinResponse
	if @detectErrorFlag==1
		i=1
	else
		i=0
	end
	while i<=4
		lineFromServer= @s.gets
		@join_details[i]=lineFromServer.slice((lineFromServer.index(':')+1)..lineFromServer.length).chomp
		puts lineFromServer
		i+=1
	end
	@detectErrorFlag=0
end

def records
	@room_ref[@join_details[3]]=@join_details[0]
	@join_ID=@join_details[4]
end

def recvWelcomeMsg
	puts @s.gets
end

def recvLeaveMsg
	puts "*****************Leaving Notification****************\n"
	puts @s.gets
	puts @s.gets
	puts "*****************************************************\n"
end

def menu
	puts "***********************Menu************************\n"
	puts "Enter 1 to post a message to a chatroom"
	puts "Enter 2 to leave a chatroom"
	puts "Enter 3 to join another chatroom"
	puts "Enter 4 to send HELO/KILL_SERVICE messages to server"
	puts "***************************************************\n"
	ch=gets.to_i
	if ch==1
		chatroom
	elsif ch==2
		leaveChatroom
	elsif ch==3
		sendJoinRequest
	elsif ch==4
		baseTestMsg
	else
		puts "invalid selection"
		menu
	end
end

def chatroom
end

def leaveChatroom
	puts "You are presently connected to the following chatrooms:- "
	@room_ref.each_value { |value| puts "#{value} " }
	puts "Enter the name of the chatroom you would like to leave"
	input=gets.chomp
	if @room_ref.has_value?(input)
		@s.puts "LEAVE_CHATROOM:#{@room_ref.key(input)}\nJOIN_ID:#{@join_ID}\nCLIENT_NAME:#{@clientName}"
	    puts "****************Message sent***************\n"
	    puts "LEAVE_CHATROOM:#{@room_ref.key(input)}\nJOIN_ID:#{@join_ID}\nCLIENT_NAME:#{@clientName}"
	    puts "*******************************************\n"
	else
		puts "Incorrect Input, try again.."
		leaveChatroom
    end
    recvLeaveMsg
	menu
end

def sendJoinRequest
end
	
def baseTestMsg 
    	
    	puts "Say something to Server"
		l=$stdin.gets
		@s.puts l

		if l[0,4]=="HELO"
			puts "**************Hello Message**************\n"
			i=0
			while(i<=3)
				lineFromServer=@s.gets
			 	puts "#{lineFromServer}"
			 	i+=1
			end
			puts "*****************************************\n"
		elsif l[0,4]=="KILL"
			puts "Terminating Server socket"
    	else
	    	puts "Invalid base message"
    	end
    menu
end

def run
    initialJoinRequest
    detectError
    if @retryJoinReqFlag==1
    	puts "log: Calling servJoinRequest again"
    	@retryJoinReqFlag=0
    	initialJoinRequest
    end
    getJoinResponse
    recvWelcomeMsg 
    records
    menu
end

end

if _FILE_=$0

client = Client.new(ARGV[0]||"Localhost",ARGV[1]||5000)
client.run()

end





