import CoreAudio
import Foundation

enum AudioOutputRouteInspector {
    static func currentDefaultOutputRoute() -> RealtimeTranslatedAudioOutputRoute? {
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != AudioDeviceID(kAudioObjectUnknown) else {
            return nil
        }

        let name = stringProperty(
            deviceID: deviceID,
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal
        ) ?? stringProperty(
            deviceID: deviceID,
            selector: kAudioDevicePropertyDeviceNameCFString,
            scope: kAudioObjectPropertyScopeGlobal
        ) ?? "Unknown output"

        let manufacturer = stringProperty(
            deviceID: deviceID,
            selector: kAudioDevicePropertyDeviceManufacturerCFString,
            scope: kAudioObjectPropertyScopeGlobal
        )
        let transportType = uint32Property(
            deviceID: deviceID,
            selector: kAudioDevicePropertyTransportType,
            scope: kAudioObjectPropertyScopeGlobal
        ).map(transportTypeDescription)
        let dataSource = uint32Property(
            deviceID: deviceID,
            selector: kAudioDevicePropertyDataSource,
            scope: kAudioDevicePropertyScopeOutput
        ).map(fourCCString)
        let uniqueID = stringProperty(
            deviceID: deviceID,
            selector: kAudioDevicePropertyDeviceUID,
            scope: kAudioObjectPropertyScopeGlobal
        )

        return RealtimeTranslatedAudioOutputRoute(
            name: name,
            manufacturer: manufacturer,
            transportType: transportType,
            dataSource: dataSource,
            uniqueID: uniqueID
        )
    }

    private static func stringProperty(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr else { return nil }
        return value as String?
    }

    private static func uint32Property(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value = UInt32(0)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
        guard status == noErr else { return nil }
        return value
    }

    private static func transportTypeDescription(_ value: UInt32) -> String {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn:
            return "built-in"
        case kAudioDeviceTransportTypeAggregate:
            return "aggregate"
        case kAudioDeviceTransportTypeVirtual:
            return "virtual"
        case kAudioDeviceTransportTypePCI:
            return "pci"
        case kAudioDeviceTransportTypeUSB:
            return "usb"
        case kAudioDeviceTransportTypeFireWire:
            return "firewire"
        case kAudioDeviceTransportTypeBluetooth:
            return "bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE:
            return "bluetooth-le"
        case kAudioDeviceTransportTypeHDMI:
            return "hdmi"
        case kAudioDeviceTransportTypeDisplayPort:
            return "displayport"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplay"
        case kAudioDeviceTransportTypeAVB:
            return "avb"
        case kAudioDeviceTransportTypeThunderbolt:
            return "thunderbolt"
        default:
            return fourCCString(value)
        }
    }

    private static func fourCCString(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
        if bytes.allSatisfy({ $0 >= 32 && $0 < 127 }),
           let text = String(bytes: bytes, encoding: .macOSRoman) {
            return text.lowercased()
        }
        return String(value)
    }
}

final class AudioOutputRouteObserver {
    private let queue = DispatchQueue(label: "com.meetingtranslator.audio-output-route")
    private var address: AudioObjectPropertyAddress
    private let listener: AudioObjectPropertyListenerBlock

    init?(onChange: @escaping @Sendable () -> Void) {
        address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        listener = { _, _ in
            onChange()
        }

        var mutableAddress = address
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &mutableAddress,
            queue,
            listener
        )
        guard status == noErr else { return nil }
        address = mutableAddress
    }

    deinit {
        var mutableAddress = address
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &mutableAddress,
            queue,
            listener
        )
    }
}
