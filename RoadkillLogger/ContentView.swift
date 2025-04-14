//
//  ContentView.swift
//  RoadkillLogger
//

import SwiftUI
import CoreLocation
import Speech
import MapKit

class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var currentLocation: CLLocation?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        print("📡 Received location update: \(String(describing: currentLocation))")
    }
}

struct Observation: Identifiable {
    let id = UUID()
    let date: Date
    let latitude: Double
    let longitude: Double
    let species: String
}

struct ContentView: View {
    @State private var observations: [Observation] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.0, longitude: -76.0),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var isListening = false
    @State private var transcript: String = ""
    @StateObject private var locationDelegate = LocationManagerDelegate()
    

    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                logFallbackObservation()
            }) {
                Text("Log Roadkill (Fallback Only)")
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button(action: startListening) {
                Text(isListening ? "Listening..." : "Start Listening")
                    .padding()
                    .background(isListening ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            if !transcript.isEmpty {
                Text("Transcript: \(transcript)")
                    .font(.subheadline)
                    .padding(.horizontal)
            }

            List(observations) { obs in
                VStack(alignment: .leading) {
                    Text("Species: \(obs.species)")
                    Text("Lat: \(obs.latitude), Lon: \(obs.longitude)")
                    Text("Time: \(obs.date.formatted())")
                }
            }

            Map(coordinateRegion: $region, annotationItems: observations) { obs in
                MapPin(coordinate: CLLocationCoordinate2D(latitude: obs.latitude, longitude: obs.longitude))
            }
            .frame(height: 250)
        }
        .onAppear {
            SFSpeechRecognizer.requestAuthorization { authStatus in
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                default:
                    print("❌ Speech recognition not authorized")
                }
            }
        }
    }

    func logObservation(species: String) {
        if let location = locationDelegate.currentLocation {
            let newObservation = Observation(
                date: Date(),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                species: species
            )
            observations.append(newObservation)
            print("✅ Logged \(species) at lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")
        } else {
            logFallbackObservation(species: species)
        }
    }

    func logFallbackObservation(species: String = "Porcupine (Fallback)") {
        let fallbackObservation = Observation(
            date: Date(),
            latitude: 43.0481,
            longitude: -76.1474,
            species: species
        )
        observations.append(fallbackObservation)
        print("⚠️ Location unavailable — logged \(species) using fallback coordinates.")
    }

    func startListening() {
        transcript = ""
        isListening = true

        // Set up audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .allowBluetooth)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to set up audio session: \(error)")
        }

        // Cancel the previous recognition task if any exists
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create a new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode

        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Start a fresh recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        // Log species and GPS immediately after recognition completes
                        self.stopListening()
                        self.logObservation(species: self.transcript)
                    }
                }
            }

            if error != nil {
                DispatchQueue.main.async {
                    self.stopListening()
                    print("❌ Speech recognition error: \(String(describing: error))")
                }
            }
        }

        // Retrieve the actual input format of the microphone
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Remove any existing taps before adding a new one
        inputNode.removeTap(onBus: 0)

        // Install the tap using the microphone's actual input format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    func stopListening() {
        // Stop the audio engine
        audioEngine.stop()

        // Ensure the tap is removed before stopping the audio engine
        audioEngine.inputNode.removeTap(onBus: 0)

        // End the recognition request audio session
        recognitionRequest?.endAudio()
        
        // Deactivate the audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
        
        isListening = false
    }}
