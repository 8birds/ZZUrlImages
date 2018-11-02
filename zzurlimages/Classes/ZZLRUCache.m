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

#import "ZZLRUCache.h"
#import "ZZList.h"

@interface CacheObject : NSObject

@property (nonatomic) id object;
@property (nonatomic) id key;

@end
@implementation CacheObject
@end

@interface ZZLRUCache(){
    NSMutableDictionary<id, ZZListNode<CacheObject*>*>* objectNodeMap;
    ZZList<CacheObject*>* objectList; //head is most-recently used
}
@end

@implementation ZZLRUCache

-(instancetype) init{
    self = [super init];
    if(!self)
        return nil;

    objectNodeMap = [NSMutableDictionary new];
    objectList = [ZZList new];

    return self;
}

-(id) objectForKey:(id)key{
    ZZListNode<CacheObject*>* existingNode = objectNodeMap[key];
    if(!existingNode)
        return nil;

    //Move to the head of the list
    [existingNode remove];
    [objectList insertHeadNode:existingNode];

    
    CacheObject* cacheObject = objectNodeMap[key].value;
    return cacheObject.object;
}

-(void) removeObjectForKey:(id)key{
    ZZListNode* existingNode = objectNodeMap[key];
    if(existingNode){
        [existingNode remove];
        [objectNodeMap removeObjectForKey:key];
    }
}

-(void) removeOldestObject{
    ZZListNode* tail = objectList.tail;
    [tail remove];
    CacheObject* cacheObject = tail.value;
    [objectNodeMap removeObjectForKey:cacheObject.key];
}

-(void) setObject:(id)obj
           forKey:(nonnull id)key
{
    [self removeObjectForKey:key];

    CacheObject* cacheObject = [CacheObject new];
    cacheObject.object = obj;
    cacheObject.key = key;

    ZZListNode* node = [objectList insertHead:cacheObject];
    objectNodeMap[key] = node;

    while(objectList.count > _cacheObjectLimit)
        [self removeOldestObject];
}

-(void) removeAllObjects{
    [objectNodeMap removeAllObjects];
    [objectList removeAllObjects];
}

-(void) reduceObjectCountBy:(double)ratio{
    NSUInteger targetElementCount = (NSUInteger)(objectList.count * ratio);

    while(objectList.count > targetElementCount)
        [self removeOldestObject];
}

@end
