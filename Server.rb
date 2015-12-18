#This class servers as the message handle, it processes the messages recieved
#from the network and generates appropriate responses, so it effectively acts 
#as a server, handling messages and sending responses
#Author: Harpreet Singh


$LOAD_PATH << '.'
require 'socket'
require 'optparse'
require 'json'
require  "src/hashIt.rb"
require "lib/threadpool.rb"
require "src/chatroom.rb"
require_relative "./client.rb"

class Server

  
  def initialize(host, port)
    @host=host
    @port=port
    @id=$options[:id]
    #@handleChatrooms=Chatroom.new(@host, @port)
    @udp_node= UDPSocket.new
    @udp_node.bind(@host, @port)
    @msgRecvPool=Thread.pool(10)
    @StudentID=ARGV[2]||152
    @chatTextTuple=Hash.new( [].freeze )
    @send=Client.new(host, port, @id, @udp_node)
  end
  
  def determine           #The cmd line options are configured in a way that if the node is initialized 
    if $options[:ip]==""  #as the Gateway then $options[:ip]==""
      puts "Gateway is running on Port #{@port} with id #{@id}..."
      listen
    else
      puts "Sending JOINING_NETWORK message to Gateway\n"
      sendJoinNetwork
      listen
    end
  end

  def sendJoinNetwork
    joinMsg={ type:"JOINING_NETWORK", node_id:$options[:id], ip_address:@host }
    @send.sendMsg(joinMsg, $options[:ip])  
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
    #puts "Inside handleMsg msgType=#{msgType}"
    if msgType=="JOINING_NETWORK"
      handleJoinNetwork(attributes)
    elsif msgType=="ROUTING_INFO"
      handleRouteInfo(attributes)
    elsif msgType=="LEAVING_NETWORK"
      handleLeaveNetwork(attributes)
  	elsif msgType=="CHAT"
  		handleChatMsg(attributes)
  	elsif msgType=="ACK_CHAT"
  		handleAckChat(attributes)
  	elsif msgType=="CHAT_RETRIVE"
  		handleRetriveMsg(attributes)
  	end
  end

  def handleRetriveMsg(attributes) #if this node has the chat, generate response, else forward it on
  	  puts "log: Inside handleRetriveMsg\n"
  	  targetId=attributes.fetch("node_id") #extract the targetId which is the hash of the tag
  	  ip=getTheNodeToSend(targetId) #get the ip address corresponding to the node matching the closest ip
      puts
      if ip==@host
      	puts "This node will generate the response\n"
  	    generateResponseMsg(attributes)
  	  else 							#just forward the message onto the next node
  	  	@send.sendMsg(attributes, ip)
  	  end
  end

  def generateResponseMsg(attributes)
      puts "Inside generateResponseMsg\n"
      puts "Printing attributes\n"
      puts attributes
      tag=attributes.fetch("tag")
      node_id=attributes.fetch("sender_id")
      puts "node_id=#{node_id} tag=#{tag}"
      responseMsg={
      	           type:"CHAT_RESPONSE",
    			   tag:tag,
    			   node_id:node_id,  #The id of the message originator
    			   sender_id:@id,    #The id of this node
    			   response:@chatTextTuple[HashIt.hashCode(tag)]
     			  }
      puts responseMsg
      ip=getTheNodeToSend(node_id)
      @send.sendMsg(responseMsg, ip)
      puts "Response message sent\n"
  end
   
  def handleAckChat(attributes)
    puts "log: need to stop timeout if this is for this node\n"
    targetId=HashIt.hashCode(attributes.fetch("tag"))
  	ip= getTheNodeToSend(targetId)
  	puts "log: Sending Ack to #{ip}\n"
  end 
  
  def getTheNodeToSend(targetId)
    puts "Inside getTheNodeToSend\n"
    min=($options[:id]-targetId).abs
    target=-9999
    @send.routing_table.each_value do |v|
    	a=(targetId-v[:node_id]).abs
    	# puts "log: Absolute diff in this iteration= #{a}\n"
    	if a<=min 
    		target=v[:node_id]
    		puts "target updated to: #{v[:node_id]}"
    	end
    end
    ip=@send.routing_table[target][:ip_address]
    return ip
  end

  def handleChatMsg(attributes)       #Finds the numerically closest node and also extracts the tag if this
  	puts "Inside handleChatMsg\n"     #node is the target
    targetId=attributes.fetch("target_id") #Extracts the id of the tag
    ip=getTheNodeToSend(targetId) #returns the ip address of the node which has the closest id to the tag hash
    	if ip==@host
    		tag=attributes.fetch("tag")
    		puts "log: This node is the target of chat with hash id #{$options[:id]} and tag #{tag}\n"
    		sendAckChat(attributes, tag)
    	else
    		puts "log: This node isn't the target, forwarding the packet to node_id- #{target}\n"
    		@send.sendMsg(attributes, @send.routing_table[target][:ip_address])
    	end
    end

  def prepareChatResponse(attributes)
     puts "Inside prepareChatResponse\n"
     #buid the chat response message here
  end
  
  def sendAckChat(attributes, tag) #If this node is the target, it sends an acknoledgement and stores the message
     puts "Inside sendACK_CHAT\n"
     ackMsg={ type: "ACK_CHAT", node_id:attributes.fetch("sender_id"), tag:tag }
     targetId=HashIt.hashCode(tag)
     ip= getTheNodeToSend(targetId)
     puts "log: Got ip= #{ip}"
     #if ip!=@host
      @send.sendMsg(ackMsg, ip)
     #else
     	#puts "log: You generated the ack message, you're probably the only node on the network\n"
     #end
     storeTheMessage(attributes, targetId)
  end

  def storeTheMessage(attributes, targetId) #work on this buddy
     puts "Inside storeTheMessage\n"
     @chatTextTuple[targetId] += [{ text: attributes.fetch("text") }]	
     puts @chatTextTuple
  end

  def handleLeaveNetwork(attributes)
   @send.routing_table.delete(attributes.fetch("node_id"))
   puts "New Routing table= #{@send.routing_table}"
  end
  
  def handleRouteInfo(attributes)
    puts "Inside handleRouteInfo"
    trimmedMsg=attributes.fetch("route_table")
    puts trimmedMsg
    flag=0
    trimmedMsg.each do |v| #trimmed and attributes are hashes with strings as keys, whatever you recieve is a string key hash
      @send.routing_table.each do |k, d|
          if v.fetch("node_id")==k
              flag=1 #The node is present in the table, won't go ahead with this
          end
      end
          if flag==0 #the node isn't present in the table
              @send.routing_table[v.fetch("node_id")]={ node_id:v.fetch("node_id"), ip_address:v.fetch("ip_address")}
          end
          flag=0
    end       
    puts "Routing table = #{@send.routing_table}\n"
  end
  
 
  def handleJoinNetwork(attributes)
    puts "Inside handleJoinNetwork"
    @send.routing_table[attributes.fetch("node_id")] = { node_id: attributes.fetch("node_id"), ip_address: attributes.fetch("ip_address")}
    puts "Printing routing table"
    puts @send.routing_table
    routeInfoMsg=buildRouteInfoMsg(attributes)
    @send.sendMsg(routeInfoMsg, attributes.fetch("ip_address"))
  end

  def buildRouteInfoMsg(attributes)
    puts "Building Route Info Message"
    routeInfoMsg= { 
                    type:"ROUTING_INFO", 
                    gateway_id: $options[:id], 
                    node_id: attributes.fetch("node_id"), 
                    ip_address: attributes.fetch("ip_address"),
                    route_table: @send.routing_table.values
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
  #--------------------------------------------Command Line Arguments Handler--------------------------------------------------------------
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
#---------------------------------------------End of Command line Arguments Handler-----------------------------------------------------
  
  puts "Initialized with options- #{$options}"
  server = Server.new(ARGV[0]||"localhost", ARGV[1]||8767)
  server.determine
end
