//
//  HistoryDB.swift
//  claude
//
//  Created by Tim Tully on 3/11/24.
//

import Foundation
import SQLite3
import SQLCipher

class HistoryDB {
    private init() {}
    
    static let shared = HistoryDB()
    
    static func getInstance() -> HistoryDB {
        return shared
    }
    
    var someProperty: String = "Initial value"
    
    func dbPathFile() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        let databasePath = (documentsPath?.appending("/database_enc.sqlite"))!
        return databasePath
    }
    
    func openTable() -> OpaquePointer? {
        let databasePath = self.dbPathFile()

        guard let encryptionKey = SecurityManager.shared.getOrCreateEncryptionKey() else {
                print("Failed to obtain encryption key.")
                return nil
            }

            guard let db = SecurityManager.shared.openEncryptedDatabase(atPath: databasePath ) else {
                print("Failed to open encrypted database.")
                return nil
            }

            return db
    }
    
    func createTable(db:OpaquePointer) {
        let createTableQuery = "CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT, ts INTEGER)"
        var createTableStatement: OpaquePointer?
        let db = self.openTable()
        if sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
            } else {
                print("Failed to create table")
            }
        } else {
            print("Failed to create table statement")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func insertQuery(query:String) {
        //let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        // Insert data
        let db = self.openTable()
        let insertQuery = "INSERT INTO history (id, query, ts) VALUES (?, ?, ?)"
        var insertStatement: OpaquePointer?
        let currentDate = Date()
        let unixTimestamp = currentDate.timeIntervalSince1970
        if sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) != SQLITE_OK {
              let errorMessage = String(cString: sqlite3_errmsg(db))
              print("Failed to begin transaction: \(errorMessage)")
              return
        }
            if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
                // sqlite3_bind_int(insertStatement, 1, 0)
                if sqlite3_bind_text(insertStatement, 2, query, -1, SQLITE_TRANSIENT) != SQLITE_OK {
                    print("couldnt bind text")
                }
                
                sqlite3_bind_int(insertStatement, 3, Int32(unixTimestamp))
                
                if sqlite3_step(insertStatement) == SQLITE_DONE {
                    print("Data inserted successfully")
                } else {
                    print("Failed to insert data")
                    
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    print("Error inserting statement: \(errmsg)")
                }
            } else {
                print("Failed to create insert statement")
            }
        
        //sqlite3_finalize(insertStatement)
        finalizeStatement(insertStatement)
    
        if sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil) != SQLITE_OK {
                print("Failed to commit transaction.")
            let errorMessage = String(cString: sqlite3_errmsg(db))
                   print("Failed to commit transaction: \(errorMessage)")
                   sqlite3_exec(db, "ROLLBACK TRANSACTION", nil, nil, nil)
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
    
    func getAll() -> [(query:String, ts:Int32, id:Int32)]{
        var rv:[(String,Int32,Int32)] = [];
        let db = self.openTable()
        var statement: OpaquePointer?
        let query = "SELECT * FROM history order by id desc limit 250"
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Error preparing statement for \(query): \(errorMessage)")
            return []
        }
        
        // Execute the statement and retrieve rows
        while sqlite3_step(statement) == SQLITE_ROW {
            // Get the column values
            if let columnValue = sqlite3_column_text(statement, Int32(1)) {
                let val = String(cString:columnValue)
                let id = sqlite3_column_int(statement, Int32(0))
                let ts = sqlite3_column_int(statement, Int32(2))
                if (val != "") {
                    rv.append((query:val, ts:ts, id:id))
                }
            }
            //let ts = sqlite3_column_int64(statement, Int32(2));
        }
        sqlite3_finalize(statement)

        return rv;
    }
    
    func deleteItem(itemId: Int) {
        let db = self.openTable()

        

        // Prepare the DELETE SQL statement
        let deleteStatementString = "DELETE FROM history WHERE id = ?;"
        var deleteStatement: OpaquePointer?

        // Prepare the statement
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            // Bind the id parameter
            sqlite3_bind_int(deleteStatement, 1, Int32(itemId))

            // Execute the DELETE statement
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("Successfully deleted row.")
            } else {
                print("Could not delete row.")
            }
        } else {
            print("DELETE statement could not be prepared.")
        }

        // Finalize the statement
        sqlite3_finalize(deleteStatement)
    }
}
