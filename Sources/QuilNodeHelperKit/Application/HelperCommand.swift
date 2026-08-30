enum HelperAction: String, CaseIterable {
    case start, stop, restart, install, activate, rollback, bootstrap, migrate, serve
    case qclientInstall = "qclient-install"
    case walletTransact = "wallet-transact"
}
