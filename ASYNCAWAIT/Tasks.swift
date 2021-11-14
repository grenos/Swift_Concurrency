//
//  Tasks.swift
//  ASYNCAWAIT
//
//  Created by Vasileios  Gkreen on 10/11/21.
//

import SwiftUI



struct NewsItem: Decodable {
	let id: Int
	let title: String
	let url: URL
}

struct HighScore: Decodable {
	let name: String
	let score: Int
}

// MARK: Using tasks that return a value

/*
	We can use tasks to return a value. The syntax is similar to a JS callback fn
	To read the returned value we just have to access the value property of the Task using await
	** NOTE ** Tasks run immediately after being called.
 */


func fetchUpdates() async {
	let newsTask = Task { () -> [NewsItem] in
		let url = URL(string: "https://hws.dev/headlines.json")!
		let (data, _) = try await URLSession.shared.data(from: url)
		return try JSONDecoder().decode([NewsItem].self, from: data)
	}
	
	let highScoreTask = Task { () -> [HighScore] in
		let url = URL(string: "https://hws.dev/scores.json")!
		let (data, _) = try await URLSession.shared.data(from: url)
		return try JSONDecoder().decode([HighScore].self, from: data)
	}
	
	do {
		let news = try await newsTask.value
		let highScores = try await highScoreTask.value
		print("Latest news loaded with \(news.count) items.")
		
		if let topScore = highScores.first {
			print("\(topScore.name) has the highest score with \(topScore.score), out of \(highScores.count) total results.")
		}
	} catch {
		print("There was an error loading user data.")
	}
}



// MARK: Using tasks with Result to throw specific errors

enum LoadError: Error {
	case fetchFailed, decodeFailed
}

func fetchQuotes() async {
	let downloadTask = Task { () -> String in
		let url = URL(string: "https://hws.dev/quotes.txt")!
		let data: Data
		
		do {
			(data, _) = try await URLSession.shared.data(from: url)
		} catch {
			throw LoadError.fetchFailed
		}
		
		if let string = String(data: data, encoding: .utf8) {
			return string
		} else {
			throw LoadError.decodeFailed
		}
	}
	
	let result = await downloadTask.result
	
	do {
		let string = try result.get()
		print(string)
	} catch LoadError.fetchFailed {
		print("Unable to fetch the quotes.")
	} catch LoadError.decodeFailed {
		print("Unable to convert quotes to text.")
	} catch {
		print("Unknown error.")
	}
}




// MARK: Giving priority to a Task
/*
	1) The highest priority is .high, which is synonymous with .userInitiated. As the name implies,
		this should be used only for tasks that the user specifically started and is actively waiting for.
 
	2) Next highest is medium, and again as the name implies this is a great choice for most of your tasks that the user isn’t actively waiting for.
 
	3) Next is .low, which is synonymous with .utility. This is the best choice for anything long enough to require a
		progress bar to be displayed, such as copying files or importing data.
 
	4)The lowest priority is .background, which is for any work the user can’t see, such as building a search index.
		This could in theory take hours to complete.
 */
func fetchQuotes1() async {
	let downloadTask = Task(priority: .high) { () -> String in
		let url = URL(string: "https://hws.dev/chapter.txt")!
		let (data, _) = try await URLSession.shared.data(from: url)
		return String(decoding: data, as: UTF8.self)
	}
	
	do {
		let text = try await downloadTask.value
		print(text)
	} catch {
		print(error.localizedDescription)
	}
}




//MARK: Cancelling a Task

/*
	Cancelling a Task throws a Cancelation Error. URLSession also throws an error (and subsequently gets the Task cancelled)
	In this example we return a default value of 0 if the task fails by any reason
 */

func getAverageTemperature() async {
	let fetchTask = Task { () -> Double in
		let url = URL(string: "https://hws.dev/readings.json")!
		
		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			if Task.isCancelled { return 0 }
			
			let readings = try JSONDecoder().decode([Double].self, from: data)
			let sum = readings.reduce(0, +)
			return sum / Double(readings.count)
		} catch {
			return 0
		}
	}
	
	fetchTask.cancel()
	
	let result = await fetchTask.value
	print("Average temperature: \(result)")
}




//MARK: Put a Task to Sleep

/*
	Basically a setTimeOut in JS
 */
