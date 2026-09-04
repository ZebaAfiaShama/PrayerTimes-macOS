import Foundation
import CoreLocation
import Combine

public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let defaults = UserDefaults.standard

    @Published public var latitude: Double
    @Published public var longitude: Double
    @Published public var cityName: String
    @Published public var countryName: String
    @Published public var isAutoLocationEnabled: Bool {
        didSet {
            defaults.set(isAutoLocationEnabled, forKey: "isAutoLocationEnabled")
            if isAutoLocationEnabled {
                requestLocation()
            }
        }
    }
    @Published public var authorizationStatus: CLAuthorizationStatus

    private override init() {
        let cachedLat = defaults.double(forKey: "lastLatitude")
        let cachedLon = defaults.double(forKey: "lastLongitude")
        let cachedCity = defaults.string(forKey: "lastCityName")
        let cachedCountry = defaults.string(forKey: "lastCountryName")

        self.latitude = (cachedLat != 0.0) ? cachedLat : 23.8103
        self.longitude = (cachedLon != 0.0) ? cachedLon : 90.4125
        self.cityName = cachedCity ?? "Dhaka"
        self.countryName = cachedCountry ?? "Bangladesh"
        self.isAutoLocationEnabled = defaults.object(forKey: "isAutoLocationEnabled") as? Bool ?? true
        self.authorizationStatus = manager.authorizationStatus

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func requestAuthorizationAndLocation() {
        if !isAutoLocationEnabled { return }
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            requestLocation()
        case .denied, .restricted:
            print("Location access denied. Using fallback: \(cityName)")
        @unknown default:
            break
        }
    }

    public func requestLocation() {
        guard isAutoLocationEnabled else { return }
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways {
                self.requestLocation()
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        DispatchQueue.main.async {
            self.latitude = lat
            self.longitude = lon
            self.defaults.set(lat, forKey: "lastLatitude")
            self.defaults.set(lon, forKey: "lastLongitude")
        }

        // Reverse geocode to get City and Country name
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let placemark = placemarks?.first {
                let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Current Location"
                let country = placemark.country ?? ""

                DispatchQueue.main.async {
                    self.cityName = city
                    self.countryName = country
                    self.defaults.set(city, forKey: "lastCityName")
                    self.defaults.set(country, forKey: "lastCountryName")

                    PrayerStore.shared.onLocationUpdated(
                        latitude: lat,
                        longitude: lon,
                        cityName: city,
                        countryName: country
                    )
                }
            } else {
                DispatchQueue.main.async {
                    PrayerStore.shared.onLocationUpdated(
                        latitude: lat,
                        longitude: lon,
                        cityName: self.cityName,
                        countryName: self.countryName
                    )
                }
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CoreLocation notice: \(error.localizedDescription). Using cached/default location.")
    }

    public func setManualDhaka() {
        self.isAutoLocationEnabled = false
        self.latitude = 23.8103
        self.longitude = 90.4125
        self.cityName = "Dhaka"
        self.countryName = "Bangladesh"
        self.defaults.set(23.8103, forKey: "lastLatitude")
        self.defaults.set(90.4125, forKey: "lastLongitude")
        self.defaults.set("Dhaka", forKey: "lastCityName")
        self.defaults.set("Bangladesh", forKey: "lastCountryName")

        PrayerStore.shared.onLocationUpdated(
            latitude: 23.8103,
            longitude: 90.4125,
            cityName: "Dhaka",
            countryName: "Bangladesh"
        )
    }
}
