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

#import "ZZList.h"

@interface ZZListNode()
-(void) setParent:(ZZList*)parent;
@end

#pragma mark ZZList methods
@implementation ZZList

-(void) removeAllObjects{
    ZZListNode* next = _head;

    while(next){
        [next remove];
        next = next.next;
    }
}

-(void) insertTailNode:(ZZListNode*)newNode{
    if(!newNode)
        return;

    if(_tail)
        [_tail insertNodeAfter:newNode];
    else{
        _head = newNode;
        _tail = newNode;
        [newNode setParent:self];
        _count = 1;
    }

    _tail = newNode;
}

-(ZZListNode*) insertTail:(id)obj{
    ZZListNode* newNode = [ZZListNode new];
    newNode.value = obj;

    [self insertTailNode:newNode];

    return newNode;
}

-(void) insertHeadNode:(ZZListNode*)newNode{
    if(!newNode)
        return;

    if(_head)
        [_head insertNodeBefore:newNode];
    else{
        _head = newNode;
        _tail = newNode;
        _count = 1;
        [newNode setParent:self];
    }

    _head = newNode;
}

-(ZZListNode*) insertHead:(id)obj{
    ZZListNode* newNode = [ZZListNode new];
    newNode.value = obj;

    [self insertHeadNode:newNode];

    return newNode;
}

-(void) removeHead{
    if(!_head)
        return;

    ZZListNode* oldNext = _head.next;
    [_head remove];
    _head = oldNext;
}

-(void) removeTail{
    if(!_tail)
        return;

    ZZListNode* oldPrev;
    [_tail remove];
    _tail = oldPrev;
    _count--;
}

-(void) incrementCount{
    _count++;
}

-(void) decrementCount{
    _count--;
}

-(void) setHead:(ZZListNode*)node{
    _head = node;
}

-(void) setTail:(ZZListNode*)tail{
    _tail = tail;
}

@end


#pragma mark ZZListNode methods
@implementation ZZListNode

-(instancetype) initWithParent:(ZZList *)parent{
    self = [super init];
    if(!self)
        return nil;

    _parent = parent;

    return self;
}

-(void) setNext:(id)next{
    _next = next;
}

-(void) setPrev:(id)prev{
    _prev = prev;
}

-(ZZListNode*) insertAfter:(id)obj{
    ZZListNode* insertedNode = [ZZListNode new];
    insertedNode.value = obj;

    [self insertNodeAfter:insertedNode];

    return insertedNode;
}

-(void) insertNodeAfter:(ZZListNode *)insertedNode{
    // self -> oldNext becomes self -> insertedNode -> oldNext
    [insertedNode remove];
    [insertedNode setParent:_parent];

    ZZListNode* oldNext = _next;

    _next = insertedNode;
    [insertedNode setPrev:self];

    [insertedNode setNext:oldNext];
    if(oldNext)
        [oldNext setPrev:insertedNode];


    //update parent
    ZZList* parent = _parent;
    if(!parent)
        return;

    [parent incrementCount];

    if(!insertedNode.prev)
        [parent setHead:insertedNode];

    if(!insertedNode.next)
        [parent setTail:insertedNode];
}

-(ZZListNode*) insertBefore:(id)obj{
    ZZListNode* insertedNode = [ZZListNode new];
    insertedNode.value = obj;
    [self insertNodeBefore:insertedNode];

    return insertedNode;
}

-(void) setParent:(ZZList*)list{
    _parent = list;
}

-(void) insertNodeBefore:(ZZListNode *)insertedNode{
    [insertedNode remove];
    [insertedNode setParent:_parent];

    ZZListNode* oldPrev = _prev;

    _prev = insertedNode;
    [insertedNode setNext:self];

    [insertedNode setPrev:oldPrev];
    if(oldPrev)
        [oldPrev setNext:insertedNode];


    //update parent
    ZZList* parent = _parent;
    if(!parent)
        return;

    [parent incrementCount];

    if(!insertedNode.prev)
        [parent setHead:insertedNode];

    if(!insertedNode.next)
        [parent setTail:insertedNode];
}

-(void) remove{
    //update parent list's count, and head/tail if necessary.
    ZZList* parent = _parent;
    if(parent){
        [parent decrementCount];

        if(!_prev)
            [parent setHead:_next];

        if(!_next)
            [parent setTail:_prev];
    }

    //remove from list
    if(_prev)
        [_prev setNext:_next];

    if(_next)
        [_next setPrev:_prev];

    _parent = nil;
    _next = nil;
    _prev = nil;
}

@end
