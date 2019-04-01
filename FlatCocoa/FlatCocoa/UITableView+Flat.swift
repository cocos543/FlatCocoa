//
//  UITableView+Flat.swift
//  FlatCocoa
//
//  Created by Cocos on 2019/3/28.
//  Copyright © 2019 Cocos. All rights reserved.
//

import Foundation


extension UITableView: HasDelegate {
    public typealias Delegate = UITableViewDelegate
}


/// 这里需要介绍一下TestDelegateProxy的继承关系.
//  1.TestDelegateProxy会被直接当作UITableView的delegate, 所以必须声明实现UITableViewDelegate.
//  2.TestDelegateProxy继承DelegateProxy, 而DelegateProxy实现了部分DelegateProxyType的方法, 这样做的好处是TestDelegateProxy能更方便实现DelegateProxyType协议
class UITableViewDelegateProxy: DelegateProxy<UITableView, UITableViewDelegate>, DelegateProxyType, UITableViewDelegate {
    typealias ParentObject = UITableView
    typealias Delegate = UITableViewDelegate
    
    weak private(set) var tableview: UITableView?
    
    init(tableView: UITableView) {
        tableview = tableView
        super.init(parentObject: tableView, delegateProxy: UITableViewDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register{UITableViewDelegateProxy(tableView: $0)}
    }
}

//这里对Falt类进行扩展, 扩展的方法会被添加到所有NSObject及其派生类中
extension Flat where Base: UITableView {
    var delegate: UITableViewDelegateProxy {
        return UITableViewDelegateProxy.proxy(for: base)
    }
    
    func didHighlightRow(_ aClosure: @escaping ((IndexPath) -> Void)) {
        let sel = #selector(UITableViewDelegate.tableView(_:didHighlightRowAt:))
        
        let tClosure = { (arguments: [Any]) -> Void in
            aClosure(arguments[1] as! IndexPath)
        }
        
        delegate.methodInvoked(sel, aClosure: tClosure)
    }
    
    
    /// UITableViewDelegate协议的其他Void返回值的方法, 都可以按照上面格式写一遍.
    // Code here.....
    //
}
