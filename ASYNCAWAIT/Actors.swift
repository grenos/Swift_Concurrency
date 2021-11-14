//
//  Actors.swift
//  ASYNCAWAIT
//
//  Created by Vasileios  Gkreen on 12/11/21.
//

import SwiftUI
import CryptoKit

//MARK: Actors

/*
 Actors are conceptually like classes that are safe to use in concurrent environments.
 This safety is made possible because Swift automatically ensures no two pieces of code attempt to access an actor’s data at the same time
 
 
	1) Like classes, actors are reference types. This makes them useful for sharing state in your program.
	2) if you’re attempting to read a variable property or call a method on an actor,
		and you’re doing it from outside the actor itself, you must do so asynchronously using await.
 
 
 
 https://www.hackingwithswift.com/quick-start/concurrency/what-is-an-actor-and-why-does-swift-have-them
 */



//	The new User1 type is created using the actor keyword rather than struct or class.
actor User1 {
	
	//	It can have properties and methods just like structs or classes.
	var score = 10
	
	func printScore() {
		// The printScore() method can access the local score property just fine, because it’s our actor’s method reading its own property.
		print("My score is \(score)")
	}
	
	// But in copyScore(from:) we’re attempting to read the score from another user, and we can’t read their score property without marking the request with await.
	func copyScore(from other: User1) async {
		score = await other.score
	}
}



// MARK: Actors Use cases


//An actor queues "requests" to do stuff in a serial way.
// So for example we could use in a case where we want to avoid race conditions between data.
// On the other hand it would't be that useful as a general catch all solution because it will wait to finish one "job" to start another
// so for example:


// NOT USEFULL EXAMPLE

// this general use cache manager will only make api calls one at a time.
actor URLCache {
	private var cache = [URL: Data]()
	
	func data(for url: URL) async throws -> Data {
		if let cached = cache[url] {
			return cached
		}
		
		let (data, _) = try await URLSession.shared.data(from: url)
		cache[url] = data
		return data
	}
}



//GOOD USE OF ACTORS

/*
 
	An actor that send money from our bank account to another. If we had used a class it would be possible to create
	data races between two transfers and for example try to send more money they can afford.
 
	Using an actors means that transfer() called from a thread will have to finish its job so the actor can re-call transfer() callwed from another thread / Instance
 
 */

actor BankAccount {
	var balance: Decimal
	
	init(initialBalance: Decimal) {
		balance = initialBalance
	}
	
	func deposit(amount: Decimal) {
		balance = balance + amount
	}
	
	func transfer(amount: Decimal, to other: BankAccount) async {
		// Check that we have enough money to pay
		guard balance > amount else { return }
		
		// Subtract it from our balance
		balance = balance - amount
		
		// Send it to the other account
		await other.deposit(amount: amount)
	}
}



// MARK: Extract isolated functions from actors

/*
	We can extract a function from an actor (or just create it outside of it) and mark it with the "isolated" keyward.
	This means that we can create a function that doesn't need the await keyword and can access AND modify internal values
	of that actors from outside!
 
 */

actor DataStore {
	var username = "Anonymous"
	var friends = [String]()
	var highScores = [Int]()
	var favorites = Set<Int>()
}

func debugLog(dataStore: isolated DataStore) {
	print("Username: \(dataStore.username)")
	print("Friends: \(dataStore.friends)")
	print("High scores: \(dataStore.highScores)")
	print("Favorites: \(dataStore.favorites)")
}


struct Actors: View {
	let ds = DataStore()
	
	var body: some View {
		Button {
			Task {
				await debugLog(dataStore: ds)
			}
		} label: {
			Text("Click me")
		}
		
	}
}

struct Actors_Previews: PreviewProvider {
	static var previews: some View {
		Actors()
	}
}


// MARK: Make parts of an actor NON isolated and access then from outside without awaiting
/*
	1) Actors methods that are non-isolated can access other non-isolated state, such as constant properties or other methods that are marked non-isolated.
	2) However, they cannot directly access isolated state like an isolated actor method would; they need to use await instead.
	3) Non-isolated properties and methods can access only other non-isolated properties and methods, which in our case is a constant property
 */

 
