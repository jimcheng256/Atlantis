"""Exercise Atlantis format call sites in a standalone macOS process."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def expression(path, pattern):
    matches = re.findall(pattern, (ROOT / path).read_text())
    if len(matches) != 1:
        raise ValueError(f"Expected one format call in {path}, found {len(matches)}")
    return matches[0]


def probe_source():
    connected = expression(
        "Event System/AtlantisState.m",
        r'setExtraData:(\[NSString stringWithFormat:[^\n]+\]) forKey:@"world\.connected"',
    )
    idle = expression(
        "Event System/Conditions/Condition-ComputerIdle.m",
        r'(\[NSString stringWithFormat:@"Computer has been idle [^\n]+?\]) retain',
    )
    session = expression(
        "Worlds/RDAtlantisWorldInstance.m",
        r'_rdMcpSessionKey = \[(\[NSString stringWithFormat:[^\n]+?\]) retain',
    ).replace("[[NSDate date] timeIntervalSinceReferenceDate]", "seconds")
    regex_log = expression(
        "Utility Classes/RDStringPattern.m",
        r'(NSLog\([^;\n]*Ignoring invalid regexp:[^;\n]+\);)',
    )
    alert_pattern = r'(\[NSAlert alertWithMessageText:question[^\n]+\])'
    spawn_alert = expression("Preferences/World/WorldSpawnEditor.m", alert_pattern)
    address_alert = expression("Worlds/AddressBook.m", alert_pattern)
    return (
        '#import <Cocoa/Cocoa.h>\n#import "MCP System/MCPMessage.m"\n'
        f"static NSString *connected(double secs) {{ return {connected}; }}\n"
        f"static NSString *idle(double _rdInterval) {{ return {idle}; }}\n"
        f"static NSString *session(double seconds) {{ return {session}; }}\n"
        f"static void logRegex(NSString *_rdPattern) {{ {regex_log} }}\n"
        f"static NSAlert *spawnAlert(NSString *question, NSString *info) {{ return {spawn_alert}; }}\n"
        f"static NSAlert *addressAlert(NSString *question, NSString *info) {{ return {address_alert}; }}\n"
        + r'''
static void printLine(NSString *value) {
    puts(value.UTF8String);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *test = @(argv[1]);
        if ([test isEqualToString:@"connected"]) {
            printLine(connected(0));
            printLine(connected(0.875));
            printLine(connected(42.875));
            printLine(connected(4294967296.875));
        } else if ([test isEqualToString:@"idle"]) {
            printLine(idle(0));
            printLine(idle(600));
            printLine(idle(600.125));
        } else if ([test isEqualToString:@"session"]) {
            printLine(session(817235520.875));
        } else if ([test isEqualToString:@"regex"]) {
            logRegex(@"[abc");
            logRegex(@"[%@ 100%%");
        } else if ([test isEqualToString:@"spawn-alert"] || [test isEqualToString:@"address-alert"]) {
            [NSApplication sharedApplication];
            NSAlert *(*alert)(NSString *, NSString *) =
                [test isEqualToString:@"spawn-alert"] ? spawnAlert : addressAlert;
            printLine([alert(@"Confirm?", [NSString stringWithFormat:@"Remove %@?", @"sample"]) informativeText]);
            printLine([alert(@"Confirm?", [NSString stringWithFormat:@"Remove %@ at 100%%?", @"sample"]) informativeText]);
        } else if ([test isEqualToString:@"mcp"]) {
            s_dataCounter = strtoul(argv[2], NULL, 16);
            MCPMessage *message = [[MCPMessage alloc] initWithNamespace:@"test" command:@"probe"];
            [message setSessionKey:@"key"];
            [message addText:@"one" toAttribute:@"content"];
            [message addText:@"café" toAttribute:@"content"];
            fputs([message messageString].UTF8String, stdout);
            [message release];
        } else {
            return 2;
        }
    }
    return 0;
}
'''
    )


class WarningFormatTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-warning-formats.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Werror=format", "-Werror=format-security",
             "-Wno-deprecated-declarations", "-I", str(ROOT), "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def probe(self, *arguments):
        return subprocess.run([self.executable, *arguments], capture_output=True, check=True)

    def test_world_connected_reports_completed_seconds(self):
        self.assertEqual(self.probe("connected").stdout, b"0\n0\n42\n4294967296\n")

    def test_computer_idle_preserves_configured_precision(self):
        self.assertEqual(
            self.probe("idle").stdout,
            b"Computer has been idle 0 seconds.\n"
            b"Computer has been idle 600 seconds.\n"
            b"Computer has been idle 600.125 seconds.\n",
        )

    def test_mcp_session_key_uses_completed_reference_date_seconds(self):
        self.assertEqual(self.probe("session").stdout, b"817235520\n")

    def test_invalid_regex_log_preserves_literal_percent_sequences(self):
        payloads = [
            line.split(b"Ignoring invalid regexp: ", 1)[1]
            for line in self.probe("regex").stderr.splitlines()
            if b"Ignoring invalid regexp: " in line
        ]
        self.assertEqual(payloads, [b"[abc", b"[%@ 100%%"])

    def test_world_spawn_alert_preserves_plain_and_percent_text(self):
        self.assertEqual(self.probe("spawn-alert").stdout, b"Remove sample?\nRemove sample at 100%?\n")

    def test_address_book_alert_preserves_plain_and_percent_text(self):
        self.assertEqual(self.probe("address-alert").stdout, b"Remove sample?\nRemove sample at 100%?\n")

    def test_mcp_multiline_wire_bytes_across_hex_width_boundaries(self):
        for counter, tag in (
            ("0", "atl0000"), ("ffff", "atlffff"), ("10000", "atl10000"),
            ("ffffffff", "atlffffffff"), ("100000000", "atl100000000"),
        ):
            with self.subTest(counter=counter):
                expected = (
                    f'#$#test-probe key  content*: "" _data-tag: {tag}\n'
                    f"#$#* {tag} content: one\n"
                    f"#$#* {tag} content: café\n"
                    f"#$#: {tag}\n"
                ).encode("utf-8")
                self.assertEqual(self.probe("mcp", counter).stdout, expected)


if __name__ == "__main__":
    unittest.main()
