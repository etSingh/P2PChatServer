class chatroom
	def initialize 
	end

	def chatRoom(chatRoomName, client)
    flag=0
    room_ref=hashCode(chatRoomName)
    @chatRooms.each do |key, value| #Checks to see if chatroom is already present, if it is, then adds the client
      if key==room_ref
        flag=1
        @chatRooms[key] += [client]
      end
    end
    if flag==0
    @roomName[room_ref]=chatRoomName
    @chatRooms[room_ref] += [client]
    end
    @clientRooms[client] += [room_ref]
    puts "log:client #{client} added to chatroom #{chatRoomName} Ref:#{room_ref}"
    return room_ref
  end

  def welcomeMessage(room_ref, client)
    msg="#{@clientName[@clientSoc[client]]} has joined this chatroom.\n"
    broadcastMessage(room_ref, msg, client)
    puts "log: Welcome message sent \n"
  end

  def broadcastMessage(room_ref, str, client)
    @chatRooms[room_ref].each do | cli |
      cli.puts "CHAT:#{room_ref}\nCLIENT_NAME:#{@clientName[@clientSoc[client]]}\nMESSAGE:#{str}\n"
    end
    puts "******************Broadcast Message********************"
    puts "CHAT:#{room_ref}\nCLIENT_NAME:#{@clientName[@clientSoc[client]]}\nMESSAGE:#{str}\n"
    puts "*******************************************************" 
  end

  def sendJoinReqMsg(join_details, client)
    room_ref=chatRoom(join_details[0], client)
    client.puts "JOINED_CHATROOM:#{join_details[0]}\nSERVER_IP:#{@host}\nPORT:#{@port}\nROOM_REF:#{@roomName.key(join_details[0])}\nJOIN_ID:#{@clientName.key(join_details[3])}\n"
    puts "log: Join request message sent to client #{client}"
    welcomeMessage(room_ref, client) #Send a welcome message to the client
  end
  
  def removeClientEntry(leave_details, client)
    @clientRooms[client] -= [leave_details[0]]
    @chatRooms[leave_details[0]] -= [client]
  end
  
  def sendleaveNotification(room_ref, str, client)
      client.puts "CHAT:#{room_ref}\nCLIENT_NAME:#{@clientName[@clientSoc[client]]}\nMESSAGE:#{str}\n"
      puts "Leave notification sent to #{client}\n"
  end
  
  def sendleaveMsg(leave_details, client)
      client.puts "LEFT_CHATROOM:#{leave_details[0]}\nJOIN_ID:#{leave_details[1]}"
      puts "log: Leave request message sent to client #{client}"
      removeClientEntry(leave_details, client)
      room_ref=leave_details[0]
      msg="#{@clientName[@clientSoc[client]]} has left this chatroom\n"
      sendleaveNotification(room_ref, msg, client)
      puts "Broadcasting leave message to others"
      broadcastMessage(room_ref, msg, client)
  end
  
  def servJoinReq(input,client)
    join_details=Array.new 
    join_details[0]=input.slice((input.index(':')+1)..input.length).chomp
    i=1
      while (i<=3) # This loop extracts the client details from the join request and stores it in the join_details array
          input=client.gets.chomp
          join_details[i]=input.slice((input.index(':')+1)..input.length).chomp
          if i==3 #Checks to see if the client name is already taken
           saveUserName(join_details[3], client)
          end
          i+=1
      end
      sendJoinReqMsg(join_details, client)
    end

  def saveUserName(input, client) 
      clientID=hashCode(input)
      @clientName[clientID]=input 
      @clientSoc[client]=clientID
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
    sendleaveMsg(leave_details, client)
  end
  
  def handleChatMsg(input, client)
   i=1
   room_ref=input.slice((input.index(':')+1)..input.length).to_i
   while i<=4
      input=client.gets
      if i==3
        msg=input.slice((input.index(':')+1)..input.length)
      end
      i+=1
    end
   puts "Broadcasting chat message where msg= #{msg}"
   broadcastMessage(room_ref, msg, client)
  end
  
  def raiseError(id, client)
    if id==0
      client.puts "ERROR_CODE:#{id}\nERROR_DESCRIPTION:Username already taken!! "
    end
  end
  
  def handleDisconnectMsg(client)
     puts "Inside handledisconnectmessage"
     input=client.gets
     port=input.slice((input.index(':')+1)..input.length).to_i
     input=client.gets
     cliName=input.slice((input.index(':')+1)..input.length)
     erase(client)
  end

  def erase(client)
    msg="#{@clientName[@clientSoc[client]]} has disconnected\n"
    puts "log: #{msg}"
    @clientRooms[client].each do | room |
      broadcastMessage(room, msg, client)
      @chatRooms[room] -= [client]
    end
    @clientRooms.delete(client)
    @descriptors.pop(client)
    @clientName.delete(@clientSoc[client])
    @clientSoc.delete(client)
    puts "client #{client} disconnected"
    client.close
  end