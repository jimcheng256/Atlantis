//
//  JSScriptingEngine.swift
//  Atlantis
//
//  Created by Jim Cheng on 12/3/25.
//

import Foundation
import JavaScriptCore

@objc(JSScriptingEngine)
public class JSScriptingEngine: ScriptingEngine {
    private struct ScriptFile: Equatable {
        let url: URL
        let modified: Date?
        let size: Int?
        let identifier: String?
    }

    private let scriptsDirectory: URL
    private let resetRegistrations: () -> Void
    private var loadedFiles: [ScriptFile] = []
    private var context: JSContext?
    private var evaluationDepth = 0

    override convenience init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Atlantis/Scripts", isDirectory: true)
        self.init(scriptsDirectory: directory) {
            RDPreferenceMainController()?.removeAllScriptedEvents(forLanguage: "JavaScript")
        }
    }

    init(scriptsDirectory: URL, resetRegistrations: @escaping () -> Void = {}) {
        self.scriptsDirectory = scriptsDirectory
        self.resetRegistrations = resetRegistrations
        super.init()
    }

    public override func scriptEngineName() -> String {
        "JavaScript"
    }

    public override func engineNeedsReinit() -> Bool {
        evaluationDepth == 0 && (context == nil || loadedFiles != scriptFiles())
    }

    public override func engineReinit(_ state: AtlantisState?) {
        guard evaluationDepth == 0, let newContext = JSContext() else { return }

        evaluationDepth += 1
        defer { evaluationDepth -= 1 }

        let files = scriptFiles()
        context = newContext
        loadedFiles = files
        resetRegistrations()

        newContext.setObject(ScriptBridge(), forKeyedSubscript: "ScriptBridge" as NSString)
        newContext.setObject([String: Any](), forKeyedSubscript: "AtlantisState" as NSString)
        let log: @convention(block) (String) -> Void = { NSLog("JavaScript: %@", $0) }
        newContext.setObject(log, forKeyedSubscript: "__atlantisLog" as NSString)
        newContext.evaluateScript("""
            globalThis.console = ((log) => ({
                log: (...values) => log(values.map(String).join(" ")),
                warn: (...values) => log("[WARN] " + values.map(String).join(" ")),
                error: (...values) => log("[ERROR] " + values.map(String).join(" "))
            }))(__atlantisLog);
            delete globalThis.__atlantisLog;
            """)

        for file in files {
            do {
                let source = try String(contentsOf: file.url, encoding: .utf8)
                newContext.evaluateScript(source, withSourceURL: file.url)
                reportException(in: newContext, source: file.url.path)
            } catch {
                NSLog("JavaScript: could not read %@: %@", file.url.path, error.localizedDescription)
            }
        }
    }

    public override func executeFunction(_ source: String, with state: AtlantisState) -> Any? {
        if context == nil {
            engineReinit(state)
        }
        guard let context else { return nil }

        evaluationDepth += 1
        let previousState = context.objectForKeyedSubscript("AtlantisState")
        defer {
            context.setObject(previousState, forKeyedSubscript: "AtlantisState" as NSString)
            evaluationDepth -= 1
        }

        var snapshot = state.scriptSafeData() as? [String: Any] ?? [:]
        let temporaryVariables = RDPreferenceMainController()?.tempStateVars() as? [String: Any] ?? [:]
        for (key, value) in temporaryVariables {
            snapshot["temp.\(key)"] = value
        }
        context.setObject(snapshot, forKeyedSubscript: "AtlantisState" as NSString)

        let expression = source.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = context.evaluateScript(source)
        if expression.range(of: #"^[a-zA-Z_$][a-zA-Z0-9_$]*$"#, options: .regularExpression) != nil,
           let value = result, value.isObject,
           let object = JSValueToObject(context.jsGlobalContextRef, value.jsValueRef, nil),
           JSObjectIsFunction(context.jsGlobalContextRef, object) {
            let arguments = state.extraData(forKey: "event.cause") as? String == "command"
                ? [(state.extraData(forKey: "RDCommandParams") as? [String: Any])?["RDOptsFullString"] as? String ?? ""]
                : []
            result = value.call(withArguments: arguments)
        }

        guard !reportException(in: context, source: "event"), let result, !result.isUndefined else { return nil }
        let value = result.toObject()
        return reportException(in: context, source: "event result") ? nil : value
    }

    private func reportException(in context: JSContext, source: String) -> Bool {
        guard let exception = context.exception else { return false }
        context.exception = nil
        NSLog("JavaScript (%@): %@", source, exception.toString() ?? "Unknown error")
        context.exception = nil
        return true
    }

    private func scriptFiles() -> [ScriptFile] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey, .fileIdentifierKey]
        guard let files = FileManager.default.enumerator(
            at: scriptsDirectory, includingPropertiesForKeys: Array(keys)
        ) else { return [] }

        return files.compactMap { entry -> ScriptFile? in
            guard let url = entry as? URL, url.pathExtension.lowercased() == "js",
                  let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else {
                return nil
            }
            return ScriptFile(url: url, modified: values.contentModificationDate, size: values.fileSize,
                              identifier: values.allValues[.fileIdentifierKey].map { String(describing: $0) })
        }.sorted { $0.url.path < $1.url.path }
    }
}
