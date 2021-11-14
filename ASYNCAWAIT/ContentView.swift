//
//  ContentView.swift
//  ASYNCAWAIT
//
//  Created by Vasileios  Gkreen on 10/11/21.
//

import SwiftUI

struct ContentView: View {
	@State private var site = "https://"
	@State private var sourceCode = ""
	
	var body: some View {
		VStack {
			HStack {
				TextField("Website address", text: $site)
					.textFieldStyle(.roundedBorder)
				
				Button("Go") {
					Task { // use Task to run async code from a sync function
						await fetchSource()
						await processWeather()
						await loadData()
						let _ = await fetchMessages()
						let _ = await fetchMessages1()
					}
				}
			}
			.padding()
			
			ScrollView {
				Text(sourceCode)
			}
		}
	}
	
	
	
	// MARK: async / await that throws
	func fetchSource() async {
		do {
			let url = URL(string: site)!
			let (data, _) = try await URLSession.shared.data(from: url)
			sourceCode = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
		} catch {
			sourceCode = "Failed to fetch \(site)"
		}
	}
	
	
	
	// MARK: Multiple async functions that run sequentially
	func fetchWeatherHistory() async -> [Double] {
		(1...100_000).map { _ in Double.random(in: -10...30) }
	}
	
	func calculateAverageTemperature(for records: [Double]) async -> Double {
		let total = records.reduce(0, +)
		let average = total / Double(records.count)
		return average
	}
	
	func upload(result: Double) async -> String {
		"OK"
	}
	
	/*
		This async function as it is also in JS will first run fetchWeatherHistory()
		it will await for the result and only when it's finished will go on and
		run the next function calculateAverageTemperature() and so on
	 */
	func processWeather() async {
		let records = await fetchWeatherHistory()
		let average = await calculateAverageTemperature(for: records)
		let response = await upload(result: average)
		print("Server response: \(response)")
	}
	
	
	
	// MARK: Runs async functions in parallel
	/*
		We can use async let to run two or more async functions in parallel.
		In this way we don't have to await for one to finish to move on to the enxt one.
		Useful for when these function don't depend on the result of one or another
	 
		We will need to await anyway to read the results in the end.
	 
	 */
	struct User: Decodable {
		let id: UUID
		let name: String
		let age: Int
	}
	struct Message: Decodable, Identifiable {
		let id: Int
		let from: String
		let message: String
	}
	
	func loadData() async {
		async let (userData, _) = URLSession.shared.data(from: URL(string: "https://hws.dev/user-24601.json")!)
		
		async let (messageData, _) = URLSession.shared.data(from: URL(string: "https://hws.dev/user-messages.json")!)
		
		do {
			let decoder = JSONDecoder()
			let user = try await decoder.decode(User.self, from: userData)
			let messages = try await decoder.decode([Message].self, from: messageData)
			print("User \(user.name) has \(messages.count) message(s).")
		} catch {
			print("Sorry, there was a network problem.")
		}
	}
	
	
	
	// MARK: Asyncronously calling a sync function with an escaping closure
	struct Message1: Decodable, Identifiable {
		let id: Int
		let from: String
		let message: String
	}
	
	func fetchMessages(completion: @escaping ([Message1]) -> Void) {
		let url = URL(string: "https://hws.dev/user-messages.json")!
		
		URLSession.shared.dataTask(with: url) { data, response, error in
			if let data = data {
				if let messages = try? JSONDecoder().decode([Message1].self, from: data) {
					completion(messages)
					return
				}
			}
			
			completion([])
		}.resume()
	}
	
	/*
		We need to add withCheckedContinuation() that unpauses the function when the result is returned
		We basically manually inform the function to stop awaiting because the result is returned
	 */
	func fetchMessages() async -> [Message1] {
		await withCheckedContinuation { continuation in
			fetchMessages { messages in
				continuation.resume(returning: messages)
			}
		}
	}
	

	/*
		We can also throw an error in any case by using withCheckedThrowingContinuation()
		In this example we check the api call returns any mesasges. If not we check if the array returned is empty
		and if so we throw an error -- which has as a default action to return a "placeholder/welcome" message
	 */
	enum FetchError: Error {
		case noMessages
	}
	func fetchMessages1() async -> [Message1] {
		do {
			return try await withCheckedThrowingContinuation { continuation in
				fetchMessages { messages in
					if messages.isEmpty {
						continuation.resume(throwing: FetchError.noMessages)
					} else {
						continuation.resume(returning: messages)
					}
				}
			}
		} catch {
			return [
				Message1(id: 1, from: "Tom", message: "Welcome to MySpace! I'm your new friend.")
			]
		}
	}
	
}


