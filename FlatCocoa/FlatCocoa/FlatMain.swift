//
//  FlatMain.swift
//  FlatCocoa
//
//  Created by Cocos on 2019/3/19.
//  Copyright © 2019年 Cocos. All rights reserved.
//

import Foundation

@objc public class FlatMain: NSObject {
    
    @objc public func sayHello(){
        print("Flat-->: hello")
    }
}


public struct Flat<Base> {
    /// Base object to extend.
    public let base: Base
    
    /// Creates extensions with base object.
    ///
    /// - parameter base: Base object.
    public init(_ base: Base) {
        self.base = base
    }
}

/// A type that has Flat extensions.
public protocol FlatCompatible {
    /// Extended type
    associatedtype CompatibleType
    
    /// Flat extensions.
    static var flat: Flat<CompatibleType>.Type { get set }
    
    /// Flat extensions.
    var flat: Flat<CompatibleType> { get set }
}

extension FlatCompatible {
    /// Flat extensions.
    public static var flat: Flat<Self>.Type {
        get {
            return Flat<Self>.self
        }
        set {
            // this enables using Flat to "mutate" base type
        }
    }
    
    /// Flat extensions.
    public var flat: Flat<Self> {
        get {
            return Flat(self)
        }
        set {
            // this enables using Flat to "mutate" base object
        }
    }
}

//向NSObject及其派生类注入falt命名空间
extension NSObject: FlatCompatible { }
