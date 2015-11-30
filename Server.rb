# A skeleton TCPserver
$LOAD_PATH << File.dirname(__FILE__)
require 'socket'
require "lib/threadpool.rb"

class Server

  def initialize(host,port)
    @host=host
    @port=port
    @clientName=Hash.new # Stores the name of all the clients, join_ID as key, clientname as value
    @serverSocket= TCPServer.open(@host,@port)
    @descriptors=Array.new #Stores all client sockets and the server socket
    @descriptors.push(@serverSocket)
    @clientSoc=Hash.new # client socket as key and join_ID as value
    @threadPool=Thread.pool(4) #There can be a maximum of 4 threads at a time
    @retryJoinReqFlag=0
    @chatRooms=Hash.new([].freeze) # Stores the chatname hash value as key, and an array of the client sockets who are in that room 
    @roomName=Hash.new # room_ref as key, chatroom name as value
    @clientRooms=Hash.new([].freeze) #client as key, array of connected room_ref as value
    @StudentID=ARGV[2]||152
  end
  
  def welcome(client)
    puts "log: Connection from client #{client}"
  end
  
  def chatRoom(chatRoomName, client)
    puts "log: Inside chatRoom method"
    flag=0
    room_ref=hashCode(chatRoomName)
    puts "log: room_ref= #{room_ref}"
    @chatRooms.each do |key, value| #Checks to see if chatroom is already present, if it is, then adds the client
      if key==room_ref
        flag=1
        @chatRooms[key] += [client]
      end
    end
    if flag==0
    @roomName[room_ref]=chatRoomName
    puts "log: adding client in #{chatRoomName}"
    @chatRooms[room_ref] += [client]
    end
    @clientRooms[client] += [room_ref]
    puts "log:client added"
    puts "log:chatroom #{chatRoomName} created"
    puts "log:printing @chatRooms #{@chatRooms}"
    puts "log:printing @roomName #{@roomName}"
    puts "log:printing @clientRooms #{@clientRooms}"
    return room_ref
  end

  def hashCode(str) #This function generates a hash code of the string it receives 
    hash=0
    str.each_byte do |i| 
      hash=hash*31 + i 
    end
    return hash     
  end
  
  def disconnectClient(client)
     puts "log: Closing connection to client on port #{@remote_port}"
     @descriptors.pop(client)
     
     client.close
   end
  
  def initiateCheckname(username, client)
    reply=checkname(username, client) #Gets 1 from checkname if username is already taken, else gets 0
    puts "log: got reply #{reply}"
    if reply==1 
      input=client.gets # If the username is already taken, get response from client if it wants to retry or not
          if input[0,5]=="Close" # If the answer recieved is close, then close the connection
             disconnectClient(client)
          else    #The client wants to retry
            @retryJoinReqFlag=1
          end
    end
    puts "log: initiateCheckname over \n"
  end
  
  def welcomeMessage(room_ref, client)
    #puts "#{@descriptors}"
    #puts "Inside welcomeMessage:  client: #{client} Client socket #{@clientSoc} client room: #{@clientRooms} Client Name #{@clientName}"
    msg="#{@clientName[@clientSoc[client]]} has joined this chatroom"
    broadcastMessage(room_ref, msg, client)
    puts "log: Welcome message sent \n"
  end

  def broadcastMessage(room_ref, str, client)
  #@chatRooms.each do | key, value |
  client.puts "CHAT:#{room_ref}\n"
  client.puts str
  end

  def sendJoinReqMsg(join_details, client)
    room_ref=chatRoom(join_details[0], client)
    client.puts "JOINED_CHATROOM:#{join_details[0]}\nSERVER_IP:#{@host}\nPORT:#{@port}\nROOM_REF:#{@roomName.key(join_details[0])}\nJOIN_ID:#{@clientName.key(join_details[3])}\n"
    puts "log: join request message sent to client"
    welcomeMessage(room_ref, client) #Send a welcome message to the client
  end
  
  def servJoinReq(input,client)
    join_details=Array.new 
    join_details[0]=input.slice((input.index(':')+1)..input.length).chomp
    i=1
      while (i<=3) # This loop extracts the client details from the join request and stores it in the join_details array
          input=client.gets.chomp
          join_details[i]=input.slice((input.index(':')+1)..input.length).chomp
          if i==3 #Checks to see if the client name is already taken
           initiateCheckname(join_details[3], client)  
          end
          if @retryJoinReqFlag==1 # If the client opts to get a new username, come of the loop and go back to the run method
            break
          end
          i+=1
      end
      
        if @retryJoinReqFlag==0
          puts "log: Calling sendJoinReqMsg"
          sendJoinReqMsg(join_details, client)
        end
    end

  def raiseError(id, client)
    if id==0
      client.puts "ERROR_CODE:#{id}\nERROR_DESCRIPTION:Username already taken!! "
    end
  end

  def checkname(input, client) #checks if username is available, returns 1 if it's already taken, 0 if it's available
    flag=0
      @clientName.each do |key, name| #If username is already taken, flag is set to 1
        if name==input              
          flag=1
        end
      end
      if flag==0  #if username is available, it is pushed into the hash @chatName
        clientID=hashCode(input)
        @clientName[clientID]=input # Stores the Client name with it's key as the join ID
        @clientSoc[client]=clientID
        puts "log: Username #{input} created for client #{@clientSoc[client]}"
        puts "log: Client socket= #{@clientSoc}"
      else
        raiseError(0, client)
      end
      return flag
  end

  def new_Connection(client)
      while true
      input=client.gets.chomp
      puts "log: From #{client}: #{input}"
      handle_Connection(input, client)
      end
  end
  
  def sendleaveMsg(leave_details, client)
      client.puts "LEFT_CHATROOM:#{leave_details[0]}\nJOIN_ID:#{leave_details[1]}"
      puts "****************leave message sent**************"
      puts "LEFT_CHATROOM:#{leave_details[0]}\nJOIN_ID:#{leave_details[1]}"
      puts "************************************************"
      @clientRooms[client] -= [leave_details[0]]
      @chatRooms[leave_details[0]] -= [client]
      room_ref=leave_details[0]
      msg="#{@clientName[@clientSoc[client]]} has left this chatroom"
      broadcastMessage(room_ref, msg, client)
      puts "log: new value of @clientRooms: #{@clientRooms} \n@chatRooms: #{@chatRooms}"
  end
  
  def leaveChatroomMsg(input, client)
    i=1
    leave_details=Array.new
    leave_details[0]=input.slice((input.index(':')+1)..input.length).to_i
    while i<=2
      input=client.gets
      leave_details[i]=input.slice((input.index(':')+1)..input.length).to_i
      i+=1
    end
    puts "log: leave_details:- #{leave_details}"
    sendleaveMsg(leave_details, client)
  end

  def handle_Connection(input, client)
    if input[0,4]=="HELO"
      client.puts "#{input}\nIP:#{@host}\nPort:#{@port}\nStudentID:#{@StudentID}\n"
      puts "log: sending HELO message"
    elsif input=="KILL_SERVICE"
      terminate
    elsif input[0,13]=="JOIN_CHATROOM"
      servJoinReq(input, client) # Service the join request of the client
      if @retryJoinReqFlag==1 #check if the "username already taken" error was raised and the client opted to try again
         @retryJoinReqFlag=0
         servJoinReq(input, client)
      end
    elsif input[0,14]=="LEAVE_CHATROOM"
      leaveChatroomMsg(input, client)
    else
      #client.puts "Invalid Input \n"
      puts "log: Invalid message"
    end
  end

  def terminate #terminates all socket connections, terminating clients first
    @descriptors.each do |socket|  
      if socket!= @serverSocket
         #socket.puts "Goodbye"
         socket.close
      end
    end
      
      puts "Server Shutting down \n"
      @serverSocket.close   
      abort("Goodbye")
      exit
  end

  
  def run
    puts "Server running on Port #{@port} ..."
    while true
      @threadPool.process {
      client=@serverSocket.accept 
      @descriptors.push(client) #Pushes the client socket
      welcome(client)
      new_Connection(client)
      }
    end
  end
end

if _FILE_=$0

server = Server.new(ARGV[0]||"Localhost",ARGV[1]||5000)
server.run()

end

