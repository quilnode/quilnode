import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class WalletModelTests: XCTestCase {
    func testWalletIntentAndRecoveryMetadata() {
        let importIntent = WalletTransactionManifest(
            kind: .importKeyset,
            displayName: "Legacy identity",
            selectedDirectory: "/Users/operator/Chosen-Keyset",
            confirmedBackupResponsibility: true
        )
        expect(importIntent.schemaVersion == 2, "wallet capability manifest version")
        expect(
            importIntent.selectedDirectory?.hasSuffix("Chosen-Keyset") == true, "wallet import carries path capability")
        expect(importIntent.exportParentDirectory == nil, "wallet import never carries export access")

        let exportIntent = WalletTransactionManifest(
            kind: .exportRecovery,
            displayName: "Active identity",
            exportParentDirectory: "/Volumes/Encrypted",
            confirmedBackupResponsibility: true
        )
        expect(exportIntent.selectedDirectory == nil, "wallet export never carries import access")
        expect(
            exportIntent.exportParentDirectory == "/Volumes/Encrypted", "wallet export carries destination capability")

        let legacyKeysetMetadata =
            #"{"id":"00000000-0000-0000-0000-000000000001","name":"Existing identity","format":"current25","health":"ready","isActive":true,"isManaged":true,"requiresMigration":false,"keyCount":11,"keyTypes":[],"identities":{},"sourceLabel":"Existing node","automaticRecoveryCopies":1,"fingerprint":"test","warnings":[]}"#
            .data(using: .utf8)!
        if let decoded = try? JSONDecoder().decode(ManagedKeyset.self, from: legacyKeysetMetadata) {
            expect(decoded.lastExternalBackupAt == nil, "legacy identity metadata defaults external backup to unknown")
        } else {
            XCTFail("legacy identity metadata compatibility")
        }

        let externalBackupDate = Date(timeIntervalSince1970: 1_777_777_777)
        let recoveryMetadata = ManagedKeyset(
            name: "Protected identity",
            format: .current25,
            health: .ready,
            sourceLabel: "Test fixture",
            lastVerifiedBackupAt: externalBackupDate,
            lastExternalBackupAt: externalBackupDate,
            automaticRecoveryCopies: 2,
            fingerprint: "test"
        )
        if let data = try? JSONEncoder().encode(recoveryMetadata),
            let decoded = try? JSONDecoder().decode(ManagedKeyset.self, from: data)
        {
            expect(decoded.automaticRecoveryCopies == 2, "internal recovery snapshot count round trip")
            expect(decoded.lastExternalBackupAt == externalBackupDate, "external recovery state round trip")
        } else {
            XCTFail("recovery metadata round trip")
        }

    }
}
