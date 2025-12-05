//
//  WrappedLuaScriptingEngine.swift
//  Atlantis
//
//  Created by Jim Cheng on 12/4/25.
//

import Foundation

@objc(WrappedLuaScriptingEngine)
public class WrappedLuaScriptingEngine: LuaScriptingEngine {
    
    override init() {
        super.init()
        print("WL init")
    }
    
    public override func scriptEngineName() -> String? {
        let result = super.scriptEngineName()
        print("WL scriptEngineName \(String(describing: result))")
        return result
    }
    
}
