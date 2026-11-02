import Foundation

enum Server {
    static let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "RokapiURL") as! String)!
}
