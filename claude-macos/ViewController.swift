//
//  ViewController.swift
//  claude-macos
//
//  Created by Tim Tully on 7/15/24.
//

import Cocoa
import WebKit
import Speech
import LDSwiftEventSource
import Mixpanel

struct Section {
    let title: String
    let items: [Item]
}

struct Item {
    let query:String
    let date:String
}

class ViewController: NSViewController, NSSearchFieldDelegate, EventHandler, NSTableViewDelegate,
                      NSTableViewDataSource, NSMenuDelegate, NSMenuItemValidation {
    
    @IBOutlet var sideTable:CustomTableView?
    @IBOutlet var webview:WKWebView?
    @IBOutlet var searchBar:NSSearchField?
    @IBOutlet var outlineView:NSOutlineView?
    @IBOutlet var modelPopupMenu:NSPopUpButton!
    @IBOutlet var splitView:NSSplitView?
    @IBOutlet var preferencesMenuItem:NSMenuItem?
    var apikey_textfield:NSTextField?
    var contextMenu: NSMenu!
    
    var preferencesWindowController: PreferencesWindowController?
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    var ANTHROPIC_KEY:String = "";
    
    let ANT_URI = "https://api.anthropic.com/v1/messages";
    
    var audioEngine = AVAudioEngine()
    var curHTML:String = "";
    var cur_div_id:String = "";
    var cur_recognition:SFSpeechRecognitionTask = SFSpeechRecognitionTask()
    var html:String = """
<!DOCTYPE html><html lang=\"en\">
<head>
    <style>
        .response{border-radius: 10px; border: 3px solid #000000;}
        .dark{color:#eeeeee;background-color:#222222;}
body {
    font-family: 'Roboto', sans-serif;
    //font-family: var(--font-styrene-b),ui-sans-serif,system-ui,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji";
    -webkit-font-smoothing: antialiased;
}
    </style>
    <meta charset=\"utf-8\">
    <!-- <meta name=\"HandheldFriendly\" content=\"True\"> -->
    <meta http-equiv=\"cleartype\" content=\"on\"><meta name=\"MobileOptimized\" content=\"320\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/themes/prism.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap" rel="stylesheet">

    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/components/prism-core.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/plugins/autoloader/prism-autoloader.min.js"></script>

</head>
<body id=\"body\" style=\"background-color:#F5F4EF; margin-left:5px;padding-left:5px;font-size:16px; font: Gotham, Arial, sans-serif;\"><br/>
<div id=\"results\"></div>

<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script>
function decodeHTMLEntities(text) {
  const entityMap = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&#x2F;': '/',
    '&#x60;': '`',
    '&#x3D;': '='
  };

  return text.replace(/&[^;]+;/g, function(match) {
    return entityMap[match] || match;
  });
}
function setBodyClass(cl){document.getElementById(\"body\").className = cl;}
function inject(h, div_id){
    h = decodeHTMLEntities(h)
    document.getElementById(div_id).innerHTML += h;
    window.scrollTo(0, document.body.scrollHeight);
}
function renderMarkdown(html, cur_div_id){
 marked.setOptions({
   highlight: function(code, lang) {
     if (Prism.languages[lang]) {
       return Prism.highlight(code, Prism.languages[lang], lang);
     } else {
       return code;
     }
   }
 });

    marked.use({html:true, gfm:true});
 
      //document.getElementById(cur_div_id).innerHTML = marked.parse('&nbsp;' + html);
      document.getElementById(cur_div_id).innerHTML = marked.parse(html);
      Prism.highlightAll();
        return 42;
}
</script>
</body>
</html>
"""
    
    var es:EventSource?;
    
    @IBOutlet weak var submitButton:  NSButton!
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        // Check the segue identifier if there are multiple segues
        if segue.identifier == "hamburger_select" {
            // Downcast the destination ViewController to your specific class
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let config = ConfigManager()
        //self.ANTHROPIC_KEY = config?.value(forKey: "ANTHROPIC_KEY") as! String;
        self.searchBar?.delegate = self
        
        let hdb = HistoryDB.shared;
        let db:OpaquePointer = hdb.openTable()!;
        HistoryDB.shared.createTable(db: db);
        // Do any additional setup after loading the view.
        webview?.loadHTMLString(html, baseURL: nil)
        // self.searchBar.backgroundColor = .white
        //self.view.backgroundColor = NSColor(hex:"#f0eee5");
        NotificationCenter.default.addObserver(self, selector: #selector(handleSearchEvent), name: .RUN_SEARCH, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsAskedFor), name: .showSettingsEvent, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bringToFront), name: .bringToFront, object: nil)
        modelPopupMenu.action = #selector(popupButtonChanged(_:))
        modelPopupMenu.target = self
        
        splitView?.setPosition(100, ofDividerAt: 0)
        sideTable?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
        sideTable?.rowHeight = 40
        sideTable?.dataSource = self
        sideTable?.delegate = self
        
        if let mainMenu = NSApp.mainMenu {
            mainMenu.delegate = self
        }
        
        view.window?.title = "Claude"
        setContextMenu()
        setModel()
        setHistoryHeader()
    }
    
    fileprivate func setContextMenu(){
        self.sideTable?.contextMenu = NSMenu()
        
        let menuItem1 = NSMenuItem(title: "Run Query", action: #selector(menuSelectRunQuery), keyEquivalent: "")
        self.sideTable?.contextMenu?.addItem(menuItem1)
        self.sideTable?.contextMenu?.addItem(NSMenuItem.separator())
        
        let menuItem2 = NSMenuItem(title: "Delete", action: #selector(menuSelectDelete), keyEquivalent: "")
        self.sideTable?.contextMenu?.addItem(menuItem2)
        
        self.sideTable?.contextMenu?.delegate = self
    }
    
    @objc func menuSelectRunQuery() {
        let (sectionIndex, isHeader, itemIndex) = indexForRow(sideTable!.selectedRow)
        if(isHeader) { return }
        let data = groupItemsByDaysAgo(getSearches())
        
        let selectedRow = (sideTable?.selectedRow)!
        if selectedRow >= 0 {
            let q = data[sectionIndex].items[itemIndex].query
            doQuery(q: q, shouldInsertHistory: false)
        }
    }
    
    @objc func menuSelectDelete() {
        
        let all = HistoryDB.shared.getAll()
        let selectedRow = (sideTable?.selectedRow)!
        
        let (sectionIndex, isHeader, itemIndex) = indexForRow(selectedRow)
        
        let item:(query:String, ts:Int32, id:Int32) = all[itemIndex]
        
        HistoryDB.shared.deleteItem(itemId: Int(item.id))
        self.sideTable?.removeRows(at: IndexSet(integer:selectedRow), withAnimation: .effectFade)
        DispatchQueue.main.async{
            self.sideTable?.reloadData()
        }
    }
    
    fileprivate func setHistoryHeader(){
        if let tableColumn = self.sideTable?.tableColumns.first {
            let customHeaderCell = CustomHeaderCell()
            customHeaderCell.image = NSImage(named: "claudelogo")
            tableColumn.headerCell = customHeaderCell
        }
    }
    
    fileprivate func setModel(){
        let ud:UserDefaults = UserDefaults.standard
        if ud.object(forKey:Constants.PREFERENCE_MODEL_SELECTED) != nil {
            let model:String = (ud.value(forKey: Constants.PREFERENCE_MODEL_SELECTED) as? String)!
            switch model {
            case Constants.MODEL_NAME_HAIKU:
                setSelectedItem(title: Constants.DISPLAY_MODEL_NAME_HAIKU)
                break;
            case Constants.MODEL_NAME_OPUS:
                setSelectedItem(title: Constants.DISPLAY_MODEL_NAME_OPUS)
                break;
            case Constants.MODEL_NAME_SONNET_35:
                setSelectedItem(title: Constants.DISPLAY_MODEL_NAME_SONNET_35)
                break;
            case Constants.MODEL_NAME_SONNET_37:
                setSelectedItem(title: Constants.DISPLAY_MODEL_NAME_SONNET_37)
                break;
            case Constants.MODEL_NAME_SONNET:
                setSelectedItem(title: "Claude 3 Sonnet")
                break;
            default:
                setSelectedItem(title: Constants.DISPLAY_MODEL_NAME_SONNET_35)
                break;
            }
        }
        else{
            setSelectedItem(title: Constants.DISPLAY_MODEL_NAME_SONNET_35)
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let items:[Item] = getSearches()
        let data = groupItemsByDaysAgo(items)
        return data.reduce(0) { $0 + $1.items.count + 1 } // +1 for each section header
        
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return nil
    }
    
    @objc func bringToFront(){
        for window in NSApplication.shared.windows {
            if !window.isKind(of: NSClassFromString("NSStatusBarWindow")!) && !window.isKind(of:NSClassFromString("NSPopupMenuWindow")!){
                window.makeKeyAndOrderFront(nil)
            }
        }
        if let window = AppDelegate.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func handleSettingsAskedFor(){
        self.preferencesMenuSelected(nil)
    }
    
    @IBAction @objc func preferencesMenuSelected(_ sender: NSMenuItem?) {
        var customWindowController:NSWindowController?
        if customWindowController == nil {
            let customWindow = NSWindow(contentRect: NSMakeRect(100, 100, 400, 300),
                                        styleMask: [.titled, .closable, .resizable],
                                        backing: .buffered, defer: false)
            customWindow.title = "Claude Settings"
            customWindowController = NSWindowController(window: customWindow)
            // Create and configure the label
            let label = NSTextField(labelWithString: "API Key:")
            label.frame = NSRect(x: 20, y: 200, width: 100, height: 24)
            
            self.apikey_textfield = NSTextField(frame: NSRect(x: 90, y: 200, width: 300, height: 24))
            self.apikey_textfield?.lineBreakMode = .byCharWrapping
            let ud = UserDefaults.standard
            let api_key = ud.object(forKey: Constants.SAVED_API_KEY)
            if  api_key != nil {
                self.apikey_textfield?.stringValue = (api_key as? String)!
            }
            
            let button = NSButton(frame: NSRect(x: 160, y: 100, width: 100, height: 30))
            
            button.title = "Save"
            button.bezelStyle = .rounded
            button.target = self
            button.action = #selector(saveButtonClicked(_:))
            
            customWindowController?.window?.contentView?.addSubview(button)
            customWindowController?.window?.contentView?.addSubview(label)
            customWindowController?.window?.contentView?.addSubview(apikey_textfield!)
            customWindowController?.window?.styleMask.remove(.resizable)
            customWindowController?.window?.center()
        }
        //customWindowController = PreferencesWindowController(windowNibName: "PreferencesWindow")
        customWindowController?.showWindow(self)
        customWindowController?.window?.makeKeyAndOrderFront(self)
        
        sender?.isEnabled = true
        sender?.isHidden = false
        
    }
    
    @objc func saveButtonClicked(_ sender:NSButton){
        let ud = UserDefaults.standard
        let val = apikey_textfield?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ud.setValue(val, forKey: Constants.SAVED_API_KEY)
    }
    
    @objc func handleSearchEvent(notification: Notification) {
        if let userInfo = notification.userInfo as? [String: Any] {
            let data = userInfo["qt"] as? String // Change the type according to the actual data type
            // Use the extracted data
            doQuery(q:data!)
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Adjust the first column to take up the whole width of the table
        if let firstColumn = sideTable?.tableColumns.first {
            firstColumn.width = (sideTable?.bounds.width)!
            for column in sideTable!.tableColumns.dropFirst() {
                column.width = 0
            }
        }
    }
    
    func setTheme(){
        let functionName = "setBodyClass"
        let arguments:[String] = []
        /*
         if self.traitCollection.userInterfaceStyle == .dark {
         arguments = ["'dark'"]
         } else {
         arguments = ["'light'"]
         }
         */
        let argumentsString = arguments.map { String($0) }.joined(separator: ",")
        let script = "\(functionName)(\(argumentsString));"
        webview?.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error calling JavaScript function: \(error.localizedDescription)")
            }
        }
    }
    
    func injectHTML(html:String, div_id:String) {
        let functionName = "inject"
        let newhtml = "'" + html + "'"
        let arguments = [newhtml, "'" + div_id + "'"] // Pass any arguments required by the function
        let argumentsString = arguments.map { String($0) }.joined(separator: ",")
        
        let script = "\(functionName)(\(argumentsString));"
        
        webview?.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error calling JavaScript function: \(error.localizedDescription)")
            }
        }
    }
    
    func renderMarkdown(h:String, div_id:String){
        
        let functionName = "renderMarkdown"
        let newhtml = "'" + h + "'"
        let arguments = [newhtml, "'" + div_id + "'"] // Pass any arguments required by the function
        let argumentsString = arguments.map { String($0) }.joined(separator: ",")
        
        let script = "\(functionName)(\(argumentsString));"
        webview?.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error calling JavaScript function: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func query(sender: NSButton) {
        let q = searchBar?.stringValue
        doQuery(q:q!);
    }
    
    // NSSearchFieldDelegate method
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if let event = NSApp.currentEvent  {
            if event.keyCode == 36 {
                let searchText = textField.stringValue
                doQuery(q:searchText)
            }
        }
    }
    
    func micHud(on:Bool) {
        DispatchQueue.main.async { () -> Void in
            if (on) {
                // ProgressHUD.animate("Please wait...", .horizontalBarScaling)
            }
            else{
                // ProgressHUD.remove()
            }
        }
    }
    
    
    @objc func popupButtonChanged(_ sender: NSPopUpButton) {
        let selectedItem = sender.titleOfSelectedItem
        let cur:UserDefaults = UserDefaults.standard
        
        if selectedItem == Constants.DISPLAY_MODEL_NAME_OPUS {
            cur.setValue(Constants.MODEL_NAME_OPUS, forKey: Constants.PREFERENCE_MODEL_SELECTED)
        }
        else
        if selectedItem == Constants.DISPLAY_MODEL_NAME_HAIKU {
            cur.setValue(Constants.MODEL_NAME_HAIKU, forKey: Constants.PREFERENCE_MODEL_SELECTED)
        }
        else
        if selectedItem == Constants.DISPLAY_MODEL_NAME_SONNET_35 {
            cur.setValue(Constants.MODEL_NAME_SONNET_35, forKey: Constants.PREFERENCE_MODEL_SELECTED)
        }
        else
        if selectedItem == Constants.DISPLAY_MODEL_NAME_SONNET_37 {
            cur.setValue(Constants.MODEL_NAME_SONNET_37, forKey: Constants.PREFERENCE_MODEL_SELECTED)
        }
        setSelectedItem(title: selectedItem ?? "")
        
        cur.synchronize()
    }
    
    func setSelectedItem(title: String) {
        if let item = modelPopupMenu.item(withTitle: title) {
            DispatchQueue.main.async{
                self.modelPopupMenu.select(item)
            }
        } else {
            print("Item with title '\(title)' not found")
        }
    }
    
    
    func currentSelectedModelName() -> String {
        let cur = UserDefaults.standard.string(forKey: Constants.PREFERENCE_MODEL_SELECTED)
        if (cur == nil) {
            return Constants.MODEL_NAME_SONNET
        }
        return cur!
    }
    
    
    func textFieldShouldReturn(_ textField: NSTextField) -> Bool {
        doQuery(q:searchBar!.stringValue)
        return true
    }
    
    @inlinable func doQuery(q:String, shouldInsertHistory:Bool=true) {
        Mixpanel.mainInstance().track(event: "Search")
        let uri = URL(string:ANT_URI);
        var config = EventSource.Config.init(handler: self, url: uri!);
        let ud = UserDefaults.standard
        let key = ud.value(forKey: Constants.SAVED_API_KEY)
        if key == nil || key as! String == ""{
            let alert = NSAlert()
            alert.messageText = "Alert Title"
            alert.informativeText = "API key missing.  Go to App Menu (Claude menu), then Settings and enter API key there."
            alert.alertStyle = .warning // You can choose between .warning, .informational, or .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        config.headers = ["Content-type": "application/json", "x-api-key":key as! String, "anthropic-version":"2023-06-01", "anthropic-beta":"messages-2023-12-15" ];
        config.method = "POST";
        let model = currentSelectedModelName()
        let postData2:[String:Any] = ["model": currentSelectedModelName(), "max_tokens": 4096, "stream":true, "messages": [["role": "user", "content": q]]];
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postData2, options: []) else {
            print("Error serializing JSON")
            return
        }
        
        config.body = jsonData
        config.idleTimeout = 600.0
        self.cur_div_id = generateRandomString(length: 10)
        
        DispatchQueue.main.async { () -> Void in
            self.setTheme()
            self.injectHTML(html: "<hr><h2>" + q + "</h2><div id=\"\(self.cur_div_id)\"></div>", div_id:"results")
            //self.view.endEditing(true)
            
        }
        
        self.es = EventSource(config: config);
        DispatchQueue.global(qos: .utility).async { [weak self] () -> Void in
            self!.es!.start()
            if(shouldInsertHistory){
                HistoryDB.shared.insertQuery(query: q)
            }
        }
        DispatchQueue.main.async{
            self.sideTable?.reloadData()
        }
    }
    
    @inlinable func jsonToDict(jsonString:String) -> [String:Any]{
        let jsonData = jsonString.data(using: .utf8)
        
        do {
            
            if let dictionary = try JSONSerialization.jsonObject(with: jsonData!, options: []) as? [String: Any] {
                // Now `dictionary` is a [String: Any] dictionary.
                return dictionary
            } else {
                print("The JSON is not a dictionary.")
            }
        } catch {
            print("Error deserializing JSON: \(error.localizedDescription)")
        }
        return [:]
    }
    
    
    @inlinable func onMessage(eventType: String, messageEvent: MessageEvent){
        let data = messageEvent.data;
        let data_obj = self.jsonToDict(jsonString: data)
        if (data_obj["type"] as! String == "content_block_delta") {
            let delta = data_obj["delta"] as! [String:Any];
            
            var newhtml = delta["text"] as! String
            
            newhtml = newhtml.replacingOccurrences(of: "\n", with: "\\n")
            newhtml = newhtml.replacingOccurrences(of: "'", with: "&#39;")
            
            DispatchQueue.global(qos: .utility).async { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                DispatchQueue.main.async { [self] () -> Void in
                    strongSelf.injectHTML(html: newhtml, div_id:self!.cur_div_id)
                    
                    
                    
                    self?.renderMarkdown(h: self!.curHTML, div_id: self!.cur_div_id)
                }
            }
            curHTML += newhtml;
        }
    }
    
    func onOpened(){
    }
    
    func onClosed(){
        self.es?.stop()
        
        let curHTMLCopy = curHTML // make copy to stop race on curHTML
        let div_id = cur_div_id
        DispatchQueue.main.async { [self] () -> Void in
            //self.injectHTML(html: "</div>", div_id:div_id)
            self.renderMarkdown(h:curHTMLCopy, div_id:div_id)
        }
        self.cur_div_id = ""
        curHTML = "";
    }
    
    func onComment(comment: String){}
    func onError(error: Error){
        print(error)
    }
    
    func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        
        for _ in 0..<length {
            let randomIndex = Int(arc4random_uniform(UInt32(characters.count)))
            let randomCharacter = characters.index(characters.startIndex, offsetBy: randomIndex)
            randomString.append(characters[randomCharacter])
        }
        
        return randomString
    }
    
    func getSearches() -> [Item] {
        var items:[Item] = []
        let all = HistoryDB.shared.getAll()
        for search in all {
            let days = daysOld(fromUnixTimestamp: Double(search.ts))
            let item = Item(query:search.query, date: String(days))
            items.append(item)
        }
        return items
    }
    
    private func indexForRow(_ row: Int) -> (section: Int, isHeader: Bool, itemIndex: Int) {
        var currentRow = 0
        let data = groupItemsByDaysAgo(getSearches())
        for (sectionIndex, section) in data.enumerated() {
            if currentRow == row {
                return (sectionIndex, true, -1)
            }
            currentRow += 1
            if row < currentRow + section.items.count {
                return (sectionIndex, false, row - currentRow)
            }
            currentRow += section.items.count
        }
        return (0, false, 0) // Should never reach here if the data is correct
    }
    
    
    func numberOfSections(in tableView: NSTableView) -> Int {
        let all = HistoryDB.shared.getAll()
        var uniq:[String:Int32] = [:]
        for row in all {
            let days_old:String = String(daysOld(fromUnixTimestamp: Double(row.ts)))
            uniq[days_old] = 1
        }
        return uniq.count
    }
    
    func groupItemsByDaysAgo(_ items: [Item]) -> [Section] {
        var sections: [String: [Item]] = [:]
        
        for item in items {
            let sectionTitle = item.date
            if sections[sectionTitle] != nil {
                sections[sectionTitle]?.append(item)
            } else {
                sections[sectionTitle] = [item]
            }
        }
        
        // Convert dictionary to array of Section, sorted by days ago asc
        return sections.map { Section(title: $0.key, items: $0.value) }
            .sorted { $0.title < $1.title }
    }
    
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let (_, isHeader, _) = indexForRow(row)
        if (isHeader) {
            return 55
        }
        return 30
    }
    
    
    // NSTableViewDelegate method
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
        guard let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else {
            return nil
        }
        let data = groupItemsByDaysAgo(getSearches())
        
        let (sectionIndex, isHeader, itemIndex) = indexForRow(row)
        if (isHeader){
            var title = data[sectionIndex].title
            if title == "0" {
                title = "Today"
            }
            else
            if (title == "1"){
                title = "Yesterday"
            }
            else {
                title = title + " days ago"
            }
            cell.textField!.stringValue = title
            cell.textField!.font = NSFont.systemFont(ofSize: 14, weight:.bold)
        }
        else{
            cell.textField?.backgroundColor = NSColor(calibratedWhite: 0.65, alpha: 1.0)
            let font = NSFont.systemFont(ofSize:14)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.lightGray
            ]
            let attributedString = NSAttributedString(string: data[sectionIndex].items[itemIndex].query, attributes: attributes)
            cell.textField?.attributedStringValue = attributedString
            
        }
        return cell
    }
    
    // Optional NSTableViewDelegate method for handling row selection
    func tableViewSelectionDidChange(_ notification: Notification) {
        let (sectionIndex, isHeader, itemIndex) = indexForRow(sideTable!.selectedRow)
        if(isHeader) { return }
        let data = groupItemsByDaysAgo(getSearches())
        
        let selectedRow = (sideTable?.selectedRow)!
        if selectedRow >= 0 {
            let q = data[sectionIndex].items[itemIndex].query
            //doQuery(q: q, shouldInsertHistory: false)
        }
    }
    
    @IBAction func showPreferences(_ sender: NSMenuItem) {
        
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController.shared
        }
        preferencesWindowController?.showWindow(self)
        
        sender.isEnabled = true
        sender.isHidden = false
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showPreferences(_:)) {
            return true
        }
        return true
    }
    
    
    
    func daysOld(fromUnixTimestamp timestamp: TimeInterval) -> Int {
        let currentDate = Date()
        let timestampDate = Date(timeIntervalSince1970: timestamp)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: timestampDate, to: currentDate)
        
        return components.day ?? 0
    }
    
    func tableView(_ tableView: NSTableView, menuFor event: NSEvent, row: Int) -> NSMenu? {
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        
        if row >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            return self.sideTable?.contextMenu
        }
        return nil
    }
    
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        let clickedRow = self.sideTable?.clickedRow
        if clickedRow! >= 0 {
            // Update menu items based on the clicked row if needed
        } else {
            // Hide or disable menu items if no row was clicked
        }
    }
    override func rightMouseDown(with event: NSEvent) {
        let point = self.sideTable?.convert(event.locationInWindow, from: nil)
        let row = self.sideTable?.row(at: point!)
        
        let (sectionIndex, isHeader, itemIndex) = indexForRow(row!)
        if(isHeader){
            super.rightMouseDown(with: event)
            return
        }
        
        if row! >= 0 {
            self.sideTable?.selectRowIndexes(IndexSet(integer: row!), byExtendingSelection: false)
            NSMenu.popUpContextMenu( (self.sideTable?.contextMenu)!, with: event, for: self.sideTable!)
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
}


