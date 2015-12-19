# P2P Chat System (Based on Pastry)
#####Individual Programming Project

Author: Harpreet Singh

####Background

1. This is a no frills implementation of a P2P chat System based on Pastry
2. Each Node can send and recieve messages, simultaneously acting as a server
   and client, which is really cool
2. All communication is done on *port 8767* by default via **UDP** sockets because `TCP sucks` 
3. All messages are sent in **JSON format** using standard ruby json libraries
4. A joining node has to **know** the **ip address** of any node *already* in the network
5. Messages are sent back and forth via Prefix routing 

####Starting the network

1. Be Sure to have `ruby 2.x` installed and added to your system `PATH`
2. cd into this repo
3. To initialize the first node in the network use the following command:

```
$ ruby Server.rb [ip_address] [port_no] --boot [integer identifier]
```    
4. Subsequently, more nodes can be added in the network using the command:

```   
$ ruby Server.rb [ip_address] [port_no] --bootstrap [IP Address] --id[integer identifier]
```

**Note**: The ip address after --bootstrap option should be a valid ip of any other node
already present in the network for communication to commence!!

####TCP Chat Server
##########Lab 2 & Lab 3

To have a look at that, just change branch to lab3
or checkout the repo- https://github.com/omnigrass/Ruby-ChatServer

#####Enjoy
