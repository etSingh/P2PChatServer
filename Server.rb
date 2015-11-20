# A skeleton TCPserver
$LOAD_PATH << File.dirname(__FILE__)
require 'socket'
require "lib/threadpool.rb"

class Server

  def initialize(host,port)
    @host=host
    @port=port
    @descriptors=Array.new #Stores all client sockets and the server socket
    @clientName=Array.new #Probably this isn't of any use either
    @clientNameCurrent #This is of no use
    @serverSocket= TCPServer.open(@host,@port)
    @descriptors.push(@serverSocket)
    @threadPool=Thread.pool(4) #There can be a maximum of 4 threads at a time
    @retryJoinReqFlag=0
    @chatroom=Hash.new
    @sock_domain 
    @remote_port 
    @remote_hostname 
    @remote_ip
    @StudentID=ARGV[2]||152
  end
  
  def welcome(client)
    @sock_domain, @remote_port, @remote_hostname, @remote_ip = client.peeraddr #this is of no use either
    puts "log: Connection from #{@remote_ip} at port #{@remote_port}"
  end
  
  def chatRoom(chatname)
    hash=0
    chatname.each_byte do |i| 
      hash=hash*31 + i 
    end
    puts "log:chatroom #{chatname} created"
    return hash     
  end
  

  def servJoinReq(input,client)
    join_details=Array.new 
    join_details[0]=input.slice((input.index(':')+1)..input.length)   
    i=1
    while (i<=3)
        input=client.gets.chomp
        join_details[i]=input.slice((input.index(':')+1)..input.length)
        if i==3
            flag=checkname(join_details[3], client)
            if flag==1 # If the username is already taken, get response from client if it wants to retry or not
              input=client.gets
              if input[0,5]=="Close" # If the answer recieved is close, then close the connection
                puts "log: Closing connection to client on port #{@remote_port}"
                @descriptors.pop(client)
                client.close
              else    #The client wants to retry, come out of the function servJoinReq
                @retryJoinReqFlag=1
                break
              end
            end
        end
        i+=1
    end
    
      if @retryJoinReqFlag==0
        room_ref=chatRoom(join_details[0])
        client.puts "JOINED_CHATROOM:#{join_details[0]}\nSERVER_IP:#{@host}\nPORT:#{@port}\nROOM_REF:#{room_ref}\nJOIN_ID: 1\n"
      else 
        puts "log: going back to run"
      end
  end

  def raiseError(id, client)
    if id==0
      client.puts "ERROR_CODE:#{id}\nERROR_DESCRIPTION: Username already taken!! "
    end
  end

  
  def checkname(input, client) #checks if username is available, returns 1 if it's already taken, 0 if it's available
    flag=0
      @clientName.each do |name| #If username is already taken, flag is set to 1
        if name==input              
          flag=1
        end
      end
      if flag==0  #if username is available, it is pushed into the array @clientName
        @clientName.push(input)
        puts "log: Username #{input} created for client on port #{@remote_port}"
      else
        raiseError(0, client)
      end
      return flag
  end

  def new_Connection(client)
      while true
      input=client.gets.chomp
      puts "log: got input from client #{@remote_port}"
      puts "From #{client} #{@remote_port}: #{input}"
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
      if @retryJoinReqFlag==1
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

