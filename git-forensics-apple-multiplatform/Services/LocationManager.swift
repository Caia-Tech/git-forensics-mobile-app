//
//  LocationManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: String?
    @Published var isUpdatingLocation = false
    
    @AppStorage("locationEnabled") var locationEnabled = false
    @AppStorage("locationAccuracy") var locationAccuracy = "best"
    
    private let locationManager = CLLocationManager()
    private var locationCompletionHandler: ((Result<EventLocation, Error>) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = getDesiredAccuracy()
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Request location permission
    func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Get current location for an event
    func getCurrentLocation() async throws -> EventLocation {
        guard locationEnabled else {
            throw LocationError.disabled
        }
        
        let isAuthorized: Bool
        #if os(iOS)
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #else
        isAuthorized = authorizationStatus == .authorizedAlways
        #endif
        
        guard isAuthorized else {
            throw LocationError.notAuthorized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationCompletionHandler = { result in
                continuation.resume(with: result)
            }
            
            isUpdatingLocation = true
            locationError = nil
            
            // Set accuracy based on user preference
            locationManager.desiredAccuracy = getDesiredAccuracy()
            
            // Request one-time location
            locationManager.requestLocation()
            
            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if self.isUpdatingLocation {
                    self.isUpdatingLocation = false
                    self.locationCompletionHandler = nil
                    continuation.resume(throwing: LocationError.timeout)
                }
            }
        }
    }
    
    /// Start continuous location updates (for testing/debugging)
    func startLocationUpdates() {
        let isAuthorized: Bool
        #if os(iOS)
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #else
        isAuthorized = authorizationStatus == .authorizedAlways
        #endif
        
        guard locationEnabled && isAuthorized else {
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    /// Stop continuous location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Check if location services are available and enabled
    var isLocationAvailable: Bool {
        {
            #if os(iOS)
            return CLLocationManager.locationServicesEnabled() && 
                   (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
            #else
            return CLLocationManager.locationServicesEnabled() && 
                   authorizationStatus == .authorizedAlways
            #endif
        }()
    }
    
    /// Human-readable status description
    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Location permission not requested"
        case .denied:
            return "Location access denied"
        case .restricted:
            return "Location access restricted"
        case .authorizedWhenInUse:
            return "Location authorized when app is in use"
        case .authorizedAlways:
            return "Location always authorized"
        @unknown default:
            return "Unknown location status"
        }
    }
    
    /// Get desired accuracy based on user preference
    private func getDesiredAccuracy() -> CLLocationAccuracy {
        switch locationAccuracy {
        case "best":
            return kCLLocationAccuracyBest
        case "nearestTenMeters":
            return kCLLocationAccuracyNearestTenMeters
        case "hundredMeters":
            return kCLLocationAccuracyHundredMeters
        case "kilometer":
            return kCLLocationAccuracyKilometer
        default:
            return kCLLocationAccuracyBest
        }
    }
    
    /// Convert CLLocation to EventLocation
    private func convertToEventLocation(_ location: CLLocation) -> EventLocation {
        return EventLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMeters: location.horizontalAccuracy,
            altitudeMeters: location.altitude,
            altitudeAccuracyMeters: location.verticalAccuracy,
            headingDegrees: location.course >= 0 ? location.course : nil,
            speedMPS: location.speed >= 0 ? location.speed : nil,
            capturedAt: location.timestamp,
            source: .gps,
            address: nil // We'll add reverse geocoding later if needed
        )
    }
    
    /// Enable location services
    func enableLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Location services are disabled in Settings"
            return
        }
        
        switch authorizationStatus {
        case .notDetermined:
            requestLocationPermission()
        case .denied, .restricted:
            locationError = "Please enable location access in Settings"
        case .authorizedWhenInUse, .authorizedAlways:
            locationEnabled = true
            locationError = nil
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
    
    /// Disable location services
    func disableLocation() {
        locationEnabled = false
        stopLocationUpdates()
        currentLocation = nil
        locationError = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        isUpdatingLocation = false
        
        if let completion = locationCompletionHandler {
            locationCompletionHandler = nil
            let eventLocation = convertToEventLocation(location)
            completion(.success(eventLocation))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isUpdatingLocation = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access denied"
            case .locationUnknown:
                locationError = "Unable to find location"
            case .network:
                locationError = "Network error while getting location"
            default:
                locationError = "Location error: \(clError.localizedDescription)"
            }
        } else {
            locationError = "Location error: \(error.localizedDescription)"
        }
        
        if let completion = locationCompletionHandler {
            locationCompletionHandler = nil
            completion(.failure(error))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationError = nil
            if locationEnabled {
                // Location is now available
            }
        case .denied, .restricted:
            locationEnabled = false
            locationError = "Location access denied. Enable in Settings to add location to events."
        case .notDetermined:
            locationError = nil
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
    case disabled
    case notAuthorized
    case timeout
    case unavailable
    
    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Location services are disabled"
        case .notAuthorized:
            return "Location access not authorized"
        case .timeout:
            return "Location request timed out"
        case .unavailable:
            return "Location services unavailable"
        }
    }
}

// MARK: - Location Settings View

struct LocationSettingsView: View {
    @ObservedObject var locationManager = LocationManager.shared
    @Environment(\.dismiss) var dismiss
    
    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Location Services", isOn: Binding(
                        get: { locationManager.locationEnabled },
                        set: { newValue in
                            if newValue {
                                locationManager.enableLocation()
                            } else {
                                locationManager.disableLocation()
                            }
                        }
                    ))
                    
                    if locationManager.locationEnabled {
                        Picker("Accuracy", selection: $locationManager.locationAccuracy) {
                            Text("Best").tag("best")
                            Text("10 Meters").tag("nearestTenMeters")
                            Text("100 Meters").tag("hundredMeters")
                            Text("1 Kilometer").tag("kilometer")
                        }
                    }
                } header: {
                    Text("Location Services")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When enabled, location data can be optionally added to events. This helps provide context and verify where evidence was documented.")
                        
                        if let error = locationManager.locationError {
                            Text(error)
                                .foregroundColor(.red)
                        } else {
                            Text("Status: \(locationManager.statusDescription)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if locationManager.locationEnabled && locationManager.isLocationAvailable {
                    Section("Current Location") {
                        if let location = locationManager.currentLocation {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Latitude:")
                                    Spacer()
                                    Text("\(location.coordinate.latitude, specifier: "%.6f")")
                                        .fontDesign(.monospaced)
                                }
                                
                                HStack {
                                    Text("Longitude:")
                                    Spacer()
                                    Text("\(location.coordinate.longitude, specifier: "%.6f")")
                                        .fontDesign(.monospaced)
                                }
                                
                                HStack {
                                    Text("Accuracy:")
                                    Spacer()
                                    Text("±\(Int(location.horizontalAccuracy))m")
                                }
                                
                                HStack {
                                    Text("Updated:")
                                    Spacer()
                                    Text(location.timestamp, format: .dateTime.hour().minute().second())
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Button("Get Current Location") {
                                Task {
                                    try? await locationManager.getCurrentLocation()
                                }
                            }
                            .disabled(locationManager.isUpdatingLocation)
                        }
                    }
                }
                
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.green)
                            Text("Location data stays on your device")
                        }
                        
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                            Text("You choose when to add location to events")
                        }
                        
                        HStack {
                            Image(systemName: "eye.slash")
                                .foregroundColor(.purple)
                            Text("No location tracking or monitoring")
                        }
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Location Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LocationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LocationSettingsView()
    }
}