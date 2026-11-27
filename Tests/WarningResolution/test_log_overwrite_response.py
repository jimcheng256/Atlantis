"""Verify that only an explicit overwrite-alert button chooses a file action."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


LOG_SYSTEM = Path(__file__).resolve().parents[2] / "Log System"


class LogOverwriteResponseTests(unittest.TestCase):
    def test_cancel_and_unexpected_responses_do_not_authorize_file_actions(self):
        header = (LOG_SYSTEM / "RDLogType.h").read_text()
        modes = re.search(r"typedef NS_ENUM\(NSInteger, RDLogSaveMode\) \{.*?\};", header, re.S)
        opener = (LOG_SYSTEM / "RDLogOpener.m").read_text()
        decision = re.search(r"^static BOOL RDLogModeForAlertResponse.*?^}", opener, re.S | re.M)
        self.assertIsNotNone(modes)
        self.assertIsNotNone(decision)
        with tempfile.TemporaryDirectory(prefix="atlantis-overwrite-response.") as temp:
            source = Path(temp) / "probe.m"
            source.write_text("#import <AppKit/AppKit.h>\n#include <assert.h>\n"
                              + modes[0] + "\n" + decision[0] + r'''
int main(void) {
    RDLogSaveMode mode = RDLogSaveModeCreate;
    assert(!RDLogModeForAlertResponse(NSAlertSecondButtonReturn, YES, &mode));
    assert(!RDLogModeForAlertResponse(NSModalResponseAbort, YES, &mode));
    assert(!RDLogModeForAlertResponse(NSAlertFirstButtonReturn + 4294967296LL, YES, &mode));
    assert(!RDLogModeForAlertResponse(NSAlertThirdButtonReturn, NO, &mode));
    assert(mode == RDLogSaveModeCreate);
    assert(RDLogModeForAlertResponse(NSAlertFirstButtonReturn, NO, &mode));
    assert(mode == RDLogSaveModeReplace);
    assert(RDLogModeForAlertResponse(NSAlertThirdButtonReturn, YES, &mode));
    assert(mode == RDLogSaveModeAppend);
}
''')
            executable = source.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-framework", "AppKit", str(source), "-o", str(executable)],
                check=True,
            )
            subprocess.run([executable], check=True)


if __name__ == "__main__":
    unittest.main()
