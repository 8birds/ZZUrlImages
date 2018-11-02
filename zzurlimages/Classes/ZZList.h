/*
 * Copyright 2018 8 Birds Video Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZZList<__covariant T>;


@interface ZZListNode<__covariant T> : NSObject

@property (nonatomic) T value;
@property (nonatomic, readonly) ZZListNode<T>* next;

/**
 * prev property is weak because prev holds a strong reference to us.
 * When prev is null, it is the head in the ZZList, which is a strong reference.
 */
@property (nonatomic, readonly, weak) ZZListNode<T>* prev;

@property (nonatomic, readonly, weak) ZZList<T>* parent;

/**
 * Inserts a new element after this node.
 * Returns the new list node containing this element.
 */
-(ZZListNode<T>*) insertAfter:(T)obj;

/**
 * Places an existing node after this node.
 *
 * If node.parent does not match self.parent, an exception will be raised.
 */
-(void) insertNodeAfter:(ZZListNode<T>*)node;

/**
 * Inserts a new element before this node.
 * Returns the new list node containing this element.
 */
-(ZZListNode<T>*) insertBefore:(T)obj;

/**
 * Places an existing node before this node.
 *
 * If node.parent does not match self.parent, an exception will be raised.
 */
-(void) insertNodeBefore:(ZZListNode<T>*)node;

/**
 * Removes this element from the list. Once removed, this object's parent
 * is nil.
 */
-(void) remove;

@end


/**
 * Doubly-linked list.
 * When empty, both head and tail are nil.
 * When non-empty, both head and tail are non-nil.
 */
@interface ZZList<__covariant T> : NSObject

@property (readonly, nonatomic) ZZListNode<T>* head;
@property (readonly, nonatomic) ZZListNode<T>* tail;
@property (readonly, nonatomic) NSUInteger count;

-(void) insertHeadNode:(ZZListNode*)node;
-(ZZListNode<T>*) insertHead:(T)obj;

-(void) insertTailNode:(ZZListNode<T>*)node;
-(ZZListNode<T>*) insertTail:(T)obj;

-(void) removeAllObjects;

@end

NS_ASSUME_NONNULL_END
