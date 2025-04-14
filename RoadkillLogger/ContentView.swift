//
//  ContentView.swift
//  RoadkillLogger
//
//  Created by ChatGPT for Road Ecology Researcher
//

import SwiftUI
import CoreLocation
import Speech
import MapKit

struct Observation: Identifiable {
    let id = UUID()
    let date: Date
    let latitude: Double
    let longitude: Double
    let species: String
}

struct ContentView: View {
    @State private var observations: [Observation] = []
    @State private var recognizedText: String = ""
    @State private var locationManager = CLLocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.0, longitude: -76.0),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var body: some View {
        VStack {
            // Button to simulate logging a roadkill
            Button(action: logObservation) {
                Text("Log Roadkill (Simulated)")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()

            // List of recorded observations
            List(observations) { obs in
                VStack(alignment: .leading) {
                    Text("Species: \(obs.species)")
                    Text("Lat: \(obs.latitude), Lon: \(obs.longitude)")
                    Text("Time: \(obs.date.formatted())")
                }
            }

            // Map displaying pins of observations
            Map(coordinateRegion: $region, annotationItems: observations) { obs in
                MapPin(coordinate: CLLocationCoordinate2D(latitude: obs.latitude, longitude: obs.longitude))
            }
            .frame(height: 250)
        }
        .onAppear {
            // Ask for location permission when app loads
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func logObservation() {
        // Simulate voice recognition result
        let simulatedSpecies = "Porcupine"
        // Get current location
        if let location = locationManager.location {
            let newObservation = Observation(
                date: Date(),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                species: simulatedSpecies
            )
            observations.append(newObservation)
        }
    }
}