actor User66 {
	let username: String
	let password: String
	var isOnline = false
	
	init(id: UUID, username: String, password: String) {
		self.username = username
		self.password = password
	}
	
	nonisolated func passwordHash() -> String {
		let passwordData = Data(password.utf8)
		let hash = SHA256.hash(data: passwordData)
		return hash.compactMap { String(format: "%02x", $0) }.joined()
	}
}


var user = User66(id: UUID(), username: "Bobo", password: "123123123")
var pass = user.passwordHash()




//MARK: @MainActor

/*
	A class or a struct marked with @MainActor will always run on the main thread.
	So use it when you want to update the UI.
 */


/*
 @ObservableObject, @StateObject and Body in a SwiftUi view always run on a main actor. But it's a good practice to mark your
 @ObservableObject with the @MainActor to ensure that everything runs in the main thread
 
 if you want to exclude a method or a computed property from running on the main actor you can use the "nonisolted" as you would do with a
 normal actor as we have sheen above.
 
 The magic of @MainActor is that it automatically forces methods or whole types to run on the main actor,
 without any further work from us. Previously we needed to do it by hand, remembering to use code like DispatchQueue.main.async()
 or similar every place it was needed, but now the compiler does it for us automatically.
 
 */
@MainActor
class AccountViewModel: ObservableObject {
	@Published var username = "Anonymous"
	@Published var isAuthenticated = false
}


/*
 If you do need to spontaneously run some code on the main actor, you can do that by calling MainActor.run()
 and providing your work. This allows you to safely push work onto the main actor no matter where your code is currently running,
 like this:
 */
func couldBeAnywhere() async {
	await MainActor.run {
		print("This is on the main actor.")
	}
}


//MARK: global actor inference
/*
	Some types in UIkit or SwiftUI like UIView, UIButton, Body etc inherit implicitly from @MainActor
 
	THERE ARE 5 RULES:
 */



// 1) if a class is marked @MainActor, all its subclasses are also automatically @MainActor
		
// 2) if a method in a class is marked @MainActor, any overrides for that method are also automatically @MainActor

// 3) ny struct or class using a property wrapper with @MainActor for its wrapped value will automatically be @MainActor.
//		This is what makes @StateObject and @ObservedObject convey main-actor-ness on SwiftUI views that use them – if you use
//		either of those two property wrappers in a SwiftUI view, the whole view becomes @MainActor too


// 4)  if a protocol declares a method as being @MainActor, any type that conforms to that protocol
//		will have that same method automatically be @MainActor unless you separate the conformance from the method

// A protocol with a single `@MainActor` method.
protocol DataStoring {
	@MainActor func save()
}

// A struct that does not conform to the protocol.
struct DataStore1 { }

// When we make it conform and add save() at the same time, our method is implicitly @MainActor.
extension DataStore1: DataStoring {
	func save() { } // This is automatically @MainActor.
}

// A struct that conforms to the protocol.
struct DataStore2: DataStoring { }

// If we later add the save() method, it will *not* be implicitly @MainActor so we need to mark it as such ourselves.
extension DataStore2 {
	@MainActor func save() { }
}



// 5) if the whole protocol is marked with @MainActor, any type that conforms to that protocol will also
//		automatically be @MainActor unless you put the conformance separately from the main type declaration,
//		in which case only the methods are @MainActor


// A protocol marked as @MainActor.
@MainActor protocol DataStoring1 {
	func save()
}

// A struct that conforms to DataStoring as part of its primary type definition.
struct DataStore1a: DataStoring1 { // This struct is automatically @MainActor.
	func save() { } // This method is automatically @MainActor.
}

// Another struct that conforms to DataStoring as part of its primary type definition.
struct DataStore2a: DataStoring1 { } // This struct is automatically @MainActor.

// The method is provided in an extension, but it's the same as if it were in the primary type definition.
extension DataStore2a {
	func save() { } // This method is automatically @MainActor.
}

// A third struct that does *not* conform to DataStoring in its primary type definition.
struct DataStore3a { } // This struct is not @MainActor.

// The conformance is added as an extension
extension DataStore3a: DataStoring1 {
	func save() { } // This method is automatically @MainActor.
}
