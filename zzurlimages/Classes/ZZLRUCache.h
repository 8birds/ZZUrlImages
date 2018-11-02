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

#define kZZLRUCache_NoLimit ((NSInteger)-1)



/**
 * A least-recently-used object cache.
 * When cacheObjectLimit is exceeded, the oldest objects are removed.
 */
@interface ZZLRUCache<__covariant T> : NSObject



/**
 * Limits the number of objects in the cache.
 * The default is no-limit (kZZLRUCache_NoLimit).
 *
 * This property may be set after the cache has been used.
 * The oldest objects will be trimmed from the cache as needed when lowering
 * this property.
 */
@property (nonatomic) NSInteger cacheObjectLimit;

/**
 * Retrieve an object from the cache if present.
 *
 * @param key A value previously used in setObject:forKey:.
 */
-(T) objectForKey:(id)key;

/**
 * Cache an object for later use.
 *
 * @param object Object to cache
 * @param key Any object that can be used as a key in a dictionary.
 */
-(void) setObject:(nonnull T)object
           forKey:(nonnull id)key;

-(void) removeObjectForKey:(id)key;

/**
 * Removes all objects from the cache.
 */
-(void) removeAllObjects;

/**
 * Removes objects from the cache.
 * @param ratio The ratio of objects to remove. 0 for none, 1 for all.
 *              The ratio represents the object count, not the memory consumed.
 */
-(void) reduceObjectCountBy:(double)ratio;

@end

NS_ASSUME_NONNULL_END
