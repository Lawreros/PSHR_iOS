//
//  PolarBleSdkManager.swift
//  PSHR_iOS
//
//  Created by Ross on 11/5/22.
//

import Foundation
import PolarBleSdk
import RxSwift
import CoreBluetooth
import AudioToolbox
import AVFoundation


class PolarBleSdkManager : ObservableObject {
    
    private var api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: Features.allFeatures.rawValue)
    
    // Create placeholder deviceID which will be changed when a real
    // polar strap device is connected
    private var deviceID = "00000000"
    
    // Strings which will publish updates on the hr/ecg/battery info
    // These are what ContentView references
    @Published public var hr_message = ""
    @Published public var ecg_message = ""
    @Published public var battery_level = ""
    
    // Variables which hold the status for BLE connection/searching
    @Published private(set) var isBluetoothOn: Bool
    @Published private(set) var isBroadcastListenOn: Bool = false
    @Published private(set) var isSearchOn: Bool = false
    
    
    private var autoConnectDisposable: Disposable?
    
    
    
    //Stores the state of the device being connected
    @Published private(set) var deviceConnectionState: ConnectionState =
        ConnectionState.disconnected {
        didSet {//didset executes whenever the value is set
            switch deviceConnectionState {
            case .disconnected:
                isDeviceConnected = false
            case .connecting(_):
                isDeviceConnected = false
            case .connected(_):
                isDeviceConnected = true
            }
        }
    }
    
    @Published private(set) var isDeviceConnected: Bool = false
    
    
    init() {
        //check on initalization that Bluetooth is on
        self.isBluetoothOn = api.isBlePowered
        
        api.polarFilter(true)
        api.observer = self
        api.deviceFeaturesObserver = self
        api.powerStateObserver = self
        api.deviceInfoObserver = self
        api.sdkModeFeatureObserver = self
        api.deviceHrObserver = self
        api.logger = self
    }
    
    // func broadcastToggle: searches for ble devices which are broadcasting
    // func searchToggle: searches for polar devices
    
    
    func connectToDevice() {
        do {
            try api.connectToDevice(deviceId)
        } catch let err {
            NSLog("Failed to connect to \(deviceId). Reason \(err)")
        }
    }
    
    func disconnectFromDevice() {
        if case .connected(let deviceId) = deviceConnectionState {
            do {
                try api.disconnectFromDevice(deviceId)
            } catch let err {
                NSLog("Failed to disconnect from \(deviceId). Reason \(err)")
            }
        }
    }
    
    //function to autoconnect to supported polar strap device
    func autoConnect() {
        autoConnectDisposable?.dispose()
        autoConnectDisposable = api.startAutoConnectToDevice(-55,service:nil,
                    polarDeviceType: nil)
            .subscribe{ e in
                       switch e {
                        case .completed:
                            NSLog("auto connect search complete")
                        case .error(let err):
                            NSLog("auto connect failed: \(err)")
                        }
            }
    }
    
    
}

extension PolarBleSdkManager {
    enum ConnectionState {//"Define an enumeration type ConnectionState which
                        // can take either a value of disconnected with nothing
                        // or a value of connection/connected with a value of String
        case disconnected
        case connection(String)
        case connected(String)
    }
}
