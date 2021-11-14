#  Some Theory


### The difference between async let, tasks, and task groups



They have one similarity:
	They allow us to run code concurrently 
	
	
They are differnet because:
	1) Task groups automatically let us process results from child tasks in the order they complete, rather than in an order we specify.
		 For example, if you have three possible servers for some data and want to use whichever one responds fastest, task groups are perfect – you can use addTask() 
		 once for each server, then call next() only once to read whichever one responded fastest.
		 
	2) Tasks and Task Groups can be cancelled direclty.
