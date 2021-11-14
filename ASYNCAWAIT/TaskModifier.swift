//
//  TaskModifier.swift
//  ASYNCAWAIT
//
//  Created by Vasileios  Gkreen on 11/11/21.
//

import SwiftUI

struct Message9: Decodable, Identifiable {
	let id: Int
	let user: String
	let text: String
}


/*
	A Task Modifier has 2 main points
 
	1) It will run its task every time the view appears and cancel it every time the view disappears
 
	2) A Task can take an identifier and re run it self every time this id changes
		
 */


struct TaskModifier: View {
	@State private var messages = [Message9]()
	@State private var selectedBox = "Inbox"
	let messageBoxes = ["Inbox", "Sent"]
	
	var body: some View {
		NavigationView {
			List {
				Section {
					ForEach(messages) { message in
						VStack(alignment: .leading) {
							Text(message.user)
								.font(.headline)
							
							Text(message.text)
						}
					}
				}
			}
			.listStyle(.insetGrouped)
			.navigationTitle(selectedBox)
			
			// Our task modifier will recreate its fetchData() task whenever selectedBox changes
			.task(id: selectedBox) {
				await fetchData()
			}
			.toolbar {
				// Switch between our two message boxes
				Picker("Select a message box", selection: $selectedBox) {
					ForEach(messageBoxes, id: \.self, content: Text.init)
				}
				.pickerStyle(.segmented)
			}
		}
	}
	
	// This is almost the same as before, but now loads the selectedBox JSON file rather than always loading the inbox.
	func fetchData() async {
		do {
			let url = URL(string: "https://hws.dev/\(selectedBox.lowercased()).json")!
			let (data, _) = try await URLSession.shared.data(from: url)
			messages = try JSONDecoder().decode([Message9].self, from: data)
		} catch {
			messages = [
				Message9(id: 0, user: "Failed to load message box.", text: "Please try again later.")
			]
		}
	}
}

struct TaskModifier_Previews: PreviewProvider {
    static var previews: some View {
        TaskModifier()
    }
}
