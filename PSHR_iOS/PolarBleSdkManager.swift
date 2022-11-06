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
    private var deviceId = "00000000"
    
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
    @Published private var isEcgStreamOn: Bool = false
    @Published var streamSettings: StreamSettings? = nil
    
    private var ecgDisposable: Disposable? //question mark means variable can be nil or not
    private var disposeBag = DisposeBag()
    
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
    
    //TODO: Check that this and streamStart are necessary
    // Get teh supported settings/streaming information for the connected device
    func getStreamSettings(feature: PolarBleSdk.DeviceStreamingFeature) {
        if case .connected(let deviceId) = deviceConnectionState {
            NSLog("Stream settings fetch for \(feature)")
            api.requestStreamSettings(deviceId, feature: feature)
                .observe(on: MainScheduler.instance)
                .subscribe{e in
                    switch e {
                    case .success(let settings):
                        NSLog("Stream settings fetch completed for \(feature)")
                        
                        var receivedSettings:[StreamSetting] = []
                        for setting in settings.settings {
                            var values:[Int] = []
                            for settingsValue in setting.value {
                                values.append(Int(settingsValue))
                            }
                            NSLog("TESTING, received setting key \(setting.key) andvalues \(values)")
                            receivedSettings.append(StreamSetting(type: setting.key, values: values))
                        }
                        
                        self.streamSettings = StreamSettings(feature: feature, settings: receivedSettings)
                        
                    case .failure(let err):
                        self.sometingFailed(text: "Stream settins request failed: \(err)")
                        self.streamSettings = nil
                    }
                }.disposed(by: disposeBag) //in charge of killing stream safely
        } else {
            NSLog("Device is not connected \(deviceConnectionState)")
        }
    }
    
    func streamStart(settings: StreamSettings) {
        var logString:String = "Stream \(settings.feature) start with settings: "
        
        var polarSensorSettings:[PolarSensorSetting.SettingType : UInt32] = [:]
        for setting in settings.settings {
            polarSensorSettings[setting.type] = UInt32(setting.values[0])
            logString.append("\(setting.type) \(setting.values[0])")
        }
        NSLog(logString)
        
        switch settings.feature {
        case .ecg:
            ecgStartStream(settings: PolarSensorSetting(polarSensorSettings))
        //Other supported streams that we don't use (see TODO: put link here):
//        case .acc:
//            accStreamStart(settings: PolarSensorSetting(polarSensorSettings))
//        case .magnetometer:
//            magStreamStart(settings: PolarSensorSetting(polarSensorSettings))
//        case .ppg:
//            ppgStreamStart(settings: PolarSensorSetting(polarSensorSettings))
//        case .ppi:
//            ppiStreamStart()
//        case .gyro:
//            gyrStreamStart(settings: PolarSensorSetting(polarSensorSettings))
        }
        
    }
    
    func streamStop(feature: PolarBleSdk.DeviceStreamingFeature) {
        switch feature {
        case .ecg:
            ecgStreamStop()
        //Other supported streams (see streamStart)
//        case .acc:
//            accStreamStop()
//        case .magnetometer:
//            magStreamStop()
//        case .ppg:
//            ppgStreamStop()
//        case .ppi:
//            ppiStreamStop()
//        case .gyro:
//            gyrStreamStop()
        }
    }
    
    
    //function which starts ECG data collection
    func ecgStreamStart(settings: PolarBleSdk.PolarSensorSetting) {
        if case .connected(let deviceId) = deviceConnectionState {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSSS"
            
            isEcgStreamOn = true
            ecgDisposable = api.startEcgStreaming(deviceId, settings: settings)
                .observe(on: MainScheduler.instance)
                .subscribe{ e in //what to do when something is sent through the ecg stream
                    switch e {
                    case .next(let data): //if the next bit of data has been sent
                        let timestamp = formatter.string(from: Date())
                        let stringArray = data.samples.map { String($0) }
                        let ecg_string = stringArray.joined(seperator: "\t")
                        Logger.log("\(data.timeStamp)\t\(ecg_string)", timestamp, "ECG", deviceId)
                        self.ecg_message = "\(timestamp)\n\(data.samples[0])\t\(data.samples[1])"
                    
                    case .error(let err): //If an error has occured
                        NSLog("ECG stream failed: \(err)")
                        for _ in 1...2 {
                            AudioServicesPlayAlertSound(SystemSoundID(1005))
                            sleep(1)
                        }
                        self.isEcgStreamOn = false //TODO: Is this the cause of ECG dropping out?
                    case .completed: //If there is MainScheduler is done(?)
                        NSLog("ECG stream completed")
                        self.isEcgStreamOn = false
                    }
                }
        } else {
            NSLog("Device is not connected \(deviceConnectionState)")
        }
    }
    
    func ecgStreamStop() {
        isEcgStreamOn = false
        ecgDisposable?.dispose()
    }
    
    private func somethingFailed(text: String) {
        generalError = Message(text:text)
        NSLog("Error \(text)")
    }
    
}





// MARK: - PolarBleApiLogger
extension PolarBleSdkManager {
    enum ConnectionState {//"Define an enumeration type ConnectionState which
                        // can take either a value of disconnected with nothing
                        // or a value of connection/connected with a value of String
        case disconnected
        case connection(String)
        case connected(String)
    }
}

// MARK: - PSHR Logger

