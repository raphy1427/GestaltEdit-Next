//
//  GestaltAccess.m
//  GestaltEdit
//
//  bad_query path traversal (iOS 26 / 27):
//       class 13, MobileGestalt SystemGroup, part 3, target absolute path,
//       flags 0x8000000000; directly consumes the sandbox token

#import "GestaltAccess.h"
#import "BadQueryBridge.h"

#import <errno.h>
#import <fcntl.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <string.h>
#import <unistd.h>

static NSString * const kGestaltPlistFileName = @"com.apple.MobileGestalt.plist";

static NSString * const kMobileGestaltCacheDirectory =
    @"/private/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";
static NSString * const kBadQueryMobileGestaltCacheDirectory =
    @"/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";

static NSError *GestaltError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"com.gestaltedit.access"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

static BOOL GestaltCanOpenReadWrite(NSString *path)
{
    int fd = open(path.fileSystemRepresentation,
                  O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return NO;
    close(fd);
    return YES;
}

static NSString *GestaltErrnoDescription(int value)
{
    if (value == 0) return @"None";
    const char *message = strerror(value);
    if (!message) return [NSString stringWithFormat:@"errno %d", value];
    return [NSString stringWithFormat:@"%s (errno %d)", message, value];
}

static BOOL GestaltWriteAll(int fd, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

@interface GestaltAccess ()
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@end

@implementation GestaltAccess
{
    BadQueryLease *_activeBadQueryLease;
}

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

+ (NSString *)currentOSBuild
{
    size_t length = 0;
    if (sysctlbyname("kern.osversion", NULL, &length, NULL, 0) != 0 ||
        length == 0) {
        return @"";
    }

    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (sysctlbyname("kern.osversion", data.mutableBytes, &length, NULL, 0) != 0)
        return @"";

    return [NSString stringWithUTF8String:data.bytes] ?: @"";
}


+ (NSString *)currentOSVersionString
{
    NSOperatingSystemVersion v = NSProcessInfo.processInfo.operatingSystemVersion;
    return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
}

+ (NSString *)currentDeviceIdentifier
{
    size_t length = 0;
    if (sysctlbyname("hw.machine", NULL, &length, NULL, 0) != 0 || length == 0)
        return @"Unknown";

    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (sysctlbyname("hw.machine", data.mutableBytes, &length, NULL, 0) != 0)
        return @"Unknown";

    return [NSString stringWithUTF8String:data.bytes] ?: @"Unknown";
}

+ (BOOL)isLegacyAccessPrimitiveAvailable
{
    // Deliberately limited to symbol discovery. Do not create a query or
    // consume a sandbox extension while running Research Mode.
    return BadQueryBridgeAvailable();
}

+ (NSDictionary<NSString *, id> *)legacyAccessDiagnostics
{
    return BadQueryBridgeDiagnostics();
}

+ (BOOL)isRunningSupportedOS
{
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    if (version.majorVersion != 27) return NO;

    static NSSet<NSString *> *verifiedBuilds;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        verifiedBuilds = [NSSet setWithArray:@[
            @"24A5355q", // iOS / iPadOS 27 beta 1
            @"24A5370h", // iOS / iPadOS 27 beta 2
            @"24A5380h", // iOS / iPadOS 27 beta 3
            @"24A5380i", // iPadOS 27 beta 3 v2
            @"24A5380l", // iOS / iPadOS 27 Public Beta 1 (revised beta 3)
            @"24A5390f"  // iOS / iPadOS 27 beta 4
        ]];
    });

    return [verifiedBuilds containsObject:self.currentOSBuild];
}

#pragma mark - Research Mode Diagnostics

