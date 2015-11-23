# A skeleton TCPserver
$LOAD_PATH << File.dirname(__FILE__)
require 'socket'
require "lib/threadpool.rb"

class Server

  def initialize(host,port)
    @host=host
    @port=port
    @descriptors=Array.new #Stores all client sockets and the server socket
    @clientName=Hash.new #Probably this isn't of any use either
    @serverSocket= TCPServer.open(@host,@port)
    @descriptors.push(@serverSocket)
    @threadPool=Thread.pool(4) #There can be a maximum of 4 threads at a time
    @retryJoinReqFlag=0
    @chatRoom=Hash.new
    @StudentID=ARGV[2]||152
  end
  
  def welcome(client)
    puts "log: Connection from client #{client}"
  end
  
  def chatRoom(chatname)
    flag=0
    @chatRoom.each do |key, value|
      if key==hash
         #chat=value
         flag=1
      end
    end
    if flag==0
    newChatroom=hashCode(chatname)
    @chatRoom[newChatroom]=chatname
    puts "log:chatroom #{chatname} created"
    puts "log:printing @chatRoom #{@chatRoom}"
    end
  end

  def hashCode(str)
    hash=0
    str.each_byte do |i| 
      hash=hash*31 + i 
    end
    return hash     
  end
  
  def initiateCheckname(username, client)
    reply=checkname(username, client)
    if reply==1 # If the username is already taken, get response from client if it wants to retry or not
      input=client.gets
          if input[0,5]=="Close" # If the answer recieved is close, then close the connection
            puts "log: Closing connection to client on port #{@remote_port}"
            @descriptors.pop(client)
            client.close
          else    #The client wants to retry
            @retryJoinReqFlag=1
          end
    end
  end
  
  def sendJoinReqMsg(join_details, client)
    chatRoom(join_details[0])
    client.puts "JOINED_CHATROOM:#{join_details[0]}\nSERVER_IP:#{@host}\nPORT:#{@port}\nROOM_REF:#{@chatRoom.key(join_details[0])}\nJOIN_ID:#{@clientName.key(join_details[3])}\n"
  end
  
  def servJoinReq(input,client)
    join_details=Array.new 
    join_details[0]=input.slice((input.index(':')+1)..input.length)   
    i=1
      while (i<=3)
          input=client.gets.chomp
          join_details[i]=input.slice((input.index(':')+1)..input.length)
          if i==3
           initiateCheckname(join_details[3], client)  
          end
          if @retryJoinReqFlag==1 # If the client opts to get a new username, come of the loop and go back to the run method
            break
          end
          i+=1
      end
      
        if @retryJoinReqFlag==0
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
        @clientName[clientID]=input
        puts "log: Username #{input} created for client on port #{@remote_port}"
      else
        raiseError(0, client)
      end
      puts "log: printing @clientName in checkname method#{@clientName}"
      return flag
  end

  def new_Connection(client)
      while true
      input=client.gets.chomp
      puts "log: From #{client}: #{input}"
      handle_Connection(input, client)
      end
  end

  def handle_Connection(input, client)
    if input[0,4]=="HELO"
      client.puts "#{input}\nIP:#{@host}\nPort:#{@port}\nStudentID:#{@StudentID}\n"
      puts "log: sending HELO message"
    elsif input=="KILL_SERVICE"
      terminate
    elsif input[0,13]=="JOIN_CHATROOM"
      servJoinReq(input, client)
      if @retryJoinReqFlag==1 #check if the username already taken error was raised and the client opted to try again
         @retryJoinReqFlag=0
         servJoinReq(input, client)
      end
    else
      client.puts "Invalid Input \n"
      puts "log:sending invalid message"
    end
  end

  def terminate #terminates all socket connections, terminating clients first
    @descriptors.each do |socket|  
      if socket!= @serverSocket
         socket.puts "Goodbye"
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
      @descriptors.push(client)
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

