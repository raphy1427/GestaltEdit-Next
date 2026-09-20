//
//  BadQueryBridge.h
//  GestaltEdit
//
//  Path-based ContainerManager query derived from forcequitOS/bad_query.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BadQueryLease : NSObject

@property(nonatomic, copy, readonly) NSString *targetPath;
@property(nonatomic, readonly, getter=isActive) BOOL active;

+ (nullable instancetype)leaseForPath:(NSString *)path
                                error:(NSString * _Nullable * _Nullable)error;

/// Same operation as leaseForPath:error:, but also reports the exact internal
/// stage reached. Intended for Research Mode diagnostics.
+ (nullable instancetype)leaseForPath:(NSString *)path
                                stage:(NSString * _Nullable * _Nullable)stage
                                error:(NSString * _Nullable * _Nullable)error;
- (void)invalidate;

@end

FOUNDATION_EXPORT BOOL BadQueryBridgeAvailable(void);

/// Returns symbol-level diagnostics for the legacy ContainerManager path.
/// This only performs dlopen/dlsym discovery; it does not create a query,
/// consume a sandbox extension, or touch MobileGestalt.
FOUNDATION_EXPORT NSDictionary<NSString *, id> *BadQueryBridgeDiagnostics(void);

NS_ASSUME_NONNULL_END
