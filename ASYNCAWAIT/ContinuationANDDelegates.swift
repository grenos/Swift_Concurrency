//
//  ContinuationANDDelegates.swift
//  ASYNCAWAIT
//
//  Created by Vasileios  Gkreen on 10/11/21.
//

import SwiftUI
import CoreLocation
import CoreLocationUI


/*
 
 Sometimes we get diferent delegate callbacks from older apis. In this case a succes result and an error result come from diferent
 functrions. So to be able to use the continuation struct we basically need to save it as a property to have it available everywhere in our object
 */

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
	
	var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Error>?
	let manager = CLLocationManager()
	
	override init() {
		super.init()
		manager.delegate = self
	}
	
	
	
	func requestLocation() async throws -> CLLocationCoordinate2D? {
		try await withCheckedThrowingContinuation { continuation in
			locationContinuation = continuation // save the continuation here on a class proprty
			manager.requestLocation()
		}
	}
	
	
	/*
	 Here depending on the result we get we use the continuation saved as a class property
	 */
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		locationContinuation?.resume(returning: locations.first?.coordinate)
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		locationContinuation?.resume(throwing: error)
	}
}




struct ContentView1: View {
	@StateObject private var locationManager = LocationManager()
	
	var body: some View {
		LocationButton {
			Task {
				if let location = try? await locationManager.requestLocation() {
					print("Location: \(location)")
				} else {
					print("Location unknown.")
				}
			}
		}
		.frame(height: 44)
		.foregroundColor(.white)
		.clipShape(Capsule())
		.padding()
	}
}
