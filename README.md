# PSHR_iOS

This repository was made to create a seperate and stable version of the previously used https://github.com/Lawreros/PSHR_v2 

This app is made to interface with the H10 Polar Strap using the `PolarBleSdk` library found on one of [Polar Strap's Official Github Repos](https://github.com/polarofficial/polar-ble-sdk).
As code and overall structure of the app is taken from `PolarBleSdk`, as per their request, the liscensing is propogated and can be found [here](https://github.com/Lawreros/PSHR_iOS/blob/main/ThirdPartySoftwareListing.txt)

### H10 Heart rate sensor
Most accurate Heart rate sensor in the markets. The H10 is used in the Getting started section of this page. 
[Store page](https://www.polar.com/en/products/accessories/H10_heart_rate_sensor)

### H10 heart rate sensor available data types
* From version 3.0.35 onwards. 
* Heart rate as beats per minute. RR Interval in ms and 1/1024 format.
* Heart rate broadcast.
* Electrocardiography (ECG) data in µV with sample rate 130Hz. Default epoch for timestamp is 1.1.2000
* Accelerometer data with sample rates of 25Hz, 50Hz, 100Hz and 200Hz and range of 2G, 4G and 8G. Axis specific acceleration data in mG. Default epoch for timestamp is 1.1.2000
* Start and stop of internal recording and request for internal recording status. Recording supports RR, HR with one second sampletime or HR with five second sampletime.
* List, read and remove for stored internal recording (sensor supports only one recording at the time).

### App Functionality:
* Connects to nearest H10 heart rate sensor
* Records transmitted RR-interval and BPM measurements into a local text file, including timestamps for when the iPhone recieved the packets of data
* Records transmitted ECG data into a local text file, also including timestamps
* Plays a sound recording and vibrates whenever there has been an unexpected disconnect or ECG data is not being recorded

### Requirements
* Xcode 12.x
* Swift 5.x

## Dependencies
*  [PolarBleSdk 3.3.6](https://github.com/polarofficial/polar-ble-sdk) or above
*  [RxSwift 6.0](https://github.com/ReactiveX/RxSwift) or above
*  [Swift Protobuf 1.18.0](https://github.com/apple/swift-protobuf) or above


## File Summary:
Below is a diagram of the folders and files found in the source code for the `PSHR_iOS` app, along with brief descriptions of what is found in them. The two most important files for chaning aspects of the app are `ContentView.swift` and `PolarBleSdkManager`. ContentView defines the structure of the view that the user sees when using the app. This is where everything related to what the user actually sees when using the app is defined. `PolarBleSdkManager` is where the BLE connection and data recording is defined/handled. The class definde in this file is effectively the engine of the entire app and sends information to update `ContentView`.

```
PSHR_iOS.xcodeproj
README.md

PSHR_iOS/
    Sounds/
        IOS_Alarm_bell.mp3 : Alarm sound used by app
    
    PSHR-iOS-info.plist : app resource permissions file
    PSHR_iOSApp.swift : The app file itself (calls ContentView.swift)
    
    Views/
        Styles/
            ButtonStyle.swift
        ContentView.swift : Defines what the user sees when using the app
        StreamSettingsView.swift
        Assets.xcassets : File containing the images used for the app logo
    
    Preview Content/
        Preview Assets
    
    PolarBleSdkManager.swift : This file is where 90% of the apps functionality is defined. It defines and handles the BLE connection and calculating/organizing/recording of data from the polar strap. This updates ContentView.swift witht he new information to display to the user

PSHR_iOSTests/
    PSHR_iOSTests.swift

PSHR_iOSUITests/
    PSHR_iOSUITests.swift
    PSHR_iOSUITestsLaunchTests.swift
```
