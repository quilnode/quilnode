import Foundation
import XCTest

@testable import QuilNodeShared

final class WalletServiceProtocolTests: XCTestCase {
    func testInventoryDecodesTheEstablishedServiceSchema() throws {
        let id = UUID()
        let json = """
            {
              "schemaVersion": 1,
              "keysets": [{
                "id": "\(id.uuidString)",
                "name": "Current node identity",
                "format": "legacyPre25",
                "health": "migrationRequired",
                "isActive": true,
                "isManaged": false,
                "requiresMigration": true,
                "keyCount": 9,
                "keyTypes": ["proving"],
                "identities": {},
                "sourceLabel": "Existing node",
                "automaticRecoveryCopies": 0,
                "fingerprint": "public-fingerprint",
                "warnings": []
              }],
              "activeKeysetID": "\(id.uuidString)",
              "serviceSupportsTransactions": true,
              "recoveryVaultHealthy": true
            }
            """

        let inventory = try JSONDecoder().decode(
            WalletInventory.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(inventory.activeKeyset?.format, .legacyPre25)
        XCTAssertEqual(inventory.activeKeyset?.health, .migrationRequired)
        XCTAssertTrue(inventory.serviceSupportsTransactions)
    }

    func testTransactionManifestKeepsVersionedIntentOnlySchema() throws {
        let manifest = WalletTransactionManifest(
            kind: .importKeyset,
            displayName: "Seniority identity",
            selectedDirectory: "/operator-selected/keyset",
            confirmedBackupResponsibility: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        XCTAssertEqual(object["kind"] as? String, "importKeyset")
        XCTAssertNil(object["privateKey"])
        XCTAssertNil(object["keyBytes"])
    }
}
