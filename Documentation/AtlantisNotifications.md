# Event notifications

Atlantis replaces its deprecated Growl integration with a Swift
implementation that uses Apple's `UserNotifications` framework to deliver
local notifications through Notification Center on modern macOS.

The **Atlantis: Display Notification** event action expands its title and
message using the event's variables and posts a local macOS notification
through the Swift `AtlantisNotifications` service. The first nonempty
notification request asks for permission. macOS controls notification
presentation through System Settings. Clicking an event notification selects
its originating spawn if that spawn is still available.

`Action_Notification` decodes older `Action_Growl` archives using the
existing coding keys so saved events continue to load. The scripting bridge
sends notifications through `systemNotification:withTitle:`. The legacy
`growlText:withTitle:` selector forwards to it.

Run the hosted notification tests with the shared Atlantis scheme.

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -only-testing:AtlantisTests/AtlantisNotificationsTests test
```

The tests exercise the archived event action and spawn selection in the host
app. They substitute the system authorization and submission calls so the
suite can run without changing the user's notification permission.

## Live macOS notification test

In an interactive macOS session, build the hosted app with signing enabled
and opt in to the live test by adding an environment variable to a copy of the
generated test-run file. Keep that copy beside the original so Xcode can find
the test host.

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/atlantis-live-notifications \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES build-for-testing
run_file=$(find /tmp/atlantis-live-notifications/Build/Products -name 'Atlantis_*.xctestrun' -print -quit)
live_run="$(dirname "$run_file")/Atlantis-live.xctestrun"
cp "$run_file" "$live_run"
plutil -insert AtlantisTests.EnvironmentVariables.ATLANTIS_LIVE_NOTIFICATIONS \
  -string 1 "$live_run"
plutil -replace AtlantisTests.CommandLineArguments -json \
  '["-lemuria.display.style", "source"]' "$live_run"
xcodebuild -xctestrun "$live_run" -destination 'platform=macOS' \
  -only-testing:AtlantisTests/AtlantisNotificationsTests/testLiveWorldEventNotificationDeliveryAndClick \
  test-without-building
```

Allow Atlantis notifications if macOS prompts. When the test notification
appears, open it from the banner or Notification Center and leave the test
spawns untouched. The test confirms delivery through the system API and
checks that macOS's response callback selects **Source**. It waits up to
60 seconds for each stage. A previously authorized installation can exercise
delivery and click handling using its existing permission.
