# External scroll hosting

Experimental native integration for UIKit platforms. The API shape is subject
to review. There is no new JavaScript gesture or detector prop.

## Use case

A collapsible header may be a sibling of a horizontally paged set of scroll
views. A native coordinator can place the selected scroll view's existing pan
recognizer on their common ancestor so touches on the header use the selected
scroll view's own scrolling behavior.

Gesture Handler must continue to associate that recognizer with the original
scroll view and Native handler after its attachment view changes. The helpers
in `RNGHExternalScroll.h` provide that opt-in association and restoration.

The coordinator still owns page selection, touch-stream tracking, horizontal
paging policy, and the lifetime of the shared host. Gesture Handler does not
choose a scroll view by searching its siblings.

## Relation to the existing API

Keep the Native gesture attached to the actual scroll component through a
native detector. Do not add another Native gesture to a component that already
wraps one. Virtual targets and manual activation are not supported by this
experimental integration; attachment rejects those configurations.

`simultaneousWith`, `requireToFail`, and `block` describe relationships between
recognizers. They do not relocate a `UIScrollView` pan. Virtual detectors keep
the host hierarchy intact but do not provide external scroll ownership either.

This feature extends the supported native integration surface. It does not
change the documented setup for ordinary scroll views.

## Ownership contract

- Call every helper on the main thread.
- Register concrete view-to-scroll associations with
  `RNGHExternalScrollSetViewOwner`. Pass `nil` to remove them. These associations
  are weak and are separate from the lifetime of an attached pan.
- Attach only a bound Native handler belonging to the specified scroll view.
  The shared host must be an ancestor of the original views. Attach returns
  `NO` when the registration or gesture state is incompatible.
- Defer ownership changes until **all** pointers are released, including
  touches that have not activated a recognizer. The coordinator must track
  this; recognizer state alone cannot identify every pending touch stream.
- Restore before removing or recycling the original page, handler or host.
  Original view references are weak to avoid retaining a view hierarchy.
- Restore before changing the handler's virtual target or manual-activation
  configuration. Neither configuration is supported while externally hosted.
- Handler unbind restores registered recognizers automatically. This is a
  cleanup safeguard, not a replacement for the coordinator's lifecycle.

The following illustrates an initial attachment. The coordinator supplies the
actual bound handler, its original detector or wrapper, and the scroll view.
Before switching owners, restore the previous attachment and clear its mapping.

```objc
#import <RNGestureHandler/RNGHExternalScroll.h>

// Called only while the coordinator has no in-progress pointer stream.
RNGHExternalScrollSetViewOwner(detectorOrWrapper, selectedScrollView);
if (!RNGHExternalScrollAttach(selectedScrollView, nativeHandler, sharedHost)) {
  RNGHExternalScrollSetViewOwner(detectorOrWrapper, nil);
  // Wait for the next bind/lifecycle event before trying again.
  return;
}

// Before a page/host detaches, or when switching owners after touches finish:
RNGHExternalScrollRestore(selectedScrollView, YES);
RNGHExternalScrollSetViewOwner(detectorOrWrapper, nil);
```

Clear every additional view association that the coordinator registered.
`RNGHExternalScrollHandlerDidBindNotification` and
`RNGHExternalScrollHandlerDidUnbindNotification` let it reconcile registration
with handler lifecycle events. Remove notification observers at teardown.

## Touch origin and events

The relocated Native handler records incoming touches. A coordinator that
observes hit testing earlier can call `RNGHExternalScrollRecordHitView`, or pass
its native touches to `RNGHExternalScrollRecordTouches`. This identifies a
header-origin drag even when UIKit starts its pan before the dummy handler's
touch callback runs.

When a header-origin drag activates, Gesture Handler uses its existing root
responder-cancellation path, respecting `cancelsJSResponder`. List-origin
streams retain the existing scroll-view responder handling. Coordinates and
event targets are resolved against the original handler view.

An optional native paging gate can use
`RNGHExternalScrollSetAuxiliaryHandler` to participate in the same handler
relations. This does not turn the gate into a scroll pan. Clear the association
when the gate detaches.

The integration uses the original UIKit recognizers, delegate and targets. It
does not synthesize scroll events, issue per-frame scroll commands, replace
UIKit's delegate, or install a global swizzle. Touch-delay behavior is still
owned by the original scroll view; header-control highlighting requires its
own device verification.

## Verification

`BasicExampleTests` exercises native ownership, rejection paths, restoration,
coordinates and association cleanup. On macOS, install the example's pods and
run its shared `BasicExample` scheme with an available iOS simulator:

```sh
cd apps/basic-example/ios
bundle exec pod install
xcodebuild test \
  -workspace BasicExample.xcworkspace \
  -scheme BasicExample \
  -destination 'platform=iOS Simulator,name=<installed simulator name>'
```

These tests do not establish UIKit's physical gesture behavior. A consuming
native host must also verify header/list drags, tap cancellation, refresh,
horizontal paging, nested gestures, multitouch, interrupted momentum,
backgrounding and accessibility on a device. The original app prototype
compiled in an iOS development build; the port and added XCTest suite require
a macOS/Xcode run.

## Source and documentation review

The relevant ownership assumptions were checked against published 3.3.0
(`3f5e6d870e1249b766a15e283b0c2aa427899f06`) and upstream main
(`e26231e9d89ec25f45ff3961d76c575ec6f04700`) on September 26, 2026.

Relevant documentation:

- [Native gesture](https://docs.swmansion.com/react-native-gesture-handler/docs/gestures/use-native-gesture/)
- [Gesture detectors](https://docs.swmansion.com/react-native-gesture-handler/docs/core-components/gesture-detector/)
- [Composition and interactions](https://docs.swmansion.com/react-native-gesture-handler/docs/composition/overview/)
- [Migration to Gesture Handler 3](https://docs.swmansion.com/react-native-gesture-handler/docs/guides/upgrading-to-3/)
