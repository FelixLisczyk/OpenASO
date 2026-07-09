import Foundation
import Testing
@testable import OpenASO

struct KeychainServiceTests {
    @Test
    func dataReturnsNilForAnItemThatWasNeverSaved() {
        let keychain = SystemKeychainService()
        let service = "com.thirdtech.openaso.tests.keychain-service-tests.\(UUID().uuidString)"

        let data = keychain.data(service: service, account: "never-saved")

        #expect(data == nil)
    }

    @Test
    func saveThenDeleteLeavesNoTrace() throws {
        let keychain = SystemKeychainService()
        let service = "com.thirdtech.openaso.tests.keychain-service-tests.\(UUID().uuidString)"
        let account = "round-trip"

        try keychain.save(Data("secret".utf8), service: service, account: account)
        #expect(keychain.data(service: service, account: account) == Data("secret".utf8))

        keychain.delete(service: service, account: account)
        #expect(keychain.data(service: service, account: account) == nil)
    }
}
