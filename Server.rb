# A skeleton TCPserver
$LOAD_PATH << '.'
require 'socket'
require 'optparse'
require "lib/threadpool.rb"
require "src/chatroom.rb"

class Server

  def initialize(host, port)
    @host=host
    @port=port
    @id=$options[:id]
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
    puts "Server is #{@nodeType} running on Port #{@port} with id #{@id}..."
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

if __FILE__ == $0
  #cmd arguments
  $options = {}

  optparse = OptionParser.new do|opts|
    opts.banner = "Usage: Server.rb [host] [Port] [options]"

    opts.on("-b", "--boot [ID]", Integer,"Creates first node in the P2P Network with provided id") do |v|
      $options[:id]=v
      $options[:ip]=""
    end
    
    opts.on("-s", "--bootstrap IP_Address", "Attaches node to gateway node having the specified IP address") do |v|
      $options[:ip]=v
    end

    opts.on("--id [ID]", Integer, "Specifies the id of the node on bootstrap") do |v|
      $options[:id] = v
    end

    opts.on_tail("-h", "--help", "Displays this message") do 
      puts opts
      exit
    end
  end.parse! #end of optparse

  puts "Initialized with options- #{$options}"
  server = Server.new(ARGV[0]||"localhost", ARGV[1]||8767)
  server.run()
end
