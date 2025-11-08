package main

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation -framework CoreLocation -framework CoreWLAN
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreWLAN/CoreWLAN.h>

// Delegate to handle location authorization
@interface LocationDelegate : NSObject <CLLocationManagerDelegate>
@property (atomic) BOOL authorized;
@property (atomic) BOOL done;
@end

@implementation LocationDelegate
- (id)init {
    self = [super init];
    if (self) {
        _authorized = NO;
        _done = NO;
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
@end

// C wrapper functions callable from Go
typedef struct {
    char ssid[256];
    char bssid[64];
    char iface[32];
    int success;
    int auth_status;
    int auth_was_requested;
} WifiInfo;

void getWifiInfo(WifiInfo *info) {
    @autoreleasepool {
        // On macOS, we need Location Services authorization to access WiFi SSID
        CLLocationManager *locationManager = [[CLLocationManager alloc] init];
        LocationDelegate *delegate = [[LocationDelegate alloc] init];
        locationManager.delegate = delegate;

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

            [locationManager stopUpdatingLocation];
        } else if (status == kCLAuthorizationStatusAuthorized) {
            delegate.authorized = YES;
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
	"fmt"
	"os"
)

func main() {
	var info C.WifiInfo
	C.getWifiInfo(&info)

	debug := os.Getenv("DEBUG") != ""
	output := ""

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
	}

	if info.success == 1 {
		ssid := C.GoString(&info.ssid[0])
		bssid := C.GoString(&info.bssid[0])
		iface := C.GoString(&info.iface[0])

		// Output format: ssid|bssid|interface
		output = fmt.Sprintf("%s|%s|%s\n", ssid, bssid, iface)
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
