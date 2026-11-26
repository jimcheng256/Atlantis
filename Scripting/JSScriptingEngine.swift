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

    private struct ScheduledTimer {
        let timer: Timer
        let callback: JSValue
        let repeats: Bool
    }

    private final class TimerTarget: NSObject {
        weak var engine: JSScriptingEngine?

        @objc func fire(_ timer: Timer) {
            engine?.fireTimer(timer)
        }
    }

    private let scriptsDirectory: URL
    private let resetRegistrations: () -> Void
    private var loadedFiles: [ScriptFile] = []
    private var context: JSContext?
    private var evaluationDepth = 0
    private var timers: [Int32: ScheduledTimer] = [:]
    private var lastTimerID: Int32 = 0
    private lazy var timerTarget: TimerTarget = {
        let target = TimerTarget()
        target.engine = self
        return target
    }()

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

    deinit {
        cancelTimers()
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
        cancelTimers()
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

        installTimers(in: newContext)

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

        var snapshot = state.scriptSafeData() as? [String: Any] ?? [:]
        let temporaryVariables = RDPreferenceMainController()?.tempStateVars() as? [String: Any] ?? [:]
        for (key, value) in temporaryVariables {
            snapshot["temp.\(key)"] = value
        }
        return withState(snapshot, in: context) {
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
    }

    private func withState<Result>(_ snapshot: [String: Any], in context: JSContext, work: () -> Result) -> Result {
        evaluationDepth += 1
        let key = "AtlantisState" as NSString
        let previousState = context.objectForKeyedSubscript(key)
        context.setObject(snapshot, forKeyedSubscript: key)
        defer {
            context.setObject(previousState, forKeyedSubscript: key)
            evaluationDepth -= 1
        }
        return work()
    }

    private func installTimers(in context: JSContext) {
        let schedule: @convention(block) (JSValue, Int32, Bool) -> Int32 = { [weak self] callback, delay, repeats in
            self?.scheduleTimer(callback, milliseconds: delay, repeats: repeats) ?? 0
        }
        let cancel: @convention(block) (Int32) -> Void = { [weak self] id in
            self?.cancelTimer(id)
        }
        context.setObject(schedule, forKeyedSubscript: "__atlantisScheduleTimer" as NSString)
        context.setObject(cancel, forKeyedSubscript: "__atlantisCancelTimer" as NSString)
        context.evaluateScript("""
            ((schedule, cancel, global, apply, evaluate, toString) => {
                function makeTimer(repeats) {
                    return function (handler, delay = 0, ...args) {
                        if (arguments.length === 0) {
                            throw new TypeError("A timer handler is required");
                        }
                        const milliseconds = delay | 0;
                        if (typeof handler === "function") {
                            return schedule(() => apply(handler, global, args), milliseconds, repeats);
                        }
                        const code = toString(handler);
                        return schedule(() => evaluate(code), milliseconds, repeats);
                    };
                }
                global.setTimeout = makeTimer(false);
                global.setInterval = makeTimer(true);
                global.clearTimeout = id => { cancel(id | 0); };
                global.clearInterval = id => { cancel(id | 0); };
            })(__atlantisScheduleTimer, __atlantisCancelTimer, globalThis, Reflect.apply, eval, String);
            delete globalThis.__atlantisScheduleTimer;
            delete globalThis.__atlantisCancelTimer;
            """)
        reportException(in: context, source: "timer initialization")
    }

    private func scheduleTimer(_ callback: JSValue, milliseconds: Int32, repeats: Bool) -> Int32 {
        repeat {
            lastTimerID = lastTimerID == Int32.max ? 1 : lastTimerID + 1
        } while timers[lastTimerID] != nil

        let id = lastTimerID
        let timer = Timer(
            timeInterval: Double(max(1, milliseconds)) / 1_000,
            target: timerTarget,
            selector: #selector(TimerTarget.fire(_:)),
            userInfo: NSNumber(value: id),
            repeats: repeats
        )
        timers[id] = ScheduledTimer(timer: timer, callback: callback, repeats: repeats)
        RunLoop.main.add(timer, forMode: .default)
        return id
    }

    private func fireTimer(_ timer: Timer) {
        guard let id = (timer.userInfo as? NSNumber)?.int32Value,
              let scheduled = timers[id], scheduled.timer === timer, let context else { return }

        if !scheduled.repeats {
            cancelTimer(id)
        }
        withState([:], in: context) {
            scheduled.callback.call(withArguments: [])
            reportException(in: context, source: "timer")
        }
    }

    private func cancelTimer(_ id: Int32) {
        timers.removeValue(forKey: id)?.timer.invalidate()
    }

    private func cancelTimers() {
        for scheduled in timers.values {
            scheduled.timer.invalidate()
        }
        timers.removeAll()
    }

    @discardableResult
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
