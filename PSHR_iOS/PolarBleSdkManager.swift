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

struct StreamSettings: Identifiable, Hashable {
    let id = UUID()
    let feature: DeviceStreamingFeature
    var settings: [StreamSetting] = []
    var sortedSettings: [StreamSetting] { return settings.sorted{ $0.type.rawValue < $1.type.rawValue }}
}

struct StreamSetting: Identifiable, Hashable {
    let id = UUID()
    let type: PolarSensorSetting.SettingType
    var values: [Int] = []
    var sortedValues: [Int] { return values.sorted(by:<)}
}

struct Message: Identifiable {
    let id = UUID()
    let text: String
}


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
    @Published private(set) var isH10RecordingSupported: Bool = false
    @Published private(set) var isH10RecordingEnabled: Bool = false
    @Published private(set) var supportedStreamFeatures: Set<DeviceStreamingFeature> = Set<DeviceStreamingFeature>()
    @Published var streamSettings: StreamSettings? = nil
    @Published var generalError: Message? = nil
    @Published var generalMessage: Message? = nil
    
    private var ecgDisposable: Disposable? //question mark means variable can be nil or not
    private var disposeBag = DisposeBag()
    private var audioPlayer : AVAudioPlayer? = nil
    
    init() {
        //check on initalization that Bluetooth is on
        self.isBluetoothOn = api.isBlePowered
        
        api.polarFilter(true)
        api.observer = self
//        api.deviceFeaturesObserver = self
        api.powerStateObserver = self
        api.deviceInfoObserver = self
//        api.sdkModeFeatureObserver = self
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
    // Get the supported settings/streaming information for the connected device
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
                        self.somethingFailed(text: "Stream settins request failed: \(err)")
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
            ecgStreamStart(settings: PolarSensorSetting(polarSensorSettings))
        //Other supported streams that we don't use (see TODO: put link here):
        case .acc:
            break
//            accStreamStart(settings: PolarSensorSetting(polarSensorSettings))
        case .magnetometer:
            break
//            magStreamStart(settings: PolarSensorSetting(polarSensorSettings))
        case .ppg:
            break
//            ppgStreamStart(settings: PolarSensorSetting(polarSensorSettings))
        case .ppi:
            break
//            ppiStreamStart()
        case .gyro:
            break
//            gyrStreamStart(settings: PolarSensorSetting(polarSensorSettings))
        }
        
    }
    
    func streamStop(feature: PolarBleSdk.DeviceStreamingFeature) {
        switch feature {
        case .ecg:
            ecgStreamStop()
        //Other supported streams (see streamStart)
        case .acc:
            break
            //accStreamStop()
        case .magnetometer:
            break
            //magStreamStop()
        case .ppg:
            break
            //ppgStreamStop()
        case .ppi:
            break
            //ppiStreamStop()
        case .gyro:
            break
            //gyrStreamStop()
        }
    }
    
    
    func isStreamOn(feature: PolarBleSdk.DeviceStreamingFeature) -> Bool {
        switch feature {
        case .ecg:
             return isEcgStreamOn
        case .acc:
            return false
            //return isAccStreamOn
        case .magnetometer:
            return false
            //return isMagStreamOn
        case .ppg:
            return false
            //return isPpgSreamOn
        case .ppi:
            return false
            //return isPpiStreamOn
        case .gyro:
            return false
            //return isGyrStreamOn
        }
    }
    
    // Function which keep track of whether to app is connecteed to an H10 device
    func getH10RecordingStatus() {
        if case .connected(let deviceId) = deviceConnectionState {
            api.requestRecordingStatus(deviceId)
                .observe(on: MainScheduler.instance)
                .subscribe{ e in
                    switch e {
                    case .failure(let err):
                        self.somethingFailed(text: "recording status request failed: \(err)")
                    case .success(let pair):
                        var recordingStatus = "Recording on: \(pair.ongoing)."
                        if pair.ongoing {
                            recordingStatus.append(" Recording started with id: \(pair.entryId)")
                            self.isH10RecordingEnabled = true
                        } else {
                            self.isH10RecordingEnabled = false
                        }
                        self.generalMessage = Message(text: recordingStatus)
                        NSLog(recordingStatus)
                    }
                }.disposed(by: disposeBag)
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
                        let ecg_string = stringArray.joined(separator: "\t")
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
        case connecting(String)
        case connected(String)
    }
}

// Adds the message function (just puts things into a NSLog)
extension PolarBleSdkManager : PolarBleApiLogger {
    func message(_ str: String) {
        NSLog("Polar SDK log:  \(str)")
    }
}

// MARK: - PolarBleApiPowerStateObserver
// Extend the PolarBleSdkManager with a protocol for the power state and functions which log
// when the power is on or off
//TODO: See if this extension is even necessary
extension PolarBleSdkManager : PolarBleApiPowerStateObserver {
    func blePowerOn() {
        NSLog("BLE ON")
        isBluetoothOn = true
    }
    
    func blePowerOff() {
        NSLog("BLE OFF")
        isBluetoothOn = false
    }
}

// MARK: - PolarBleApiSdkModeFeatureObserver
// Check if certain data types are available for transmission from the connected
// polar strap device (in this case HR and "streaming" (i.e. ecg and others))
extension PolarBleSdkManager : PolarBleApiDeviceFeaturesObserver {
    func hrFeatureReady(_ identifier: String) {
        NSLog("HR ready")
    }
    
