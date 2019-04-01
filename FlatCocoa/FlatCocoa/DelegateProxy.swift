//
//  DelegateProxy.swift
//  FlatCocoa
//
//  Created by Cocos on 2019/3/21.
//  Copyright © 2019年 Cocos. All rights reserved.
//

import Foundation


/// DelegateProxy实现了DelegateProxyType协议的部分方法, 但是并没有遵循DelegateProxyType协议.
// 这样做的好处是他的派生类默认也拥有DelegateProxyType方法的实现, 派生类可以更容易被设计出来
// 注意, 这里需要为open访问控制, 因为其他模块需要继承该类
open class DelegateProxy<P: AnyObject, D>: _RXDelegateProxy {
    public typealias ParentObject = P
    public typealias Delegate = D
    
    private var _sentMessageForSelector = [Selector: (([Any]) -> Void)]()
    private var _methodInvokedForSelector = [Selector: (([Any]) -> Void)]()
    
    /// Parent object associated with delegate proxy.
    private weak var _parentObject: ParentObject?
    
    fileprivate let _currentDelegateFor: (ParentObject) -> AnyObject?
    fileprivate let _setCurrentDelegateTo: (AnyObject?, ParentObject) -> Void
    
    /// 这里的泛型语法真的是非常不容易理解.实话说Swift这门语言实在是太复杂了.....
    // 1. 首先还是和之前说过的一样, 带有泛型的协议, 是不能直接被用在方法签名的. 只能让这个协议作为一个约束去约束一个泛型
    public init<Proxy: DelegateProxyType>(parentObject: ParentObject, delegateProxy: Proxy.Type) where Proxy: DelegateProxy<ParentObject, Delegate>, Proxy.ParentObject == ParentObject, Proxy.Delegate == Delegate {
        self._parentObject = parentObject
        self._currentDelegateFor = delegateProxy._currentDelegate
        self._setCurrentDelegateTo = delegateProxy._setCurrentDelegate
        
        super.init()
    }
    
    private func hasHandler(selector: Selector) -> Bool {
        return self._sentMessageForSelector[selector] != nil || self._methodInvokedForSelector[selector] != nil
    }
    
    
    /// object要调用代理的方法前都会先调用代理的respondsTo方法, 确保代理已经实现对应方法, 所以我们需要重写respondsTo方法, 按照我们自己的规则来响应
    /// 当respondsTo返回true, 但是proxy没有实现对应方法时, proxy的forwardInvocation会被调用, 刚好可以用来执行我们的"注入代码"
    /// - Parameter aSelector: -
    /// - Returns: -
    override open func responds(to aSelector: Selector!) -> Bool {
        return super.responds(to: aSelector) || self._forwardToDelegate?.responds(to: aSelector) ?? false ||
            (self.voidDelegateMethodsContain(aSelector) && self.hasHandler(selector: aSelector))
    }
    
    open func forwardToDelegate() -> D? {
        return castOptionalOrFatalError(_forwardToDelegate)
    }
    
    open func setForwardToDelegate(_ forwardToDelegate: D?, retainDelegate: Bool) {
        self._setForwardToDelegate(forwardToDelegate, retainDelegate: retainDelegate)
    }
    
    // 向proxy实例注入闭包代码
    open func methodInvoked(_ selector: Selector, aClosure: @escaping (([Any]) -> Void)) {
        self._methodInvokedForSelector[selector] = aClosure
    }
    
    // proxy
    // 当object向代理发送消息时, 如果proxy有注入对应的selector, 则会转发到_methodInvoked方法里, 在这里可以直接调用之前注入的闭包, 直接执行代码.
    // 当前, 这里目前只能支持Void返回值的selector. 其他非Void的selector得研究一下实现方案.
    open override func _sentMessage(_ selector: Selector, withArguments arguments: [Any]) {
        self._sentMessageForSelector[selector]?(arguments)
    }
    
    open override func _methodInvoked(_ selector: Selector, withArguments arguments: [Any]) {
        self._methodInvokedForSelector[selector]?(arguments)
    }
    
    
}
