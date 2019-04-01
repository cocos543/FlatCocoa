//
//  TestClass.swift
//  FlatCocoaTests
//
//  Created by Cocos on 2019/3/21.
//  Copyright © 2019年 Cocos. All rights reserved.
//

import XCTest
@testable import FlatCocoa


class TestDelegateProxyType: XCTestCase {
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func test_Delegate_Identifier() {
        XCTAssertNotNil(UITableViewDelegateProxy.identifier)
    }
    
    func test_Delegate_Register() {
        let tv = UITableView(frame: CGRect.zero, style: UITableView.Style.plain)
        _ = UITableViewDelegateProxy.proxy(for: tv)
        
        let proxy = UITableViewDelegateProxy.proxy(for: tv)

        XCTAssertNotNil(proxy)
    }
    
   
    
    func test_DelegateProxy_MethodInvoked() {
        class TestTableViewDelegate: NSObject, UITableViewDelegate {
            // 如果代理自身有实现某个方法的, 是可以被执行到
            func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                XCTAssert(indexPath.row == indexPath.section && indexPath.row == 1)
            }
        }
        
        let tv = UITableView(frame: CGRect.zero, style: UITableView.Style.plain)
        let tvd = TestTableViewDelegate()
        tv.delegate = tvd
        
        let index = IndexPath(row: 1, section: 1)
        
        // Flat动态创建的代理能够处理tvd没有实现的功能
        tv.flat.didHighlightRow { (indexPath) in
            XCTAssert(index == indexPath)
        }
        
        tv.delegate?.tableView?(tv, didHighlightRowAt: index)
        tv.delegate?.tableView?(tv, didSelectRowAt: IndexPath(row: 1, section: 1))
        
    }
    
}
