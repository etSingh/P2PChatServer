# P2P Chat Server (Based on Pastry)

Author: Harpreet Singh

####Background

1. Each Node can send and recieve messages
2. All communication is done via **UDP** sockets on *port 8767* by default
3. All messages are sent in **JSON format** using standard ruby json libraries
4. A joining node has to *know* the ip address of any node *already* in the network

####Starting the network

1. cd into this repo
2. To initialize the first node in the network use the following command:
```
    $ ruby Server.rb [ip_address] [port_no] --boot [integer identifier]
```    
3. Subsequently, more nodes can be added in the network using the command:
```   
    $ ruby Server.rb [ip_address] [port_no] --bootstrap [IP Address] --id[integer identifier]
```
*Note*: The ip address after --bootstrap option should be a valid ip of any other node
already present in the network

#####More Documentation about all the features soon!
