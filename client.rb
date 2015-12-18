#This class serves as a client, essentialy facilitating the user to send
#different messages supported by the protocol
#Author: Harpreet Singh

require 'socket'
require 'json'


class Client

 attr_accessor :routing_table

def initialize(host, port, id, node)
	@host=host
	@port=port
	@id=id
	@node=node #The udp node
    @routing_table=Hash.new
    @routing_table[@id]={ node_id:@id, ip_address:@host}
    menu
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
  
  def whichNodesToSendThis(chatMsg) #Will be exactly similar to getthenodetosendthis
      #Presently for simplicity, just send it to all the nodes, including yourself
      puts "log: Inside whichNodesToSendThis printing routing table"
      puts @routing_table
      @routing_table.each_value do |v|
      		#if v[:node_id]!=$options[:id]
      			puts "Sending message to #{v[:ip_address]}"
        		sendMsg(chatMsg, v[:ip_address])
        	#end
      end
  end

  def sendMsg(msg, ip)
    puts "sending message #{msg.to_json} from sendingGateway"
    @node.send(msg.to_json, 0, ip, @port)
    puts "message sent to #{ip}" 
  end

def retrive
    puts "Inside retrive\n"
end

def leave
    puts "Inside leave\n"
    leaveMsg= { type:"LEAVING_NETWORK", node_id: $options[:id] }
    
    @routing_table.each_value do |v|
       puts "log: Before if, routing_table= #{@routing_table}\n"
       puts "log: #{v[:node_id]} != #{@id}\n"
       if v[:node_id]!=@id #So that it may not send the message to itself
       puts "Sending message to #{v[:ip_address]}"
       sendMsg(leaveMsg, v[:ip_address]) 
       end
    end
    puts "Goodbye\n"
    exit
  end


end







