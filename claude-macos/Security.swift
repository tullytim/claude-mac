import Foundation
import SQLCipher

class SecurityManager {
    
    // Singleton instance
    static let shared = SecurityManager()
    
    // Keychain account identifier
    private let keychainAccount = "com.menlovc.claude-macos"
    // Database connection
    private var db: OpaquePointer?
    
    private init() {
        // Open the database connection when the singleton is initialized
        let databasePath = "/path/to/your/database.db"
        self.db = self.openEncryptedDatabase(atPath: databasePath)
    }
    
    deinit {
        // Close the database connection when the singleton is deinitialized
        closeDatabase()
    }
    
    func generateEncryptionKey() -> Data? {
        var key = Data(count: 32) // 256-bit key
        let result = key.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        return result == errSecSuccess ? key : nil
    }

    func storeKeyInKeychain(key: Data, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: key
        ]

        SecItemDelete(query as CFDictionary) // Delete any existing item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func retrieveKeyFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func getOrCreateEncryptionKey() -> Data? {
        if let existingKey = retrieveKeyFromKeychain(account: keychainAccount) {
            return existingKey
        } else {
            if let newKey = generateEncryptionKey() {
                if storeKeyInKeychain(key: newKey, account: keychainAccount) {
                    print("Generated and stored new encryption key.")
                    return newKey
                } else {
                    print("Failed to store new encryption key.")
                    return nil
                }
            } else {
                print("Failed to generate new encryption key.")
                return nil
            }
        }
    }

    func openEncryptedDatabase(atPath path: String) -> OpaquePointer? {
        if let existingDb = self.db {
            return existingDb
        }

        guard let encryptionKey = getOrCreateEncryptionKey() else {
            print("Failed to obtain encryption key.")
            return nil
        }

        var db: OpaquePointer?
        if sqlite3_open(path, &db) == SQLITE_OK {
            let keyString = encryptionKey.base64EncodedString()
            if sqlite3_key(db, keyString, Int32(keyString.utf8.count)) == SQLITE_OK {
                print("Database opened and encrypted successfully at \(path).")
                self.db = db
                return db
            } else {
                print("Failed to set encryption key.")
            }
        } else {
            print("Unable to open database.")
        }
        return nil
    }

    func closeDatabase() {
        if let db = db {
            if sqlite3_close(db) != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Failed to close database: \(errorMessage)")
            } else {
                print("Database closed successfully.")
            }
            self.db = nil
        }
    }
    
    func finalizeStatement(_ statement: OpaquePointer?) {
        if let statement = statement {
            let result = sqlite3_finalize(statement)
            if result != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(sqlite3_db_handle(statement)))
                print("Failed to finalize statement: \(errorMessage)")
            }
        }
    }
    
    func runSelectQuery(query: String) {
        guard let db = openEncryptedDatabase(atPath: "/path/to/your/database.db") else {
            print("Database is not open.")
            return
        }
        
        var selectStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &selectStatement, nil) == SQLITE_OK {
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                let id = sqlite3_column_int(selectStatement, 0)
                if let name = sqlite3_column_text(selectStatement, 1) {
                    let nameString = String(cString: name)
                } else {
                }
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SELECT statement could not be prepared: \(errorMessage)")
        }
        
        finalizeStatement(selectStatement)
    }
    
    func insertDataWithTransaction(id: Int, name: String) -> Bool {
        guard let db = openEncryptedDatabase(atPath: "/path/to/your/database.db") else {
            print("Database is not open.")
            return false
        }

        if sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Failed to begin transaction: \(errorMessage)")
            return false
        }
        
        let insertStatementString = "INSERT INTO Contact (Id, Name) VALUES (?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(insertStatement, 1, Int32(id))
            sqlite3_bind_text(insertStatement, 2, (name as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Successfully inserted row.")
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Could not insert row: \(errorMessage)")
                finalizeStatement(insertStatement)
                sqlite3_exec(db, "ROLLBACK TRANSACTION", nil, nil, nil)
                return false
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("INSERT statement could not be prepared: \(errorMessage)")
            sqlite3_exec(db, "ROLLBACK TRANSACTION", nil, nil, nil)
            return false
        }
        finalizeStatement(insertStatement)
        
        if sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Failed to commit transaction: \(errorMessage)")
            sqlite3_exec(db, "ROLLBACK TRANSACTION", nil, nil, nil)
            return false
        }
        
        return true
    }
}
