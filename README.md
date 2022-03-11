# EnetLobby

Language: GDScript
Renderer: GLES 2

This project is meant only to demonstrate how to manage a lobby with peer matching
and follows the (client-server-client) communication model
so basically 

CLIENT_A >>notifies>> SERVER >>notifies>> CLIENT_B

in this way 

	PROS:
		nothing happens without the SERVER's knowledge
		only SERVER keeps record of each peer's information
		
	CONS:
		peers are not aware of all other peers and will only directly communicate with the ones in same room
		less flexibility when options are changed
		if SERVER goes offline during critical point no way to resume
		
The approach here is whenever a change is made to the server all peers are notified through an rpc to update
To use/test run one instance as Server using the "Host" button then run multiple instances using the "Join"
on either the same machine with localhost or multiple devices on the same network
