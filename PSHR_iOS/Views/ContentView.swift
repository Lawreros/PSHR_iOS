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
                    }
                }
            }//ScrollView
        }//VStack
    }//View
    
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
