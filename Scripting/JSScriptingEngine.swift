//
//  JSScriptingEngine.swift
//  Atlantis
//
//  Created by Jim Cheng on 12/3/25.
//
import Foundation

@objc(JSScriptingEngine)
public class JSScriptingEngine: ScriptingEngine {
    
    override init() {
        super.init()
        print("init")
    }
    
    public override func scriptEngineName() -> String {
        return "JavaScript"
    }
    
    
    
    public override func executeFunction(_ fn:String, with state:AtlantisState) -> Any {
        let test = "JSScriptingEngine::executeFunction \(fn)"
        print("---")
        print(test)
        print(state)
        print("...")
        
        return true
    }
}