- (NSDictionary<NSString *, id> *)runReadOnlyProbe
{
    NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary dictionary];
    result[@"schemaVersion"] = @2;
    result[@"timestampUTC"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0));
    result[@"build"] = GestaltAccess.currentOSBuild ?: @"";
    result[@"osVersion"] = GestaltAccess.currentOSVersionString ?: @"";
    result[@"device"] = GestaltAccess.currentDeviceIdentifier ?: @"Unknown";
    result[@"symbolsAvailable"] = @(BadQueryBridgeAvailable());
    result[@"writeAttempted"] = @NO;
    result[@"leaseAcquired"] = @NO;
    result[@"readOpenSucceeded"] = @NO;
    result[@"readSucceeded"] = @NO;
    result[@"fileSize"] = @0;
    result[@"sampleBytesRead"] = @0;
    result[@"legacyDiagnostics"] = BadQueryBridgeDiagnostics();
    NSString *diagnosticPath = [kMobileGestaltCacheDirectory stringByAppendingPathComponent:kGestaltPlistFileName];
    result[@"targetPath"] = diagnosticPath;

    struct stat pathStat = {0};
    errno = 0;
    int lstatResult = lstat(diagnosticPath.fileSystemRepresentation, &pathStat);
    int lstatErrno = errno;
    result[@"fileExists"] = @(lstatResult == 0);
    result[@"isSymlink"] = @(lstatResult == 0 && S_ISLNK(pathStat.st_mode));
    if (lstatResult != 0) {
        result[@"lstatErrnoText"] = GestaltErrnoDescription(lstatErrno);
    }

    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    if (version.majorVersion != 27) {
        result[@"stage"] = @"blocked";
        result[@"detail"] = @"Read-only research probe is limited to iOS/iPadOS 27 builds.";
        return result;
    }

    if (!BadQueryBridgeAvailable()) {
        result[@"stage"] = @"symbols";
        result[@"detail"] = @"Required legacy ContainerManager/sandbox symbols are unavailable.";
        return result;
    }

    NSString *target = [kBadQueryMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *livePath = [kMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];

    errno = 0;
    result[@"preLeaseReadable"] = @(access(livePath.fileSystemRepresentation, R_OK) == 0);
    int preLeaseErrno = errno;
    result[@"preLeaseErrno"] = @(preLeaseErrno);
    result[@"preLeaseErrnoText"] = GestaltErrnoDescription(preLeaseErrno);

    NSString *leaseDetail = nil;
    NSString *leaseStage = nil;
    BadQueryLease *lease = [BadQueryLease leaseForPath:target stage:&leaseStage error:&leaseDetail];
    result[@"leaseStage"] = leaseStage ?: @"unknown";
    if (!lease) {
        result[@"stage"] = @"lease";
        result[@"detail"] = leaseDetail ?: @"The legacy access query was rejected.";
        return result;
    }
    result[@"leaseAcquired"] = @YES;

    errno = 0;
    result[@"postLeaseReadable"] = @(access(livePath.fileSystemRepresentation, R_OK) == 0);
    int postLeaseErrno = errno;
    result[@"postLeaseErrno"] = @(postLeaseErrno);
    result[@"postLeaseErrnoText"] = GestaltErrnoDescription(postLeaseErrno);

    errno = 0;
    int fd = open(livePath.fileSystemRepresentation,
                  O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        int openErrno = errno;
        result[@"stage"] = @"open-read";
        result[@"openErrnoText"] = GestaltErrnoDescription(openErrno);
        result[@"detail"] = [NSString stringWithFormat:
            @"A temporary sandbox lease was acquired, but the plist could not be opened read-only: %@",
            GestaltErrnoDescription(openErrno)];
        [lease invalidate];
        return result;
    }
    result[@"readOpenSucceeded"] = @YES;

    struct stat st = {0};
    if (fstat(fd, &st) == 0 && st.st_size >= 0) {
        result[@"fileSize"] = @((unsigned long long)st.st_size);
        result[@"fileUID"] = @((unsigned int)st.st_uid);
        result[@"fileGID"] = @((unsigned int)st.st_gid);
        result[@"fileMode"] = @((unsigned int)(st.st_mode & 07777));
    }

    uint8_t prefix[16] = {0};
    errno = 0;
    ssize_t count = read(fd, prefix, sizeof(prefix));
    int readErrno = errno;
    close(fd);
    [lease invalidate];

    if (count < 0) {
        result[@"readErrnoText"] = GestaltErrnoDescription(readErrno);
        result[@"stage"] = @"read";
        result[@"detail"] = [NSString stringWithFormat:
            @"The plist opened read-only, but reading a small prefix failed: %@",
            GestaltErrnoDescription(readErrno)];
        return result;
    }

    result[@"readSucceeded"] = @YES;
    result[@"sampleBytesRead"] = @((long long)count);
    result[@"stage"] = @"complete";
    result[@"detail"] = @"Read-only access succeeded. No MobileGestalt values were parsed, changed, or written.";
    return result;
}

#pragma mark - Connection

