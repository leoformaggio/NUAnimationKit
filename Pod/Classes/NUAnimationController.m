//
//  NUAnimationController.m
//  NUAnimationKit
//
//  Created by Victor Maraccini on 1/21/16.
//  Copyright © 2016 Victor Gabriel Maraccini. All rights reserved.
//

#import "NUAnimationController.h"
#import <QuartzCore/QuartzCore.h>

@interface NUAnimationController ()

@property (nonatomic, strong) NSMutableArray *animationSteps;
@property (nonatomic, readonly) NSTimeInterval totalAnimationTime;

@property (nonatomic, readwrite) int animationStep;
@property (nonatomic, readwrite) BOOL animationRunning;
@property (nonatomic, readwrite) BOOL animationCancelled;

@end

@interface NUBaseAnimation (Private)
- (void)pauseLayerAnimations;
- (void)setTargetLayersOffset:(NSTimeInterval)offset;
@end

@implementation NUAnimationController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _animationSteps = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Public methods

- (NUBaseAnimation *)addAnimation:(NUBaseAnimation *)block {
    [self.animationSteps addObject:block];
    return block;
}

- (void)startAnimationChainWithCompletionBlock:(NUNoArgumentsBlock)completionBlock {
    self.completionBlock = completionBlock;
    [self startAnimationChain];
}

- (void)startAnimationChain {
    self.animationCancelled = false;
    self.animationStep = 0;
    if (self.animationRunning) {
        //Animation cannot be started multiple times.
        return;
    }

    self.animationRunning = true;

    if (self.initializationBlock) {
        self.initializationBlock();
    }

    [self startNextAnimation];
}

- (NUCompositeAnimation *)addAnimations: (NUSimpleAnimationBlock)animation {
    NUCompositeAnimation *result = [[NUCompositeAnimation alloc] init];
    result.animationBlock = animation;
    [self addAnimation:result];
    return result;
}

- (void)cancelAnimations {
    self.animationCancelled = true;
}

- (void)removeAnimation: (NUBaseAnimation *)animation {
    [self.animationSteps removeObject:animation];
}

- (void)removeAllAnimations {
    self.animationSteps = [[NSMutableArray alloc] init];
}

- (NSArray *)animations {
    return [self.animationSteps copy];
}

- (NUNoArgumentsBlock)allAnimations {
    return ^{
        for (NUBaseAnimation *animation in self.animationSteps) {
            animation.animationBlock();
        }
    };
}

-(void)animateToProgress:(CGFloat)progress {
    if (!self.animationRunning) {
        for (NUBaseAnimation *animation in self.animationSteps) {
            [self beginBlock:animation andChainToBlock:nil];
        }
        self.animationRunning = YES;
    }

    NSTimeInterval currentTime = 0;
    NSTimeInterval targetTime = progress * self.totalAnimationTime;
    for (NUBaseAnimation *animation in self.animationSteps) {
        CGFloat delay = animation.delay;
        [animation pauseLayerAnimations];

        if (currentTime + delay < targetTime) {
            if (currentTime + animation.options.duration + delay > targetTime) {
                //Animation in progress
                NSTimeInterval currentOffset = (targetTime - currentTime - delay);
                [animation setTargetLayersOffset:currentOffset];
            } else {
                //Animation done
                [animation setTargetLayersOffset:animation.options.duration + delay];
            }
        } else {
            [animation setTargetLayersOffset:0];
        }

        currentTime += animation.options.duration + delay;
    }
}

#pragma mark - Private

- (void)startNextAnimation {
    if (self.animationSteps.count == self.animationStep) {
        [self finishAnimations];
        return;
    }

    NUBaseAnimation *block = self.animationSteps[self.animationStep];
    [self setupBlock:block isParallel:false];

}

- (void)setupBlock:(NUBaseAnimation *)block isParallel: (BOOL)isParallel {
    __weak typeof(self) weakself = self;
    if ([block isKindOfClass:[NUCompositeAnimation class]]) {
        NUCompositeAnimation *composite = (NUCompositeAnimation *)block;
        if (composite.parallelBlock) {
            [self setupBlock:composite.parallelBlock isParallel:true];
        }
    }

    void (^continueBlock)(BOOL finished) = ^(BOOL finished){
        __strong typeof(self) self = weakself;
        if (!finished || self.animationCancelled) {
            self.animationCancelled = true;
            [block animationDidCancel];
            [self finishAnimations];
        } else {
            [block animationDidFinish];
            if (!isParallel) {
                self.animationStep++;
                [self startNextAnimation];
            }
        }
    };

    [block animationWillBegin];
    [self beginBlock:block andChainToBlock:continueBlock];
}

- (void)beginBlock:(NUBaseAnimation *)block
   andChainToBlock:(void(^)(BOOL finished))continueBlock {
    if (!continueBlock) {
        continueBlock = ^(BOOL _){};
    }

    if (block.type == NUAnimationTypeDefault) {
        [UIView animateWithDuration:block.options.duration
                              delay:block.delay
                            options:block.options.options
                         animations:^{
                             if (block.animationBlock) {
                                 block.animationBlock();
                             }
                         }
                         completion:continueBlock];

    } else if (block.type == NUAnimationTypeSpringy) {
        NUSpringAnimationOptions *springOptions = (NUSpringAnimationOptions *)block.options;
        [UIView animateWithDuration:block.options.duration
                              delay:block.delay
             usingSpringWithDamping:springOptions.damping
              initialSpringVelocity:springOptions.initialVelocity
                            options:block.options.options
                         animations:^{
                             if (block.animationBlock) {
                                 block.animationBlock();
                             }
                         }
                         completion:continueBlock];
    } else {
        @throw [NSException exceptionWithName:@"Uknown animation type"
                                       reason:@"Unknown animation block type"
                                     userInfo:nil];
    }
}

- (void)finishAnimations {
    self.animationRunning = false;

    if (self.animationCancelled) {
        if (self.shouldRunAllAnimationsIfCancelled) {
            self.allAnimations();
        }
        if (self.cancellationBlock) {
            self.cancellationBlock();
        }
        return;
    }

    if (self.completionBlock) {
        self.completionBlock();
    }
}

- (NSTimeInterval)totalAnimationTime {
    NSTimeInterval result = 0;
    for (NUBaseAnimation *animation in self.animationSteps) {
        if ([animation isKindOfClass:[NUCompositeAnimation class]]) {
            NUCompositeAnimation *parallel = ((NUCompositeAnimation *)animation).parallelBlock;
            if (parallel) {
                CGFloat this = animation.options.duration + animation.delay;
                CGFloat other = parallel.options.duration + parallel.options.duration;
                result += MAX(this, other);
                continue;
            }
        }
        result += animation.options.duration;
        result += animation.delay;
    }
    return result;
}

@end
