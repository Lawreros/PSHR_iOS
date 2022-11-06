//
//  ContentView.swift
//  PSHR_iOS
//
//  Created by Ross on 11/5/22.
//

import SwiftUI
import PolarBleSdk

extension Text {
    func headerStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.secondary)
            .fontWeight(.light)
    }
}

struct ContentView: View {
    @ObservedObject var bleSdkManager: PolarBleSdkManager
    
    // What is actually displayed by the app
    var body: some View {
        VStack {
            // Title at the top of the app
            Text("PSHR BLE App")
                .bold
            
            ScrollView(.vertical){
                VStack(spacing: 10) {
                    if !bleSdkManager.isBluetoothOn {
                        Text("Bluetooth OFF")
                            .bold()
                            .foregroundColor(.red)
                    }
                    Group {
                        Text("Connectivity:")
                            .headerStyle()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Check what the connection status is and change the appearance of the button accordingly
                        switch bleSdkManager.deviceConnectionState {
                        case .disconnected:
                            Button("Connection Status", action: {bleSdkManager.connectToDevice()})
                                .buttonStyle(PrimaryButtonStyle(buttonState: getConnectButtonState()))
                        case .connecting(let deviceId):
                            Button("Connecting \(deviceId)", action: {})
                                .buttonStyle(PrimaryButtonStyle(buttonState: getConnectButtonState()))
                                .disabled(true)
                        case .connected(let deviceId):
                            Button("Disconnect \(deviceId)", action: {bleSdkManager.disconnectFromDevice()})
                                .buttonStyle(PrimaryButtonStyle(buttonState: getConnectButtonState()))
                        }
                        Button("Auto Connect", action: { bleSdkManager.autoConnect()})
                            .buttonStyle(PrimaryButtonStyle(buttonState: getAutoConnectButtonState()))
                        
                    }.disabled(!bleSdkManager.isBluetoothOn)
                    
                    Divider() // Put seperation between buttons and streams
                    
                    Group {// Streaming Group
                        Group {
                            Text("Streams:")
                                .headerStyle()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button( bleSdkManager.isStreamOn(feature: DeviceStreamingFeature.ecg) ? "Stop ECG Stream" : "Start ECG Stream", action: {
                                streamButtonToggle(DeviceStreamingFeature.ecg) })
                                .buttonStyle(SecondaryButtonStyle(buttonState: getStreamButtonState(DeviceStreamingFeature.ecg)))
                            
                        }.fullScreenCover(item: $bleSdkManager.streamSettings) { streamSettings in
                            if let settings = streamSettings {
                                StreamSettingsView(bleSdkManager: bleSdkManager, streamedFeature: settings.feature, streamSettings: settings)
                            }
                        }
                        Divider()
                        // Display area for the recieved data packets
                        Group{
                            Text("Recieved Data Packet")
                                .headerStyle()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("HR: \(bleSdkManager.hr_message)")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.system(size: 30))
                                .padding()
                                .foregroundColor(.none)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            
                            Text("ECG: \(bleSdkManager.ecg_message)")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.system(size: 30))
                                .padding()
                                .foregroundColor(.none)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            Text("Battery: \(bleSdkManager.battery_level)%")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.system(size: 15))
                                .padding()
                                .foregroundColor(.none)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.black, lineWidth:2)
                                )
                        }
                    }.disabled(!bleSdkManager.isDeviceConnected)//Streaming Group
                }.frame(maxWidth: .infinity)//VStack
            }//ScrollView
        //VStack
        }.alert(item: $bleSdkManager.generalError) {message in
            Alert(title: Text(message.text),
                  dismissButton: .cancel()
            )
        }.alert(item: $bleSdkManager.generalMessage){ message in
            Alert(title: Text(message.text),
                  dismissButton: .cancel()
            )//TODO: Check if this double alert is necessary
        }
    }//View
    
    // function of changing the connect button
    func getConnectButtonState() -> ButtonState {
        if bleSdkManager.isBluetoothOn {
            switch bleSdkManager.deviceConnectionState {
            case .disconnected:
                return ButtonState.released
            case .connecting(_):
                return ButtonState.disabled
            case .connected(_):
                return ButtonState.pressedDown
            }
        }
        
    }
    
    // function for changing the autoconnect button
    func getAutoConnectButtonState() -> ButtonState {
        if bleSdkManager.isBluetoothOn && !bleSdkManager.isDeviceConnected {
            return ButtonState.released
        } else {
            return ButtonState.disabled
        }
    }
    
}//struct

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 8", "iPAD Pro (12.9-inch)"], id: \.self) { deviceName in
            ContentView(bleSdkManager: PolarBleSdkManager())
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
        
    }
}
