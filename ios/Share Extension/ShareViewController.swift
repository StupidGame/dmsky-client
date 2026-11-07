import UIKit
import Social
import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
