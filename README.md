# 文档更新说明
* 最后更新 2019年04月01日
* 首次更新 2019年04月01日

# 前言
　　学习RxSwift的时候, 看到一个比较强大的功能, 动态代理. 简单说就是RxSwift对每一个NSObject及其子类都扩展了rx属性, 用户可以用过编写代码来在rx上直接扩展出方法, 用来实现响应式代理功能. 下面举个例子:

```swift
import UIKit
import RxSwift
import RxCocoa
import CoreLocation

extension CLLocationManager: HasDelegate {
    public typealias Delegate = CLLocationManagerDelegate
}

class CLLocationManagerDelegateProxy:DelegateProxy<CLLocationManager, CLLocationManagerDelegate>, DelegateProxyType, CLLocationManagerDelegate {
    weak private(set) var locationManager: CLLocationManager?
    
    init(locationManager: ParentObject) {
        self.locationManager = locationManager
        super.init(parentObject: locationManager, delegateProxy: CLLocationManagerDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register {
            CLLocationManagerDelegateProxy(locationManager: $0)
        }
    }
}

extension Reactive where Base: CLLocationManager {
    var delegate: CLLocationManagerDelegateProxy {
        return CLLocationManagerDelegateProxy.proxy(for: base)
    }
    
    var didUpdateLocations: Observable<[CLLocation]> {
        let sel = #selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:))
        
        return delegate.methodInvoked(sel).map {
            parameters in parameters[1] as! [CLLocation]
        }
    }
}

// 使用方法
class RootViewController: UIViewController {
	private func requestLocation() {
        self.locationManager.startUpdatingLocation()
            self.locationManager.rx.didUpdateLocations.take(1).subscribe(onNext: {
                print("update location")
                self.currentLocation = $0.first
            }).disposed(by: bag)
        //等价于self.locationManager.delegate = self, 然后在RootViewController里实现CLLocationManagerDelegate协议的didUpdateLocations方法
    }
}

```
通过上面的代码我们可以扩展CLLocationManager类, 让每一个CLLocationManager对象都能直接使用didUpdateLocations方法获取到对应的Observable, 这样一旦CLLocationManager对象要调用didUpdateLocations方法时, 对应的就会把值传到Observable里. 咋一看, 哎呀这个模式挺好的, 可以一行代码就实现代理功能了,不再需要修改自己的类然后实现对应的协议方法, 再设置给CLLocationManager.delegate. 
　　我对这个功能挺感兴趣的, 因此要想它底层原理弄明白, 所以就有了FlatCocoa这个库, 大部分灵感(其实是Code)来自RxSwfit和RxCocoa, FlatCocoa本意就是扁平化Cocoa, 很形象的意思, 不过他可能更适合叫FlatDelegate吧, 呵呵最在乎呢. 下面我会通过FlatCocoa的代码, 来详细分析上述强大功能的实现原理.
　　还想再说一句, Swift真的是一门及其复杂的语言, 光是泛化编程(模板编程)的语法就十分复杂, 这块一时半会我也记不住, 只能边看边学了.

# FlatCocoa的UML
　　其实整体的代码结构还是挺复杂的, 所以我用了UML的Class Diagram和Sequence Diagram来简化这个描述, 可能有些地方使用的不规范, 我会尽量改进.

## Class Diagram
![class_diagram](https://raw.githubusercontent.com/cocos543/FlatCocoa/master/FlatCocoa/FlatCocoa/Doc/class%20diagram.png)

## Sequence Diagram

### 动态创建代理
![get delegate](https://raw.githubusercontent.com/cocos543/FlatCocoa/master/FlatCocoa/FlatCocoa/Doc/get%20delegate.png)

### 消息转发
![mesaage forward](https://raw.githubusercontent.com/cocos543/FlatCocoa/master/FlatCocoa/FlatCocoa/Doc/message%20forward.png)

### 用户代码注入
![invoked](https://raw.githubusercontent.com/cocos543/FlatCocoa/master/FlatCocoa/FlatCocoa/Doc/message%20invoked.png)

# 实现原理
　　这里简述一下实现原理, 相关详细原理我已经用注释的形式放到代码里面了. 首先从类图里我们可以看到为所有NSObject及其子类扩展出flat属性的原理, 就是让NSObject实现FlatCompatible协议, 然后我们在给协议添加一个默认的实现, 这样就可以访问到flat已经falt下定义的方法了.
  
　　接着我们采用工厂模式, 利用一个比较工厂来动态创建我们的proxy实例, 接着向proxy实例注入我们要代理的方法逻辑(Closure).
  
　　最后, 被代理的对象一旦有消息发出时, 我们让消息转发到proxy对象里, proxy对象负责处理消息, 它可能是调用上一步注入的Closure, 或者调用被代理对象原始的delegate.

# 缺陷
　　通过代码我们可以发现, 目前FlatCocoa只能动态代理那些返回值为Void的方法, 这是因为在RxSwift里也是如此, 我暂时还没有想到一个好方法来处理返回值不为Void的方案, 比如可能可以用数组? 容我再思考思考.

# 未来
　　当前的FlatCocoa更多的是作为一个源码分析例子去深入了解RxSwift的动态代理实现原理, 所以FlatCocoa的源码我只提供了对UITableViewDelegate.tableView(_:didHighlightRowAt:)方法的Flat化, 其他代码其实格式一样. 还有就是目前不支持返回值不为Void的协议方法, 这个我再想想~
　　完.😄️
