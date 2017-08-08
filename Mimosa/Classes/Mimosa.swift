//
//  Mimosa.swift
//  Mimosa
//
//  Created by Patrick Metcalfe on 8/7/17.
//

import Foundation
import SceneKit
import CoreLocation
import Starscream

public struct Quaternion : Codable {
    public let w : Double
    public let x : Double
    public let y : Double
    public let z : Double
    
    public init(_ w : Double, _ x : Double, _ y : Double, _ z : Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }
    
    public init(scnVector : SCNVector4) {
        w = Double(scnVector.w)
        x = Double(scnVector.x)
        y = Double(scnVector.y)
        z = Double(scnVector.z)
    }
}

public struct InternalParameters : Codable {
    public let sceneHeight : Int
    public let sceneWidth : Int
    
    public let isPortrait : Int
    public let fov : Float
    
    public init(sceneSize : CGSize, fieldOfView : Float, isPortrait : Bool) {
        sceneWidth = Int(sceneSize.width)
        sceneHeight = Int(sceneSize.height)
        self.isPortrait = isPortrait ? 1 : 0
        fov = fieldOfView
    }
}

public struct ExternalParameters : Codable {
    public let latitude : Double
    public let longitude : Double
    public let height : Double
    
    public let quaternion : Quaternion
    
    public init(latitude : Double, longitude : Double, height : Double, orientation : Quaternion) {
        self.latitude = latitude
        self.longitude = longitude
        self.height = height
        self.quaternion = orientation
    }
    
    public init(location : CLLocation, orientation : Quaternion) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        height = location.altitude
        quaternion = orientation
    }
}

public struct AIServerRequest {
    public struct Parameters : Codable {
        public let internalParameters : InternalParameters
        public let externalParameters : ExternalParameters
        
        public init(`internal` internalParams : InternalParameters, external externalParams : ExternalParameters) {
            self.internalParameters = internalParams
            self.externalParameters = externalParams
        }
    }
    
    public var imageData : Data
    public var parameters : Parameters
    
    public init(imageData : Data, parameters : Parameters) {
        self.imageData = imageData
        self.parameters = parameters
    }
    
    public func asData() -> Data? {
        var result = Data()
        var imageSize = UInt32(imageData.count)
        withUnsafeBytes(of: &imageSize) { pointer in
            guard let firstAddress = pointer.baseAddress else { return }
           result.append(firstAddress.assumingMemoryBound(to: UInt8.self), count: 4)
        }
        print(result.count)
        result.append(imageData)
        
        let jsonEncoder = JSONEncoder()
        guard let parametersData = try? jsonEncoder.encode(parameters) else { return nil }
        result.append(parametersData)
        
        return result
    }
}

public typealias ServerRespondable = Codable

public struct ServerResponse<Respondable : ServerRespondable> : ServerRespondable {
    public enum Status : String, Codable {
        case success
        case failure
    }
    
    public let status : Status
    public let data : Respondable
}

public struct AIServerResponse : ServerRespondable {
    public let latitude : Double
    public let longitude : Double
    
    public let x : Double
    public let y : Double
    public let z : Double
    
    public let height : Double
    
    public let yx : Double
    public let xx : Double
}

public struct AIServerErrorResponse : ServerRespondable {
    let msg : String
    let status : ServerResponse<String>.Status
}

public class Mimosa {
    public class func callToServer(url : URL, with data : Data, onComplete completionHandler : @escaping ((ServerResponse<AIServerResponse>) -> Void)) {
        let socket = WebSocket(url: url)
        socket.onConnect = {
            print("Mimosa Connected to Server")
            socket.write(data: data) {
                print("Sent Data")
            }
        }
        socket.onDisconnect = { (possibleError : NSError?) in
            if let error = possibleError {
                print("Mimosa Recieved Error \(error)")
            } else {
                print("Mimosa Disconnected from Server")
            }
        }
        
        socket.onText = { text in
            guard let data = text.data(using: .utf8) else {
                print("Error converting response to data")
                return
            }
            print("Got text ", text)
            let jsonDecoder = JSONDecoder()
            if let response = try? jsonDecoder.decode(ServerResponse<AIServerResponse>.self, from: data) {
                completionHandler(response)
            } else if let errorResponse = try? jsonDecoder.decode(AIServerErrorResponse.self, from: data) {
                print(errorResponse.msg)
                let response = ServerResponse<AIServerResponse>(status: .failure, data: AIServerResponse(latitude: 0, longitude: 0, x: 0, y: 0, z: 0, height: 0, yx: 0, xx: 0))
                completionHandler(response)
            }
        }
        
        socket.connect()
    }
}
