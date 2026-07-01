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
    
    var context:JSContext?
    
    override init() {
        super.init()
        print("JS init")
        self.engineReinit(AtlantisState())
    }
    
    deinit {
        
    }
    
    public override func engineReinit(_ state: AtlantisState) {
        
        print("enginereinit");
        
        if context == nil {
            context = JSContext();
            print("Created JS context")
            
            // MARK: - Debug Console

            // Inject the function into the JavaScript global scope
            context?.setObject(jsConsolePrint, forKeyedSubscript: "jsConsolePrint" as NSString)
            
            context?.exceptionHandler = { context, exception in
                if let exc = exception {
                    print("JavaScript Error: \(exc.toString() ?? "Unknown error")")
                }
            }
            
            context?.evaluateScript("""
                var console = {
                    log: function() {
                        var args = Array.prototype.slice.call(arguments);
                            jsConsolePrint(args.map(function(arg) {
                            return typeof arg === 'object' ? JSON.stringify(arg) : String(arg);
                        }).join(' '));
                    },
                    warn: function() { console.log('[WARN]', arguments); },
                    error: function() { console.log('[ERROR]', arguments); }
                };
                """)
            
            context?.evaluateScript("console.log('test!');")
        }
    }
    
    
    public override func scriptEngineName() -> String {
        return "JavaScript"
    }
    
    public override func executeFunction(_ fn:String, with state:AtlantisState) -> Any {
        print("JSScriptingEngine::executeFunction \(fn)");
        print("---")
        context?.evaluateScript(fn);
        print("---")
        
        return true
    }
    
    
    let jsConsolePrint: @convention(block) (String) -> Void = { message in
        print(message)
    }
    
}



