//
//  _RXDelegateProxy.m
//  RxCocoa
//
//  Created by Krunoslav Zaher on 7/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#import "_RXDelegateProxy.h"
#import "_RX.h"
#import "_RXObjCRuntime.h"

@interface _RXDelegateProxy () {
    id __weak __forwardToDelegate;
}

@property (nonatomic, strong) id strongForwardDelegate;

@end

static NSMutableDictionary *voidSelectorsPerClass = nil;

@implementation _RXDelegateProxy

+(NSSet*)collectVoidSelectorsForProtocol:(Protocol *)protocol {
    NSMutableSet *selectors = [NSMutableSet set];

    unsigned int protocolMethodCount = 0;
    struct objc_method_description *pMethods = protocol_copyMethodDescriptionList(protocol, NO, YES, &protocolMethodCount);

    for (unsigned int i = 0; i < protocolMethodCount; ++i) {
        struct objc_method_description method = pMethods[i];
        if (RX_is_method_with_description_void(method)) {
            [selectors addObject:SEL_VALUE(method.name)];
        }
    }
            
    free(pMethods);

    unsigned int numberOfBaseProtocols = 0;
    Protocol * __unsafe_unretained * pSubprotocols = protocol_copyProtocolList(protocol, &numberOfBaseProtocols);

    for (unsigned int i = 0; i < numberOfBaseProtocols; ++i) {
        [selectors unionSet:[self collectVoidSelectorsForProtocol:pSubprotocols[i]]];
    }
    
    free(pSubprotocols);

    return selectors;
}


/**
 类加载之后, 先获取该类的所有方法集合, 存起来, 后面可以用于判断该类是否能响应某一个消息~
 */
+(void)initialize {
    @synchronized (_RXDelegateProxy.class) {
        if (voidSelectorsPerClass == nil) {
            voidSelectorsPerClass = [[NSMutableDictionary alloc] init];
        }

        NSMutableSet *voidSelectors = [NSMutableSet set];

#define CLASS_HIERARCHY_MAX_DEPTH 100

        NSInteger  classHierarchyDepth = 0;
        Class      targetClass         = NULL;

        for (classHierarchyDepth = 0, targetClass = self;
             classHierarchyDepth < CLASS_HIERARCHY_MAX_DEPTH && targetClass != nil;
             ++classHierarchyDepth, targetClass = class_getSuperclass(targetClass)
        ) {
            unsigned int count;
            Protocol *__unsafe_unretained *pProtocols = class_copyProtocolList(targetClass, &count);
            
            for (unsigned int i = 0; i < count; i++) {
                NSSet *selectorsForProtocol = [self collectVoidSelectorsForProtocol:pProtocols[i]];
                [voidSelectors unionSet:selectorsForProtocol];
            }
            
            free(pProtocols);
        }

        if (classHierarchyDepth == CLASS_HIERARCHY_MAX_DEPTH) {
            NSLog(@"Detected weird class hierarchy with depth over %d. Starting with this class -> %@", CLASS_HIERARCHY_MAX_DEPTH, self);
#if DEBUG
            abort();
#endif
        }
        
        voidSelectorsPerClass[CLASS_VALUE(self)] = voidSelectors;
    }
}

-(id)_forwardToDelegate {
    return __forwardToDelegate;
}

-(BOOL)hasWiredImplementationForSelector:(SEL)selector {
    return [super respondsToSelector:selector];
}

-(BOOL)voidDelegateMethodsContain:(SEL)selector {
    @synchronized(_RXDelegateProxy.class) {
        NSSet *voidSelectors = voidSelectorsPerClass[CLASS_VALUE(self.class)];
        NSAssert(voidSelectors != nil, @"Set of allowed methods not initialized");
        return [voidSelectors containsObject:SEL_VALUE(selector)];
    }
}

/**
 这个方法被用来设置转发代理, 如果proxy没有实现对应的方法, 则会把消息转向__forwardToDelegate对象

 @param forwardToDelegate -
 @param retainDelegate 是否retain
 */
-(void)_setForwardToDelegate:(id __nullable)forwardToDelegate retainDelegate:(BOOL)retainDelegate {
    __forwardToDelegate = forwardToDelegate;
    if (retainDelegate) {
        self.strongForwardDelegate = forwardToDelegate;
    }
    else {
        self.strongForwardDelegate = nil;
    }
}

/**
 这里是runtime的知识
 1. 当发送消息给一个没有实现该Selector的对象时, 运行时会调用- (id)forwardingTargetForSelector:(SEL)aSelector, 用户可以重写该方法返回另一个要接受该消息的对象.
 2. 如果没有重写1所说的方法, 接下来runtime会调用- (void)forwardInvocation:(NSInvocation *)anInvocation, 这个时候用户可以自行修改anInvocation的内容, 比如修改参数值, 甚至可以修改selector改成其他方法,前提是其他方法的签名和anInvocation原始的方法一样(即参数返回值相同), 然后可以通过invokeWithTarget方法把anInvocation发送给其他能处理该消息的对象~
 3. 当然如果用户没有重写2所说方法,则NSObject默认的实现是调用doesNotRecognizeSelector方法,直接抛出一个异常~
 @param anInvocation 一个调用的封装
 */
-(void)forwardInvocation:(NSInvocation *)anInvocation {
    // 现在只是让proxy处理返回值为void的消息. 后面返回值不为void的消息要怎么实现, 等我再思考思考...
    BOOL isVoid = RX_is_method_signature_void(anInvocation.methodSignature);
    NSArray *arguments = nil;
    if (isVoid) {
        arguments = RX_extract_arguments(anInvocation);
        [self _sentMessage:anInvocation.selector withArguments:arguments];
    }
    
    if (self._forwardToDelegate && [self._forwardToDelegate respondsToSelector:anInvocation.selector]) {
        [anInvocation invokeWithTarget:self._forwardToDelegate];
    }

    if (isVoid) {
        [self _methodInvoked:anInvocation.selector withArguments:arguments];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [super methodSignatureForSelector:aSelector];
}

// abstract method
-(void)_sentMessage:(SEL)selector withArguments:(NSArray *)arguments {

}

// abstract method
-(void)_methodInvoked:(SEL)selector withArguments:(NSArray *)arguments {

}

-(void)dealloc {
}

@end
