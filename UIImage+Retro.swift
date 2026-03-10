import UIKit

extension UIImage {
    func normalized() -> UIImage { self }
    func centerCroppedTo4by3() -> UIImage { self }
    func resized(to size: CGSize) -> UIImage { self }
    func withDateStamp() -> UIImage { self }
}
