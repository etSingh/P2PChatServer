#--
#         This class serves as a client side of the node, essentialy facilitating the user to send
#         different messages supported by the protocol
#         Messages generated by client: JOINING_NETWORK, CHAT, CHAT_RETRIVE, LEAVE_NETWORK, and PING
#         Messages handled by client: CHAT_RESPONSE, ACK and ACK_CHAT 
#         Author: Harpreet Singh
#         Version 1, December 2015
#++   

require 'socket'
require 'json'
require 'timeout'

class Client

 attr_accessor :routing_table, :chatResponseAck, :pingAck

def initialize(host, port, id, node)
	@host=host
	@port=port
	@id=id
	@node=node #The udp node
  @routing_table=Hash.new
  @routing_table[@id]={ node_id:@id, ip_address:@host}
  @chatResponseAck=false # set to true in Server.rb if a Chat_Response message is recieved
  @pingAck=false         # set to true in Server.rb if an ACK message is recieved
  menu
end

def sendJoinNetwork #Sent initially when bootstrapping if the node isn't the gateway
    joinMsg={ type:"JOINING_NETWORK", node_id:@id, ip_address:@host }
    sendMsg(joinMsg, @id)  
end

def sendMsg(msg, ip)
    puts "sending message #{msg.to_json}\n"
    @node.send(msg.to_json, 0, ip, @port)
    puts "message sent to #{ip}" 
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
  
  def generateChatMsg(tag, msg) #Generates CHAT messages corresponding to the tags entered
  	puts "Inside generateChatMsg with tag-#{tag}\n"
  	trimTag=tag[1..(tag.length)] #removing the hash character 
    targetId=HashIt.hashCode(trimTag) #hash of the tag, the node having id closed to that will respond
    chatMsg={ 
      		  type:"CHAT", 
      		  target_id:targetId, 
      		  sender_id:@id, 
      		  tag:trimTag, 
      		  text:msg 
      		  }
    puts chatMsg
    ip=getTheNodeToSend(targetId) 
      sendMsg(chatMsg, ip)   
  end

  def handleAckChat(attributes) 
    targetId=HashIt.hashCode(attributes.fetch("tag"))
    ip= getTheNodeToSend(targetId)
    if ip==@host
      puts "Ack_CHAT recieved for chat msg with tag #{attributes.fetch("tag")}\n"
    else
      puts "log: forwarding ACK_CHAT to #{ip}\n"
      sendMsg(attributes, ip)
    end
  end 

  def generateChatRetriveMsg(tag) #Generates CHAT_RETRIVE messages corresponding to the tags entered
     puts "Inside generateChatRetriveMsg with tag #{tag} \n"
     node_id=HashIt.hashCode(tag) #this should go to the node having the id closest to the hash of the tag
     puts node_id
     retriveMsg={
                 type:"CHAT_RETRIVE",
                 tag:tag,
                 node_id:node_id,
                 sender_id:@id          
                } 
      puts retriveMsg
      ip=getTheNodeToSend(node_id) 
      sendMsg(retriveMsg, ip)   
      if responseTimeout(30)   #Timeout for 30 seconds, if no response recieved then ping is sent
       puts "Error: Chat retrive request timed out for #{tag}\n"
       ping(node_id, ip)
      end
  end

  def responseTimeout(time) #Checks for CHAT_RESPONSE msg arrival, returns true if arrival times out
    puts "Inside ackTimeout\n"
      begin
      timeout(time) do  # if @chatResponseAck isnt true in 30 sesonds, then throws exception
        while !@chatResponseAck
        end
      end
        rescue Timeout::Error
          return true
        end  
        return false
  end

  def pingTimeout(time)   #Checks for CHAT_RESPONSE msg arrival, returns true if arrival times out 
    puts "Inside pingTimeout\n"
    begin
      timeout(time) do  # if pingAck isnt true in 30 sesonds, then throws exception
        while !@pingAck
        end
      end
        rescue Timeout::Error
          return true
        end  
        return false
  end

  
  def ping(node_id, ip)
    puts "Inside ping\n"
    pingMsg={
             type:"PING",
             target_id:node_id, #hash of the chat_retrive tag
             sender_id:@id,
             ip_address:@host #changes on each hop
            }
            sendMsg(pingMsg, ip)#ip address of the node that will get the ping
        if pingTimeout(10)   # Timeout for 10 seconds, if no response recieved, then removes entry
           puts "Error: Ping timed out\n"
           removeEntry(ip)
        end     
  end

  def handleChatResponse(attributes)
     puts "InsideChatResponse\n"
     puts "Chat Response for tag #{attributes.fetch("tag")}:\n"
     puts attributes.fetch("response")
     @chatResponseAck=false #Reinitializing it for next time
  end


  def removeEntry(ip)           #removes the entry corresponding to the ip address
    @routing_table.each_value do |v|
      if v[:ip_address]==ip
        node_id=v.fetch(:node_id)
        puts "Node #{node_id} removed from routing table\n"
        @routing_table.delete(node_id)
      end
    end
  puts "New routing table= #{@routing_table}\n"
  end
  
  def handlePingAck(attributes)
      puts "Ping Ack recieved\n"
      puts "The route is still valid for #{attributes.fetch("node_id")}\n"
      @pingAck=fales #Reinitializing it for next time
  end

  def parseMsg(message)
      attributes=JSON.parse(message)
      return attributes.fetch("type")
  end

  def getTheNodeToSend(targetId)     #This method determines the node with the GUID
    puts "Inside getTheNodeToSend\n" #which is closest to the targetID from the routing table
    min=(@id-targetId).abs           #of the node and returns it's ip address
    target=-9999
    @routing_table.each_value do |v|
      a=(targetId-v[:node_id]).abs
      if a<=min 
        target=v[:node_id]
        puts "target updated to: #{v[:node_id]}"
      end
    end
    ip=@routing_table[target][:ip_address]
    return ip
  end
  
def retrive
    puts "Inside retrive\n"
    puts "Enter the tag for which you would like to retrive chat\n"
    tag=$stdin.gets.chomp
    t=pruneTag(tag)
    puts "Building message to retrive chat with the tag #{t}\n"
    generateChatRetriveMsg(t)
end

def pruneTag(tag)
    if tag.include? ' '
      puts tag.index(' ')
      t=tag[0..(tag.index(' ')-1)]
      return t
    elsif tag.include? '#'
      t=tag[1..(tag.length)]
      return t
    else
      t=tag
      return t
    end
end

def leave
    puts "Inside leave\n"
    leaveMsg= { type:"LEAVING_NETWORK", node_id:@id }
    
    @routing_table.each_value do |v|
       puts "log: Before if, routing_table= #{@routing_table}\n"
       #puts "log: #{v[:node_id]} != #{@id}\n"
       if v[:node_id]!=@id #So that it may not send the message to itself
       puts "Sending message to #{v[:ip_address]}"
       sendMsg(leaveMsg, v[:ip_address]) 
       end
    end
    puts "Goodbye\n"
    exit
  end

end







