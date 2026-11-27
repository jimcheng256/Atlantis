"""Exercise the actual HID reader and Computer Idle comparison with stubbed IOKit."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
READER = ROOT / "Utility Classes/HIDIdleTime.m"
CONDITION = ROOT / "Event System/Conditions/Condition-ComputerIdle.m"

SHIMS = r'''
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
CFMutableDictionaryRef probeMatch(const char *name);
kern_return_t probeServices(mach_port_t port, CFDictionaryRef match, io_iterator_t *iterator);
io_object_t probeNext(io_iterator_t iterator);
kern_return_t probeRelease(io_object_t object);
kern_return_t probeProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties,
                              CFAllocatorRef allocator, IOOptionBits options);
void probeCFRelease(CFTypeRef value);
#define IOServiceMatching probeMatch
#define IOServiceGetMatchingServices probeServices
#define IOIteratorNext probeNext
#define IOObjectRelease probeRelease
#define IORegistryEntryCreateCFProperties probeProperties
#define CFRelease probeCFRelease
'''

FIXTURE = r'''
#import "HIDIdleTime.h"
#include <math.h>
#undef CFRelease

static NSString *scenario;
static id payload;
static unsigned advances, iteratorReleases, entryReleases, reads, propertyReleases;

CFMutableDictionaryRef probeMatch(const char *name) {
    return CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
}

kern_return_t probeServices(mach_port_t port, CFDictionaryRef match, io_iterator_t *iterator) {
    CFRelease(match);
    *iterator = [scenario isEqualToString:@"no-iterator"] ? 0 : 7;
    return [scenario isEqualToString:@"match-error"] ? KERN_FAILURE : KERN_SUCCESS;
}

io_object_t probeNext(io_iterator_t iterator) {
    advances++;
    return [scenario isEqualToString:@"no-entry"] ? 0 : 8;
}

kern_return_t probeRelease(io_object_t object) {
    if (object == 7) iteratorReleases++;
    if (object == 8) entryReleases++;
    return KERN_SUCCESS;
}

kern_return_t probeProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties,
                              CFAllocatorRef allocator, IOOptionBits options) {
    reads++;
    if ([scenario isEqualToString:@"no-properties"])
        return KERN_FAILURE;
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    if (payload)
        dictionary[@"HIDIdleTime"] = payload;
    *properties = (CFMutableDictionaryRef)dictionary;
    return [scenario isEqualToString:@"read-error"] ? KERN_FAILURE : KERN_SUCCESS;
}

void probeCFRelease(CFTypeRef value) {
    propertyReleases++;
    CFRelease(value);
}

@class AtlantisState;
@interface ConditionProbe : NSObject {
@public NSTimeInterval _rdInterval;
}
@end
@implementation ConditionProbe
'''

DRIVER = r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        scenario = [NSString stringWithUTF8String:argv[1]];
        NSString *type = [NSString stringWithUTF8String:argv[2]];
        uint64_t value = strtoull(argv[3], NULL, 10);
        if ([type isEqualToString:@"number"])
            payload = @(value);
        else if ([type isEqualToString:@"float"])
            payload = @(strtod(argv[3], NULL));
        else if ([type isEqualToString:@"data"])
            payload = [NSData dataWithBytes:&value length:sizeof(value)];
        else if ([type isEqualToString:@"short"])
            payload = [NSData dataWithBytes:&value length:1];
        else if ([type isEqualToString:@"long"])
            payload = [NSMutableData dataWithLength:9];
        else if ([type isEqualToString:@"string"])
            payload = @"600";

        if (strcmp(argv[4], "read") == 0) {
            HIDIdleTime *reader = [HIDIdleTime new];
            uint64_t actual = 42;
            BOOL read = [reader readIdleTime:&actual];
            [reader release];
            printf("%d %llu\n", read, (unsigned long long)actual);
        } else {
            ConditionProbe *condition = [ConditionProbe new];
            condition->_rdInterval = strtod(argv[4], NULL);
            printf("%d\n", [condition isTrueForState:nil]);
        }
        printf("%u %u %u %u %u\n", advances, iteratorReleases, entryReleases, reads, propertyReleases);
    }
}
'''


class ComputerIdleReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        match = re.search(r"^- \(BOOL\) isTrueForState:.*?^}", CONDITION.read_text(), re.M | re.S)
        if match is None:
            raise ValueError("Expected the Computer Idle comparison")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-computer-idle.")
        cls.addClassCleanup(temp.cleanup)
        directory = Path(temp.name)
        shims = directory / "shims.h"
        shims.write_text(SHIMS)
        source = directory / "probe.m"
        source.write_text(FIXTURE + match[0] + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "Foundation", "-framework", "IOKit", "-include", str(shims),
                        "-I", str(READER.parent), str(READER), str(source), "-o", str(cls.exe)], check=True)

    def check(self, scenario, kind, value, command, expected):
        output = subprocess.check_output([self.exe, scenario, kind, str(value), str(command)], text=True)
        self.assertEqual(output, expected)

    def test_acquisition_and_read_failures_release_owned_resources(self):
        for scenario, counts in (("match-error", "0 1 0 0 0"), ("no-iterator", "0 0 0 0 0"),
                                 ("no-entry", "1 1 0 0 0"), ("no-properties", "1 1 1 1 0"),
                                 ("read-error", "1 1 1 1 1")):
            with self.subTest(scenario=scenario):
                self.check(scenario, "number", 0, "read", f"0 42\n{counts}\n")
                self.check(scenario, "number", 0, 0, f"0\n{counts}\n")

    def test_decode_accepts_zero_and_full_width_integer_values(self):
        for kind in ("number", "data"):
            for value in (0, 600_000_000_000, 2**64 - 1):
                with self.subTest(kind=kind, value=value):
                    self.check("success", kind, value, "read", f"1 {value}\n1 1 1 1 1\n")

    def test_invalid_values_do_not_overwrite_the_result(self):
        for kind, value in (("short", 0), ("long", 0), ("string", 0), ("missing", 0),
                            ("float", -1), ("float", 0.5), ("float", "nan"),
                            ("float", "inf"), ("float", 2**64)):
            with self.subTest(kind=kind, value=value):
                self.check("success", kind, value, "read", "0 42\n1 1 1 1 1\n")

    def test_condition_matches_at_whole_and_fractional_thresholds(self):
        for nanoseconds, threshold in ((0, 0), (600_000_000_000, 600), (600_125_000_000, 600.125)):
            with self.subTest(threshold=threshold):
                if nanoseconds:
                    self.check("success", "number", nanoseconds - 1, threshold, "0\n1 1 1 1 1\n")
                self.check("success", "number", nanoseconds, threshold, "1\n1 1 1 1 1\n")
        self.check("success", "short", 0, 0, "0\n1 1 1 1 1\n")


if __name__ == "__main__":
    unittest.main()
