# A skeleton TCPserver
$LOAD_PATH << '.'
require 'socket'
require "lib/threadpool.rb"
require "src/chatroom.rb"

class Server

  def initialize(host,port)
    @host=host
    @port=port
    @handleChatrooms=Chatroom.new(@host, @port)
    @serverSocket= TCPServer.open(@host,@port)
    @descriptors=Array.new #Stores all client sockets and the server socket
    @descriptors.push(@serverSocket)
    @threadPool=Thread.pool(10) #There can be a maximum of 4 threads at a time
    @StudentID=ARGV[2]||152
  end
  
  def welcome(client)
    puts "log: Connection from client #{client}"
  end
  
  def raiseError(id, client)
    if id==0
      client.puts "ERROR_CODE:#{id}\nERROR_DESCRIPTION:Username already taken!! "
    end
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
      @handleChatrooms.servJoinReq(input, client) # Service the join request of the client
    elsif input[0,14]=="LEAVE_CHATROOM"
       @handleChatrooms.leaveChatroomMsg(input, client)
    elsif input[0,5]=="CHAT:"
       @handleChatrooms.handleChatMsg(input, client)
    elsif input[0,11]=="DISCONNECT:"
       @handleChatrooms.handleDisconnectMsg(client)
    else
      puts "log: Invalid message"
    end
  end


  def terminate #terminates all socket connections, terminating clients first
    @descriptors.each do |socket|  
      if socket!= @serverSocket
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
    puts "Listening for connections \n"
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

server = Server.new(ARGV[0]||"Localhost",ARGV[1]||5000)
server.run()

