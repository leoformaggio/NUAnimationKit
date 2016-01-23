//
//  NUCompositeAnimation.m
//  NUAnimationKit
//
//  Created by Victor Maraccini on 1/22/16.
//  Copyright © 2016 Victor Gabriel Maraccini. All rights reserved.
//

#import "NUCompositeAnimation.h"

@interface NUCompositeAnimation ()

@property (nonatomic, strong) NUProgressAnimationBlock progressBlock;

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, readwrite) CFTimeInterval lastTimestamp;

@property (nonatomic, readwrite) CGFloat progress;
@property (nonatomic, readwrite) CGFloat totalAnimationDuration;

@end

@implementation NUCompositeAnimation

+ (instancetype) animationBlockWithType: (NUAnimationType)type
                             andOptions: (NUAnimationOptions *)options
                               andDelay: (NSTimeInterval)delay
                          andAnimations: (NUSimpleAnimationBlock)animations
                     andCompletionBlock: (NUCompletionBlock)completionBlock
                         inParallelWith:(NUBaseAnimation *)parallelBlock
                       animateAlongside: (NUProgressAnimationBlock)progressBlock {
    
    NUCompositeAnimation *result = [[NUCompositeAnimation alloc] init];
    if (result) {
        result.type = type;
        result.options = options;
        result.delay = delay;
        result.animationBlock = animations;
        result.completionBlock = [completionBlock copy];
        result.parallelBlock = [parallelBlock copy];
        result.progressBlock = [progressBlock copy];
    }
    return result;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self
                                                   selector:@selector(updateAnimationProgress)];
        self.completionBlock = nil;
    }
    return self;
}

#pragma mark - Extension methods

- (void)animationWillBegin {
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSDefaultRunLoopMode];
}

- (void)setCompletionBlock:(NUCompletionBlock)completionBlock {
    __weak typeof(self) weakself = self;
    super.completionBlock = ^() {
        __strong typeof(self) self = weakself;
        [self cleanUp];
        
        if (completionBlock) {
            completionBlock();
        }
    };
}

#pragma mark - Convenience methods

- (NUCompositeAnimation * (^)(NUProgressAnimationBlock))alongSideBlock {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NUProgressAnimationBlock block) {
        __strong typeof(self) self = weakself;
        self.progressBlock = block;
        return self;
    };
}

- (NUCompositeAnimation * (^)(NUAnimationType))withType {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NUAnimationType type) {
        __strong typeof(self) self = weakself;
        self.type = type;
        if (type == NUAnimationTypeSpringy) {
            self.options = [[NUSpringAnimationOptions alloc] init];
        }
        return self;
    };
}

- (NUCompositeAnimation * (^)(NSTimeInterval))withDelay {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NSTimeInterval delay) {
        __strong typeof(self) self = weakself;
        self.delay = delay;
        return self;
    };
}
- (NUCompositeAnimation * (^)(NUCompletionBlock))andThen {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NUCompletionBlock completion) {
        __strong typeof(self) self = weakself;
        self.completionBlock = completion;
        return self;
    };
}

- (NUCompositeAnimation * (^)(UIViewAnimationCurve))withCurve {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(UIViewAnimationCurve curve) {
        __strong typeof(self) self = weakself;
        self.options.curve = curve;
        return self;
    };
}

- (NUCompositeAnimation * (^)(UIViewAnimationOptions))withAnimationOption {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(UIViewAnimationOptions options) {
        __strong typeof(self) self = weakself;
        self.options.options = options;
        return self;
    };
}

- (NUCompositeAnimation * (^)(NSTimeInterval))withDuration {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NSTimeInterval duration) {
        __strong typeof(self) self = weakself;
        self.options.duration = duration;
        return self;
    };
}

- (NUCompositeAnimation * (^)(NUAnimationOptions *))withOptions {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NUAnimationOptions *options) {
        __strong typeof(self) self = weakself;
        self.options = options;
        return self;
    };
}

- (NUCompositeAnimation * (^)(CGFloat))withInitialVelocity {
    __weak typeof(self) weakself = self;
    NSAssert(self.type == NUAnimationTypeSpringy, @"This can only be set in springy animations.");
    return ^NUCompositeAnimation*(CGFloat velocity) {
        __strong typeof(self) self = weakself;
        ((NUSpringAnimationOptions *)self.options).initialVelocity = velocity;
        return self;
    };
}

- (NUCompositeAnimation * (^)(CGFloat))withDamping {
    __weak typeof(self) weakself = self;
    NSAssert(self.type == NUAnimationTypeSpringy, @"This can only be set in springy animations.");
    return ^NUCompositeAnimation*(CGFloat damping) {
        __strong typeof(self) self = weakself;
        ((NUSpringAnimationOptions *)self.options).damping = damping;
        return self;
    };
}

- (NUCompositeAnimation * (^)(NUSimpleAnimationBlock))inParallelWith {
    __weak typeof(self) weakself = self;
    return ^NUCompositeAnimation*(NUSimpleAnimationBlock block) {
        __strong typeof(self) self = weakself;
        NUCompositeAnimation *result = [[NUCompositeAnimation alloc] init];
        result.animationBlock = block;
        self.parallelBlock = result;
        return result;
    };
}

#pragma mark - Private methods

- (void)cleanUp {
    [self.displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    self.progress = 1;
}

- (void)updateAnimationProgress {
    if (self.lastTimestamp == 0) {
        self.lastTimestamp = self.displayLink.timestamp;
        self.progress = 0;
        return;
    }
    
    self.progress += (self.displayLink.timestamp - self.lastTimestamp) / self.options.duration;
    self.lastTimestamp = self.displayLink.timestamp;
}

- (void)setProgress:(CGFloat)progress {
    _progress = MIN(progress, 1.0f);
    if (self.progressBlock) {
        self.progressBlock(_progress);
    }
}

@end