- (BOOL)connectWithError:(NSError **)error
{
    if (!GestaltAccess.isRunningSupportedOS) {
        if (error) *error = GestaltError(0, NSLocalizedString(
            @"GestaltEdit currently supports only iOS and iPadOS 27 beta 1 through beta 4.", nil));
        return NO;
    }

    if (self.isConnected && _activeBadQueryLease.isActive &&
        self.plistPath.length > 0) {
        if (error) *error = nil;
        return YES;
    }

    if (!BadQueryBridgeAvailable()) {
        if (error) *error = GestaltError(1, NSLocalizedString(
            @"bad_query is unavailable (required ContainerManager or sandbox extension APIs are missing).", nil));
        return NO;
    }

    [_activeBadQueryLease invalidate];
    _activeBadQueryLease = nil;
    self.isConnected = NO;
    self.plistPath = nil;

    NSString *badQueryTarget = [kBadQueryMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryPlist = [kMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryDetail = nil;
    BadQueryLease *badQueryLease = [BadQueryLease leaseForPath:badQueryTarget
                                                        error:&badQueryDetail];
    if (!badQueryLease) {
        if (error) *error = GestaltError(2,
            badQueryDetail ?: NSLocalizedString(@"bad_query failed.", nil));
        return NO;
    }
    if (!GestaltCanOpenReadWrite(badQueryPlist)) {
        [badQueryLease invalidate];
        if (error) *error = GestaltError(3, NSLocalizedString(
            @"bad_query acquired a sandbox extension, but the MobileGestalt plist is not writable.", nil));
        return NO;
    }

    _activeBadQueryLease = badQueryLease;
    self.isConnected = YES;
    self.plistPath = badQueryPlist;
    if (error) *error = nil;
    return YES;
}

#pragma mark - Read / Write

- (NSData *)readGestaltDataWithError:(NSError **)error
{
    if (![self connectWithError:error]) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.plistPath]) {
        if (error) *error = GestaltError(3,
            [NSString stringWithFormat:NSLocalizedString(@"The plist does not exist: %@", nil), self.plistPath]);
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.plistPath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readError];
    if (!data) {
        if (error) *error = readError ?: GestaltError(4, NSLocalizedString(@"Failed to read the plist.", nil));
        return nil;
    }
    if (error) *error = nil;
    return data;
}

- (NSDictionary *)readGestaltWithError:(NSError **)error
{
    NSData *data = [self readGestaltDataWithError:error];
    if (!data) return nil;

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *parseError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:&format
                                                           error:&parseError];
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = parseError ?: GestaltError(5,
            NSLocalizedString(@"The plist top level is not a dictionary.", nil));
        return nil;
    }
    self.lastReadFormat = format;
    return plist;
}

- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error
{
    // Defense in depth: never let a direct caller reach serialization/open(2)
    // on an unverified build, even if connection logic changes in the future.
    if (!GestaltAccess.isRunningSupportedOS) {
        if (error) *error = GestaltError(12, [NSString stringWithFormat:
            @"MobileGestalt writes are disabled on this build (%@).",
            GestaltAccess.currentOSBuild.length > 0 ? GestaltAccess.currentOSBuild : @"unknown"]);
        return NO;
    }

    if (![self connectWithError:error]) return NO;
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(6, NSLocalizedString(@"The content to save is not a dictionary.", nil));
        return NO;
    }

    NSPropertyListFormat format = self.lastReadFormat;
    if (format != NSPropertyListXMLFormat_v1_0 &&
        format != NSPropertyListBinaryFormat_v1_0)
        format = NSPropertyListBinaryFormat_v1_0;

    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:format
                                                             options:0
                                                               error:&serializeError];
    if (!data) {
        if (error) *error = serializeError ?: GestaltError(7, NSLocalizedString(@"Failed to serialize the plist.", nil));
        return NO;
    }

    NSString *targetPath = self.plistPath;
    NSError *readError = nil;
    NSData *original = [NSData dataWithContentsOfFile:targetPath
                                              options:0
                                                error:&readError];
    if (!original) {
        if (error) *error = readError ?: GestaltError(8, NSLocalizedString(@"Failed to read the original plist.", nil));
        return NO;
    }

    int fd = open(targetPath.fileSystemRepresentation,
                  O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        if (error) *error = GestaltError(9,
            [NSString stringWithFormat:NSLocalizedString(@"Failed to open the plist (errno=%d).", nil), errno]);
        return NO;
    }

    BOOL wrote = ftruncate(fd, 0) == 0 &&
        lseek(fd, 0, SEEK_SET) == 0 &&
        GestaltWriteAll(fd, data) &&
        fsync(fd) == 0;
    int writeErrno = errno;

    if (!wrote) {
        ftruncate(fd, 0);
        lseek(fd, 0, SEEK_SET);
        GestaltWriteAll(fd, original);
        fsync(fd);
        close(fd);
        if (error) *error = GestaltError(10,
            [NSString stringWithFormat:NSLocalizedString(@"Failed to write the plist (errno=%d).", nil), writeErrno]);
        return NO;
    }
    close(fd);

    NSData *verification = [NSData dataWithContentsOfFile:targetPath];
    if (![verification isEqualToData:data]) {
        if (error) *error = GestaltError(11, NSLocalizedString(@"Post-write verification failed.", nil));
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

@end
