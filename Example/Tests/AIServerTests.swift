import UIKit
import XCTest
import Mimosa

extension UIImage {
    func cropping(to rect: CGRect, toOrientation : UIImageOrientation = .up) -> UIImage {
        var rect = rect
        rect.origin.x*=self.scale
        rect.origin.y*=self.scale
        rect.size.width*=self.scale
        rect.size.height*=self.scale
        
        let imageRef = self.cgImage!.cropping(to: rect)
        let image = UIImage(cgImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
        return image
    }
}

class AIServerTests: XCTestCase {
    
    override func setUp() {
        
    }
    
    func testProvidedData() {
        isPortrait = false
        imageData = UIImageJPEGRepresentation(imageFrom(name: "exampleImage"), 0)
        makeRequest()
    }
    
    func testOrientationSwitch() {
        let image = imageFrom(name: "exampleImage").cropping(to: CGRect(x: 437.5, y: 0, width: CGFloat(405), height: CGFloat(720)))
        isPortrait = true
        imageData = UIImageJPEGRepresentation(image, 0)
        makeRequest()
    }
    
    func imageFrom(name : String, file: StaticString = #file, line : UInt = #line) -> UIImage {
        let bundle = Bundle(for: type(of: self))
        guard let imageURL = bundle.url(forResource: name, withExtension: ".jpg") else {
            XCTFail("Image file not found", file: file, line: line)
            return UIImage()
        }
        return imageFrom(url: imageURL)
    }
    
    func imageFrom(url : URL, file: StaticString = #file, line : UInt = #line) -> UIImage {
        guard let rawImageData = try? Data(contentsOf: url) else {
            XCTFail("Image could not be read", file: file, line: line)
            return UIImage()
        }
        
        guard let uiImage = UIImage(data: rawImageData) else {
            XCTFail("Image couldn't be converted", file: file, line: line)
            return UIImage()
        }
        return uiImage
    }
    
    var imageData : Data?
    var screenSize : CGSize = CGSize(width: 1280, height: 720)
    var isPortrait : Bool = false
    var location : CGPoint = CGPoint(x: 37.35791604, y: -121.93528937)
    var orientation : Quaternion = Quaternion(0.11332562565803528, 0.14226141571998596, 0.7066415548324585, 0.6837958097457886)
    var internalParams = InternalParameters(sceneSize: CGSize(width: 1280, height: 720), fieldOfView: 40.0, isPortrait: false)
    var externalParams = ExternalParameters(latitude: 37.35791604, longitude: -121.93528937, height: -11.0, orientation: Quaternion(0.11332562565803528, 0.14226141571998596, 0.7066415548324585, 0.6837958097457886))
    var request : AIServerRequest?
    
    func makeThingsWithVariables() {
        internalParams = InternalParameters(sceneSize: screenSize, fieldOfView: 40.0, isPortrait: isPortrait)
        externalParams = ExternalParameters(latitude: Double(location.x), longitude: Double(location.y), height: -11.0, orientation: orientation)
    }
    
    func makeRequest(file: StaticString = #file, line : UInt = #line) {
        guard let image = imageData else {
            XCTFail("No image data set", file: file, line: line)
            return
        }
        let parameters = AIServerRequest.Parameters(internal: internalParams, external: externalParams)
        request = AIServerRequest(imageData: image, parameters: parameters)
        sendRequest(file: file, line: line)
    }
    
    func sendRequest(file: StaticString = #file, line : UInt = #line) {
        guard let request = request else {
            XCTFail("No request set", file: file, line: line)
            return
        }
        guard let requestData = request.asData() else {
            XCTFail("Request could not be made into data", file: file, line: line)
            return
        }
        guard let url = URL(string: "wss://ai.devsturfee.com/ws") else {
            XCTFail("URL is invalid", file: file, line: line)
            return
        }
        let responseExpectation = XCTestExpectation(description: "Recieved Response")
        
        Mimosa.callToServer(url: url, with: requestData) { response in
            print(response)
            responseExpectation.fulfill()
            XCTAssert(response.status == .success, file: file, line: line)
        }
        wait(for: [responseExpectation], timeout: 10)
    }
}
