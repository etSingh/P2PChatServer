# A skeleton TCPserver
$LOAD_PATH << '.'
require 'socket'
require 'optparse'
require 'json'
require  "src/hashIt.rb"
require "lib/threadpool.rb"
require "src/chatroom.rb"

class Server

  def initialize(host, port)
    @host=host
    @port=port
    @handleChatrooms=Chatroom.new(@host, @port)
    @udp_node= UDPSocket.new
    @udp_node.bind(@host, @port)
    #@descriptors=Array.new #Stores all client sockets and the server socket
    #@descriptors.push(@serverSocket)
    @routing_table=Hash.new
    @routing_table[$options[:id]]={ node_id:$options[:id], ip_address:@host}
    @msgRecvPool=Thread.pool(10)
    @StudentID=ARGV[2]||152
    @chatTextTuple=Hash.new
    menu
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
  
  def determine
    if $options[:ip]==""
      puts "Gateway is running on Port #{@port} with id #{@id}..."
      listen
    else
      puts "Sending JOINING_NETWORK message to Gateway\n"
      sendJoinNetwork
      listen
    end
  end

  def response
    puts "Waiting for response from gateway"
    msg, _=@udp_node.recvfrom(1024)
    puts "got msg #{msg}"
    attributes=parseMsg(msg)
  end


  def sendJoinNetwork
    joinMsg={ type:"JOINING_NETWORK", node_id:$options[:id], ip_address:@host }
    sendMsg(joinMsg, $options[:ip])  
  end

  def sendMsg(msg, ip)
    puts "sending message #{msg.to_json}"
    @udp_node.send(msg.to_json, 0, ip, @port)
    puts "message sent to #{ip}" 
  end

  def parseMsg(json)
    attributes=JSON.parse(json)
    return attributes
  end

  def findMsgType(attributes={})
    msgType = attributes.fetch("type")
    puts "Message recieved of type #{msgType}"
    puts attributes
    return msgType
  end

  def handleMsg(msgType, attributes)
    puts "Inside handleMsg msgType=#{msgType}"
    if msgType=="JOINING_NETWORK"
      handleJoinNetwork(attributes)
    elsif msgType=="ROUTING_INFO"
      handleRouteInfo(attributes)
    elsif msgType=="LEAVING_NETWORK"
      handleLeaveNetwork(attributes)
  	elsif msgType=="CHAT"
  		sendAckChat(attributes)
  		handleChatMsg(attributes)
  	end
  end

  def sendAckChat(attributes)
     puts "Inside sendACK_CHAT\n"
  end

  def handleChatMsg(attributes)
  	puts "Inside handleChatMsg\n"
    #Let's find the numerically closest node
    targetId=attributes.fetch("target_id")
    min=($options[:id]-targetId).abs
    puts min
    target=-9999
    @routing_table.each_value do |v|
    	a=(targetId-v[:node_id]).abs
    	puts a
    	if a<=min 
    		target=v[:node_id]
    	end
    	if target==$options[:id]
    		puts "This node is the target\n"
    		prepareChatResponse(attributes)
    	else
    		sendMsg(attributes, @routing_table[target][:ip_address])
    	end
    end
  end

  def prepareChatResponse(attributes)
     puts "Inside prepareChatResponse\n"
  end
  
  def handleLeaveNetwork(attributes)
   @routing_table.delete(attributes.fetch("node_id"))
   puts "New Routing table= #{@routing_table}"
  end
  
  def handleRouteInfo(attributes)
    puts "Inside handleRouteInfo"
    trimmedMsg=attributes.fetch("route_table")
    puts trimmedMsg
    flag=0
    trimmedMsg.each do |v| #trimmed and attributes are hashes with strings as keys, whatever you recieve is a string key hash
      @routing_table.each do |k, d|
          if v.fetch("node_id")==k
              flag=1 #The node is present in the table, won't go ahead with this
          end
      end
          if flag==0 #the node isn't present in the table
              @routing_table[v.fetch("node_id")]={ node_id:v.fetch("node_id"), ip_address:v.fetch("ip_address")}
          end
          flag=0
    end       
    puts "Routing table = #{@routing_table}\n"
  end
  
  def menu
      Thread.new do
        loop {
          puts "Press 1 to send a Chat message\n"
          puts "Press 2 to retrive a Chat\n"
          puts "Press 3 to leave the Network\n"
          s=$stdin.gets.to_i
          if s==1
            chat
          elsif s==2
            retrive
          elsif s==3
            leave
          else
            puts "Wrong choice darlin', try again\n"
          end
          }
      end
  end
  
  def chat
      puts "Inside chat\n"
      puts "Enter a chat message\n"
      msg=$stdin.gets.chomp
      if msg.include? '#'
        puts "Sending your message\n"
      else
        puts "message should have a # atleast once, try again\n"
        chat
      end
     tags=msg.scan(/#\w+/).flatten #Extrat all tags 
     puts tags
     tags.each { |t| generateChatMsg(t, msg) }
 end
  
  def generateChatMsg(tag, msg)
  	puts "Inside generateChatMsg with tag-#{tag}\n"
  	trimTag=tag[1..(tag.length)] #removing the hash character 
    chatMsg={ 
    		  type:"CHAT", 
    		  target_id:HashIt.hashCode(trimTag), 
    		  sender_id:$options[:id], 
    		  tag:trimTag, 
    		  text:msg 
    		}
    puts chatMsg
    whichNodesToSendThis(chatMsg)
  end
  
  def whichNodesToSendThis(chatMsg) #Needs Significant refining
      #Presently for simplicity, just send it to all the nodes, including yourself
      @routing_table.each_value do |v|
      	puts "Sending message to #{v[:ip_address]}"
        sendMsg(chatMsg, v[:ip_address])
      end
  end
  
  def ping
    puts "Inside ping\n"
  end

  def retrive
    puts "Inside retrive\n"
  end

  def leave
    puts "Inside leave\n"
    leaveMsg= { type:"LEAVING_NETWORK", node_id: $options[:id] }
    
    @routing_table.each_value do |v|
       puts "log: Before if, routing_table= #{@routing_table}\n"
       puts "log: #{v[:node_id]} != #{$options[:id]}\n"
       if v[:node_id]!=$options[:id] #So that it may not send the message to itself
       puts "Sending message to #{v[:ip_address]}"
       sendMsg(leaveMsg, v[:ip_address]) 
       end
    end
    puts "Goodbye\n"
    exit
  end

  def handleJoinNetwork(attributes)
    puts "Inside handleJoinNetwork"
    @routing_table[attributes.fetch("node_id")] = { node_id: attributes.fetch("node_id"), ip_address: attributes.fetch("ip_address")}
    puts "Printing routing table"
    puts @routing_table
    routeInfoMsg=buildRouteInfoMsg(attributes)
    sendMsg(routeInfoMsg, attributes.fetch("ip_address"))
  end

  def buildRouteInfoMsg(attributes)
    puts "Building Route Info Message"
    routeInfoMsg= { 
                    type:"ROUTING_INFO", 
                    gateway_id: $options[:id], 
                    node_id: attributes.fetch("node_id"), 
                    ip_address: attributes.fetch("ip_address"),
                    route_table: @routing_table.values
                  }
    puts "routeInfoMsg = #{routeInfoMsg}"
    return routeInfoMsg
  end
 
  def listen
    puts "Listening for messages \n"
    while true
      @msgRecvPool.process {
      message, _ = @udp_node.recvfrom(1024)
      puts "Got input"
      attributes=parseMsg(message)
      msgType=findMsgType(attributes)
      handleMsg(msgType, attributes)
      #welcome(client)
      #new_Connection(client)
      }
    end
  end
end

if __FILE__ == $0
  #cmd arguments
  $options = {} #Stores id of the node, and ip of the Gateway, if the node is the gateway, then ip=""

  optparse = OptionParser.new do|opts|
    opts.banner = "Usage: Server.rb [host] [Port] [options]"

    opts.on("-b", "--boot [ID]", Integer,"Creates first node in the P2P Network with provided id") do |v|
      $options[:id]=v
      $options[:ip]=""
    end
    
    opts.on("-s", "--bootstrap IP_Address", "Attaches node to gateway node having the specified IP address") do |v|
      $options[:ip]=v
    end

    opts.on("--id [ID]", Integer, "Specifies the id of the node on bootstrap, mandatory to give after --bootstrap option") do |v|
      $options[:id] = v
    end

    opts.on_tail("-h", "--help", "Displays this message") do 
      puts opts
      exit
    end
  end #end of optparse

  begin
    optparse.parse!
    mandatory = [:ip, :id]
    missing = mandatory.select{ |v| $options[v].nil? }
    unless missing.empty?
      puts "Missing options: --boot [ID] or --bootstrap IP_Address --id [ID]"
      puts optparse
      exit
    end
  rescue OptionParser::InvalidOption
    puts $!.to_s                                                           
    puts optparse                                                          
    exit                                                                   
  end 

  puts "Initialized with options- #{$options}"
  server = Server.new(ARGV[0]||"localhost", ARGV[1]||8767)
  server.determine
end
