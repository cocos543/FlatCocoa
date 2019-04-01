//
//  DelegateProxy.swift
//  FlatCocoa
//
//  Inspired by RxCocoa
//
//  Created by Cocos on 2019/3/20.
//  Copyright © 2019年 Cocos. All rights reserved.
//

import Foundation



/// HasDelegate
// 所有遵循HasDelegate协议的类, 都必须拥有一个delegate属性, 类型就是associatedtype声明的类型. 这样才能在DelegateProxy被安全使用.
public protocol HasDelegate: AnyObject {
    // 要代理的类型
    associatedtype Delegate
    
    var delegate: Delegate? { get set }
}


/// DelegateProxyType
// 定义一些代理的代理的行为规范, 实现了DelegateProxyType协议的类的对象proxy, 会被当做相关Controller的真实代理, 然后再由proxy把具体的方法转发到用户注册的代码里.
public protocol DelegateProxyType: AnyObject {
    associatedtype ParentObject: AnyObject
    associatedtype Delegate
    
    // Proxy子类可以实现这个方法, 向框架注册"Proxy实例化代码", 这样框架就能通过工厂模式实例化Proxy实例了
    static func registerKnownImplementations()
    
    // identifier 为每一个Delegate类型生成一个独一无二的指针, 可以用来作为工厂类型池(Dictionary)里面的key~
    static var identifier: UnsafeRawPointer { get }
    
    // 传入一个拥有delegate属性的对象, 返回这个对象的delegate
    static func currentDelegate(for object: ParentObject) -> Delegate?
    static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject)
    
    
    /// 下面两个方法没有默认实现.
    //
    // 如果实现了DelegateProxyType的类没有声明具体要代理的方法, 当消息到来时, 默认会把消息转发给下面保存的forwardToDelegate.
    // 举个例子, 我们现在有一个实现了DelegateProxyType协议的类UITableViewDelegateProxy, 被设计来取代UITableViewDelegate
    // 然后我们在UITableViewDelegateProxy中编写了相关注册代码, 比如注册要代理tableView(UITableView, didSelectRowAt: IndexPath), 这样didSelectRowAt方法触发的时候就会调用到UITableViewDelegateProxy里, 但是其他UITableViewDelegate的方法,比如tableView(UITableView, didDeselectRowAt: IndexPath), 则还是会转发到下面设置的delegate中~ (这里不管有没有注册方法, 只要存在有能力的forwardToDelegate, 消息最后都会发过去)
    func forwardToDelegate() -> Delegate?
    
    func setForwardToDelegate(_ forwardToDelegate: Delegate?, retainDelegate: Bool)
}



// MARK: - 协议的默认实现
extension DelegateProxyType {
    public static var identifier: UnsafeRawPointer {
        let delegateIdentifier = ObjectIdentifier(Delegate.self)
        let integerIdentifier = Int(bitPattern: delegateIdentifier)
        return UnsafeRawPointer(bitPattern: integerIdentifier)!
    }
}

// 如果ParentObject遵循HasDelegate协议的话, 我们可以直接返回object.delegate, 所以这里做一个默认实现
extension DelegateProxyType where ParentObject: HasDelegate, Self.Delegate == ParentObject.Delegate {
    
    public static func currentDelegate(for object: ParentObject) -> Delegate? {
        let d = object.delegate!
        return d
    }
    
    ///   - object: 注意上面HasDelegate协议必须限定为AnyObject, 因为非引用类型无法在这个方法里修改object对象的属性
    public static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject) {
        object.delegate = delegate
    }
}

// workaround of Delegate: class
extension DelegateProxyType {
    static func _currentDelegate(for object: ParentObject) -> AnyObject? {
        return currentDelegate(for: object).map { $0 as AnyObject }
    }
    
    static func _setCurrentDelegate(_ delegate: AnyObject?, to object: ParentObject) {
        return setCurrentDelegate(delegate as? Delegate, to: object)
    }
    
    func _forwardToDelegate() -> AnyObject? {
        return self.forwardToDelegate().map { $0 as AnyObject }
    }
    
    func _setForwardToDelegate(_ forwardToDelegate: AnyObject?, retainDelegate: Bool) {
        return self.setForwardToDelegate(forwardToDelegate as? Delegate, retainDelegate: retainDelegate)
    }
}



// MARK: - 相关工厂方法
extension DelegateProxyType {
    // 用户可以调用该方法向框架注册初始化DelegateProxy实例的代码
    public static func register<Parent>(make: @escaping (Parent) -> Self ) {
        self.factory.extend(make: make)
    }
    
    /// Should not call this function directory, use 'DelegateProxy.proxy(for:)'
    // 上面这句话是RxCocoa里的原话, 创建proxy实例应该使用下面的proxy方法, 该方法同时对同一个object实例创建proxy做了缓存, 增强性能
    public static func createProxy(for object: AnyObject) -> Self {
        return self.factory.createProxy(for: object) as! Self
    }
    
    public static func proxy(for object: ParentObject) -> Self {
        // 如果object已经创建过proxy,则直接从缓存中获取
        let maybeProxy = self.assignedProxy(for: object)
        let proxy: AnyObject
        if let existingProxy = maybeProxy {
            proxy = existingProxy
        }else {
            proxy = self.createProxy(for: object)
            self.assignProxy(proxy, toObject: object)
            assert(self.assignedProxy(for: object) === proxy)
        }
        
        // 如果object已经自带delegate实例, 则把它存进delegateProxy作为forwardToDelegate, 确保相关消息还是会转发给原来的delegate
        let currentDelegate = self._currentDelegate(for: object)
        let delegateProxy = proxy as! Self
        
        if delegateProxy !== currentDelegate {
            // 设置proxy的转发代理
            delegateProxy._setForwardToDelegate(currentDelegate, retainDelegate: false)
            assert(delegateProxy._forwardToDelegate() === currentDelegate)
            
            // 把proxy设置为object实例的真正代理
            self._setCurrentDelegate(proxy, to: object)
            assert(self._currentDelegate(for: object) === proxy)
            assert(delegateProxy._forwardToDelegate() === currentDelegate)
        }
        return delegateProxy
    }
}


