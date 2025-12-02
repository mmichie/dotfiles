package main

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation -framework CoreLocation -framework CoreWLAN
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreWLAN/CoreWLAN.h>

// Delegate to handle location authorization and updates
@interface LocationDelegate : NSObject <CLLocationManagerDelegate>
@property (atomic) BOOL authorized;
@property (atomic) BOOL done;
@property (atomic) BOOL locationReceived;
@property (atomic) double latitude;
@property (atomic) double longitude;
@property (atomic) double altitude;
@property (atomic) double horizontalAccuracy;
@property (atomic) double verticalAccuracy;
@end

@implementation LocationDelegate
- (id)init {
    self = [super init];
    if (self) {
        _authorized = NO;
        _done = NO;
        _locationReceived = NO;
        _latitude = 0.0;
        _longitude = 0.0;
        _altitude = 0.0;
        _horizontalAccuracy = 0.0;
        _verticalAccuracy = 0.0;
    }
    return self;
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = [manager authorizationStatus];
    if (status == kCLAuthorizationStatusAuthorized) {
        _authorized = YES;
    }
    _done = YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = [locations lastObject];
    if (location != nil) {
        _latitude = location.coordinate.latitude;
        _longitude = location.coordinate.longitude;
        _altitude = location.altitude;
        _horizontalAccuracy = location.horizontalAccuracy;
        _verticalAccuracy = location.verticalAccuracy;
        _locationReceived = YES;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // Location failed, but don't block - we'll return WiFi info without coordinates
    _locationReceived = NO;
}
@end

// C wrapper functions callable from Go
typedef struct {
    char ssid[256];
    char bssid[64];
    char iface[32];
    int success;
    int auth_status;
    int auth_was_requested;

    // CoreLocation data (WiFi-based positioning)
    int has_location;
    double latitude;
    double longitude;
    double altitude;
    double horizontal_accuracy;
    double vertical_accuracy;
} WifiInfo;

void getWifiInfo(WifiInfo *info, int fetch_location) {
    @autoreleasepool {
        // Initialize location fields
        info->has_location = 0;
        info->latitude = 0.0;
        info->longitude = 0.0;
        info->altitude = 0.0;
        info->horizontal_accuracy = 0.0;
        info->vertical_accuracy = 0.0;

        // On macOS, we need Location Services authorization to access WiFi SSID
        CLLocationManager *locationManager = [[CLLocationManager alloc] init];
        LocationDelegate *delegate = [[LocationDelegate alloc] init];
        locationManager.delegate = delegate;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;

        // Check current authorization status
        CLAuthorizationStatus status = [locationManager authorizationStatus];
        info->auth_status = status;
        info->auth_was_requested = 0;

        // If not determined, requesting location updates will trigger authorization
        if (status == kCLAuthorizationStatusNotDetermined) {
            info->auth_was_requested = 1;
            [locationManager startUpdatingLocation];

            // Wait for authorization (with timeout) - keep location updates running
            int timeout = 0;
            while (!delegate.done && timeout < 100) {  // 10 seconds timeout
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                timeout++;
            }

            // If we don't need coordinates, stop now
            if (!fetch_location) {
                [locationManager stopUpdatingLocation];
            }
        } else if (status == kCLAuthorizationStatusAuthorized) {
            delegate.authorized = YES;

            // Start location updates if we need coordinates
            if (fetch_location) {
                [locationManager startUpdatingLocation];
            }
        }

        // If we want location coordinates and are authorized, wait for them
        if (fetch_location && delegate.authorized) {
            int location_timeout = 0;
            while (!delegate.locationReceived && location_timeout < 300) {  // 30 seconds timeout
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                location_timeout++;
            }

            // Copy location data if received
            if (delegate.locationReceived) {
                info->has_location = 1;
                info->latitude = delegate.latitude;
                info->longitude = delegate.longitude;
                info->altitude = delegate.altitude;
                info->horizontal_accuracy = delegate.horizontalAccuracy;
                info->vertical_accuracy = delegate.verticalAccuracy;
            }

            [locationManager stopUpdatingLocation];
        }

        // Get WiFi interface
        CWWiFiClient *client = [CWWiFiClient sharedWiFiClient];
        CWInterface *wifiInterface = [client interface];

        if (wifiInterface != nil) {
            NSString *ssid = [wifiInterface ssid];
            NSString *bssid = [wifiInterface bssid];
            NSString *interfaceName = [wifiInterface interfaceName];

            if (ssid != nil) {
                strncpy(info->ssid, [ssid UTF8String], sizeof(info->ssid) - 1);
                info->ssid[sizeof(info->ssid) - 1] = '\0';
            }

            if (bssid != nil) {
                strncpy(info->bssid, [bssid UTF8String], sizeof(info->bssid) - 1);
                info->bssid[sizeof(info->bssid) - 1] = '\0';
            }

            if (interfaceName != nil) {
                strncpy(info->iface, [interfaceName UTF8String], sizeof(info->iface) - 1);
                info->iface[sizeof(info->iface) - 1] = '\0';
            }

            info->success = 1;
        } else {
            info->success = 0;
        }
    }
}
*/
import "C"
import (
	"flag"
	"fmt"
	"os"
)

func main() {
	// Parse command-line flags
	fetchLocation := flag.Bool("location", false, "Fetch CoreLocation coordinates (WiFi-based positioning, 1-15 seconds)")
	flag.Parse()

	// Call C function to get WiFi and optionally location info
	var info C.WifiInfo
	var fetchLoc C.int = 0
	if *fetchLocation {
		fetchLoc = 1
	}
	C.getWifiInfo(&info, fetchLoc)

	debug := os.Getenv("DEBUG") != ""
	var output string

	if debug {
		authStatusNames := map[int]string{
			0: "kCLAuthorizationStatusNotDetermined",
			1: "kCLAuthorizationStatusRestricted",
			2: "kCLAuthorizationStatusDenied",
			3: "kCLAuthorizationStatusAuthorizedAlways",  // iOS only
			4: "kCLAuthorizationStatusAuthorized",        // macOS
		}
		statusName := authStatusNames[int(info.auth_status)]
		if statusName == "" {
			statusName = fmt.Sprintf("Unknown(%d)", info.auth_status)
		}
		fmt.Fprintf(os.Stderr, "DEBUG: Authorization status: %s\n", statusName)
		fmt.Fprintf(os.Stderr, "DEBUG: Authorization requested: %v\n", info.auth_was_requested == 1)
		fmt.Fprintf(os.Stderr, "DEBUG: WiFi query success: %v\n", info.success == 1)
		fmt.Fprintf(os.Stderr, "DEBUG: Location received: %v\n", info.has_location == 1)
		if info.has_location == 1 {
			fmt.Fprintf(os.Stderr, "DEBUG: Coordinates: %.6f, %.6f (±%.1fm)\n",
				info.latitude, info.longitude, info.horizontal_accuracy)
		}
	}

	if info.success == 1 {
		ssid := C.GoString(&info.ssid[0])
		bssid := C.GoString(&info.bssid[0])
		iface := C.GoString(&info.iface[0])

		// Base output: ssid|bssid|interface
		output = fmt.Sprintf("%s|%s|%s", ssid, bssid, iface)

		// Add location data if available
		if info.has_location == 1 {
			output += fmt.Sprintf("|%.6f|%.6f|%.1f|%.1f",
				info.latitude, info.longitude,
				info.altitude, info.horizontal_accuracy)
		}
		output += "\n"
	} else {
		// No WiFi or not connected
		output = "||\n"
	}

	// Always write to stdout
	fmt.Print(output)

	// If OUTPUT_FILE env var is set, also write to file for app bundle mode
	if outputFile := os.Getenv("OUTPUT_FILE"); outputFile != "" {
		os.WriteFile(outputFile, []byte(output), 0644)
	}
}