    //NOT USED but necessary for PolarBleApiDeviceFeaturesObserver protocol
    func ftpFeatureReady(_ identifier: String) {
        //NSLog("FTP ready")
        //isFtpFeatureSupported = true
    }
    
    func streamingFeaturesReady(_ identifier: String, streamingFeatures: Set<DeviceStreamingFeature>) {
        supportedStreamFeatures = streamingFeatures
        for feature in streamingFeatures {
            NSLog("Feature \(feature) is ready.")
        }
    }
}



// MARK: - PolarBleApiDeviceInfoObserver
// Extend PolarBleSdkManager with protocol for recieving/processing/tracking the battery level
// for the connected polar device
extension PolarBleSdkManager : PolarBleApiDeviceInfoObserver {
    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        NSLog("battery level updated: \(batteryLevel)")
        battery_level = "\(batteryLevel)"
    }
    
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
        NSLog("dis info: \(uuid.uuidString) value: \(value)")
    }
}


// MARK: - PolarBleApiObserver
// Extend the PolarBleSdkManager with a protocol for the tracking of the connection status
// for the BLE device
extension PolarBleSdkManager : PolarBleApiObserver {
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        NSLog("DEVICE CONNECTING: \(polarDeviceInfo)")
        deviceConnectionState = ConnectionState.connecting(polarDeviceInfo.deviceId)
    }
    
    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        NSLog("DEVICE CONNECTED: \(polarDeviceInfo)")
        if(polarDeviceInfo.name.contains("H10")){//Check if connected device is H10
            self.isH10RecordingSupported = true
            getH10RecordingStatus()
        }
        deviceConnectionState = ConnectionState.connected(polarDeviceInfo.deviceId)
    }
    
    //Warning function to be called
    func vibrate() {
        for _ in 0...10 {
            DispatchQueue.main.async(execute: {sleep(1); AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)})
        }
    }
    
    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo) {
        NSLog("DISCONNECTED: \(polarDeviceInfo)")
        deviceConnectionState = ConnectionState.disconnected
//        self.isSdkStreamModeEnabled = false
//        self.isSdkFeatureSupported = false
//        self.isFtpFeatureSupported = false
        self.isH10RecordingSupported = false
        self.supportedStreamFeatures = Set<DeviceStreamingFeature>()
        
        let alarmURL = Bundle.main.url(forResource: "IOS_Alarm_bell",
                                         withExtension: "mp3")!
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: alarmURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            vibrate()
        } catch let err {
            NSLog("Failed to find sound file. Reason \(err)")
        }
    }
}

// MARK: - PolarBleApiDeviceHrObserver
extension PolarBleSdkManager : PolarBleApiDeviceHrObserver {
    func hrValueReceived(_ identifier: String, data: PolarHrData) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSSS"
        
//        NSLog("(\(identifier)) HR value: \(data.hr) rrsMs: \(data.rrsMs) rrs: \(data.rrs) contact: \(data.contact) contact supported: \(data.contactSupported)")
        
        let timestamp = formatter.string(from: Date())
        let RR_count = data.rrsMs.count
        var RRs: String = "ERROR"
        
        if RR_count == 0 {
            RRs = "0\t0\t0"
        } else if RR_count == 1 {
            RRs = "\(data.rrsMs[0])\t0\t0"
        } else if RR_count == 2 {
            RRs = "\(data.rrsMs[0])\t\(data.rrsMs[1])\t0"
        } else if RR_count == 3 {
            RRs = "\(data.rrsMs[0])\t\(data.rrsMs[1])\t\(data.rrsMs[2])"
        }
        
        Logger.log("\(data.hr)\t\(RRs)", timestamp, "HR", identifier) //for some reason, here it pulls the initial deviceId, instad of the real one, unlike with the logging of ECG data
        hr_message = "\(timestamp)\n\(data.rrsMs)"
        
    }
}



// MARK: - PSHR Logger

class Logger {
    // Create the filename and path for the text file that you wish to append the data to
    static func gen_test_file(_ dattype:String, _ deviceID:String)->String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        let dateString = formatter.string(from: Date())
        let fileName = "\(dattype)_\(dateString)_\(deviceID).txt"
        return fileName
    }

    
    // Actuallly append the data to the text file
    static func log(_ message: String, _ timestamp: String, _ source: String, _ deviceID: String) {
        
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        // Add the device ID to the name of the file
        guard let textFile_ecg = documentDirectory?.appendingPathComponent(gen_test_file(source, deviceID)) else {
            return
        }
        guard let textFile_hr = documentDirectory?.appendingPathComponent(gen_test_file(source, deviceID)) else {
            return
        }
        
        guard let data = (timestamp + "\t" + message + "\n").data(using: String.Encoding.utf8) else { return }

        // What to write into ECG text file
        if source == "ECG" {
        
            if FileManager.default.fileExists(atPath: textFile_ecg.path) {
                if let fileHandle = try? FileHandle(forWritingTo: textFile_ecg) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: textFile_ecg, options: .atomicWrite)
            }
        }
        
        // What to write into HR text file
        if source == "HR" {
            if FileManager.default.fileExists(atPath: textFile_hr.path) {
                if let fileHandle = try? FileHandle(forWritingTo: textFile_hr) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: textFile_hr, options: .atomicWrite)
            }
        }
    }
}