extension DelegateProxyType {
    fileprivate static var factory: DelegateProxyFactory {
        return DelegateProxyFactory.sharedFactory(for: self)
    }
    
    // 下面两个方法, 被用来缓存和获取已经创建出来的proxy实例.
    fileprivate static func assignedProxy(for object: ParentObject) -> AnyObject? {
        let maybeDelegate = objc_getAssociatedObject(object, self.identifier)
        return maybeDelegate as AnyObject?
    }
    
    fileprivate static func assignProxy(_ proxy: AnyObject, toObject object: ParentObject) {
        objc_setAssociatedObject(object, self.identifier, proxy, .OBJC_ASSOCIATION_RETAIN)
    }
}


// 私有的工厂类
private class DelegateProxyFactory {
    
    // 这个有点强大了. 这个工厂可以存储多个"工厂"实例, 他们被用来创建"实现了不同DelegateProxyType协议的类"的实例
    private static var _sharedFactories: [UnsafeRawPointer: DelegateProxyFactory] = [:]
    
    // 单例, 用于获取DelegateProxyFactory的实例
    // 这里如果没有使用泛型, 直接定义方法的for参数为proxyType: DelegateProxyType.Type时, 编译器会报错如下:
    // Protocol 'DelegateProxyType' can only be used as a generic constraint because it has Self or associated type requirements
    // 具体原因可以看这里 https://stackoverflow.com/questions/36348061/protocol-can-only-be-used-as-a-generic-constraint-because-it-has-self-or-associa
    // 解决方案  https://www.hackingwithswift.com/example-code/language/how-to-fix-the-error-protocol-can-only-be-used-as-a-generic-constraint-because-it-has-self-or-associated-type-requirements
    fileprivate static func sharedFactory<DelegateProxy: DelegateProxyType>(for proxyType: DelegateProxy.Type) -> DelegateProxyFactory {
        let identifier = DelegateProxy.identifier
        
        // 下面代码都比较简单, 如果工厂实例存在则直接获取返回, 否则就创建并且缓冲起来
        if let factory = _sharedFactories[identifier] {
            return factory
        }
        
        let factory = DelegateProxyFactory(for: proxyType)
        _sharedFactories[identifier] = factory
        
        // 同个"类型工厂"只会创建一次, 所以这个注册的方法也最多被调用一次
        DelegateProxy.registerKnownImplementations()
        
        return factory
    }
    
    
    // DelegateProxyType协议本身就是带有associatedtype的泛型协议.实现了DelegateProxyType的类,本身的职责就是设计来代理各种各种的ParentObject,
    // 所以这里还需要一个Dictonary存储这些不同目的DelegateProxy类的初始化代码块.
    private var _factories: [ObjectIdentifier: ((AnyObject) -> AnyObject)]
    private var _delegateProxyType: Any.Type
    private var _identifier: UnsafeRawPointer
    
    private init<DelegateProxy: DelegateProxyType>(for proxyType: DelegateProxy.Type) {
        self._factories = [:]
        self._delegateProxyType = proxyType
        self._identifier = proxyType.identifier
    }
    
    fileprivate func extend<DelegateProxy: DelegateProxyType, ParentObject>(make: @escaping (ParentObject) -> DelegateProxy) {
        // 这句代码看似可有可无
        precondition(self._identifier == DelegateProxy.identifier, "Delegate proxy has inconsistent identifier")
        
        guard self._factories[ObjectIdentifier(ParentObject.self)] == nil else {
            fatalError("The factory of \(ParentObject.self) is duplicated. DelegateProxy is not allowed of duplicated base object type.")
        }
        
        self._factories[ObjectIdentifier(ParentObject.self)] = { obj in
            // 因为obj类型是AnyObject, 所以我们要把它转成ParentObject类型, 才能调用make闭包
            let maybeResult: ParentObject? = obj as? ParentObject
            guard let result = maybeResult else {
                fatalError("Failure converting")
            }
            return make(result)
        }
    }
    
    // 通过exten注册的实例化object的代码, 在此处会被执行, 并创建出proxy对象
    // 这里为什么要用Mirror反射, 暂时不清楚, 感觉可以直接用类型
    fileprivate func createProxy(for object: AnyObject) -> AnyObject {
        var maybeMirror: Mirror? = Mirror(reflecting: object)
        while let mirror = maybeMirror {
            if let factory = self._factories[ObjectIdentifier(mirror.subjectType)] {
                return factory(object)
            }
            maybeMirror = mirror.superclassMirror
        }
        fatalError("DelegateProxy has no factory of \(object). Implement DelegateProxy subclass for \(object) first.")
    }
}


/// 如果value为nil, 则返回nil. 否则value转换成类型T, 如果无法转换成T类型则报错.
///
/// - Parameter value: -
/// - Returns: 根据调用方推断出具体类型
func castOptionalOrFatalError<T>(_ value: Any?) -> T? {
    if value == nil {
        return nil
    }
    let v: T = castOrFatalError(value)
    return v
}

func castOrFatalError<T>(_ value: Any!) -> T {
    let maybeResult: T? = value as? T
    guard let result = maybeResult else {
        fatalError("Failure converting from \(String(describing: value)) to \(T.self)")
    }
    
    return result
}