//try await Task.sleep(nanoseconds: 3_000_000_000)




//MARK: Using Task Groups

/*
	1) task groups are collections of tasks that work together to produce a single result.
	2) Each task inside the group must return the same kind of data,
	3) task results are sent back in completion order and not creation order.
		(so will need to be sorted in some specific order if needed before rendering them)
 */
struct NewsStory: Identifiable, Decodable {
	let id: Int
	let title: String
	let strap: String
	let url: URL
}

struct GroupTasks: View {
	@State private var stories = [NewsStory]()
	
	var body: some View {
		NavigationView {
			List(stories) { story in
				VStack(alignment: .leading) {
					Text(story.title)
						.font(.headline)
					
					Text(story.strap)
				}
			}
			.navigationTitle("Latest News")
		}
		.task {
			await loadStories()
		}
	}
	
	func loadStories() async {
		do {
			stories = try await withThrowingTaskGroup(of: [NewsStory].self) { group -> [NewsStory] in
				for i in 1...5 {
					group.addTask {
						let url = URL(string: "https://hws.dev/news-\(i).json")!
						let (data, _) = try await URLSession.shared.data(from: url)
						return try JSONDecoder().decode([NewsStory].self, from: data)
					}
				}
				
				let allStories = try await group.reduce(into: [NewsStory]()) { $0 += $1 }
				return allStories.sorted { $0.id > $1.id }
			}
		} catch {
			print("Failed to load stories")
		}
	}
}



//MARK: Fetch diferent results with a single Task Group

/*
	We can Fetch diferent result with a single task group by creating an enum that represents
	each of the diferent values the group is fetching
 */

// A struct we can decode from JSON, storing one message from a contact.
struct Message: Decodable {
	let id: Int
	let from: String
	let message: String
}

// A user, containing their name, favorites list, and messages array.
struct User {
	let username: String
	let favorites: Set<Int>
	let messages: [Message]
}

// A single enum we'll be using for our tasks, each containing a different associated value.
enum FetchResult {
	case username(String)
	case favorites(Set<Int>)
	case messages([Message])
}

func loadUser() async {
	// Each of our tasks will return one FetchResult, and the whole group will send back a User.
	let user = await withThrowingTaskGroup(of: FetchResult.self) { group -> User in
		// Fetch our username string
		group.addTask {
			let url = URL(string: "https://hws.dev/username.json")!
			let (data, _) = try await URLSession.shared.data(from: url)
			let result = String(decoding: data, as: UTF8.self)
			
			// Send back FetchResult.username, placing the string inside.
			return .username(result)
		}
		
		// Fetch our favorites set
		group.addTask {
			let url = URL(string: "https://hws.dev/user-favorites.json")!
			let (data, _) = try await URLSession.shared.data(from: url)
			let result = try JSONDecoder().decode(Set<Int>.self, from: data)
			
			// Send back FetchResult.favorites, placing the set inside.
			return .favorites(result)
		}
		
		// Fetch our messages array
		group.addTask {
			let url = URL(string: "https://hws.dev/user-messages.json")!
			let (data, _) = try await URLSession.shared.data(from: url)
			let result = try JSONDecoder().decode([Message].self, from: data)
			
			// Send back FetchResult.messages, placing the message array inside
			return .messages(result)
		}
		
		// At this point we've started all our tasks,
		// so now we need to stitch them together into
		// a single User instance. First, we set
		// up some default values:
		var username = "Anonymous"
		var favorites = Set<Int>()
		var messages = [Message]()
		
		// Now we read out each value, figure out
		// which case it represents, and copy its
		// associated value into the right variable.
		do {
			for try await value in group {
				switch value {
					case .username(let value):
						username = value
					case .favorites(let value):
						favorites = value
					case .messages(let value):
						messages = value
				}
			}
		} catch {
			// If any of the fetches went wrong, we might
			// at least have partial data we can send back.
			print("Fetch at least partially failed; sending back what we have so far. \(error.localizedDescription)")
		}
		
		// Send back our user, either filled with
		// default values or using the data we
		// fetched from the server.
		return User(username: username, favorites: favorites, messages: messages)
	}
	
	// Now do something with the finished user data.
	print("User \(user.username) has \(user.messages.count) messages and \(user.favorites.count) favorites.")
}


