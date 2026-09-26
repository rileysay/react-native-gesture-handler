#import <Foundation/Foundation.h>
#import "RNGHUIKit.h"

#if !TARGET_OS_OSX
@class RNGestureHandler;
NS_ASSUME_NONNULL_BEGIN

// Experimental, opt-in ownership for an existing UIKit scroll pan hosted on an
// ancestor. All calls must be on the main thread. UIKit's delegate and existing
// targets are preserved. The caller owns the hierarchy and must restore before
// removing its page or host; original views are weakly referenced to avoid cycles.
FOUNDATION_EXPORT NSNotificationName const RNGHExternalScrollHandlerDidBindNotification;
FOUNDATION_EXPORT NSNotificationName const RNGHExternalScrollHandlerDidUnbindNotification;
FOUNDATION_EXPORT void RNGHExternalScrollSetViewOwner(UIView *view, UIScrollView *_Nullable scrollView);
FOUNDATION_EXPORT UIScrollView *_Nullable RNGHExternalScrollViewOwner(UIView *view);
// Register the wrapper-to-scroll-view path with SetViewOwner before attaching.
// Attachment fails without mutation for a mismatched handler, invalid hierarchy,
// existing registration, or recognizer that is already tracking touches.
// Manual activation and folded virtual targets are not supported: their
// activation blocker or hit target remains in the original view hierarchy.
// Restore before changing either of those configurations while attached.
FOUNDATION_EXPORT BOOL RNGHExternalScrollAttach(UIScrollView *scrollView, RNGestureHandler *handler, UIView *host);
FOUNDATION_EXPORT void RNGHExternalScrollRestore(UIScrollView *scrollView, BOOL cancelTouches);
FOUNDATION_EXPORT void RNGHExternalScrollRestoreHandler(RNGestureHandler *handler);
FOUNDATION_EXPORT BOOL RNGHExternalScrollIsRegistered(UIGestureRecognizer *recognizer);
FOUNDATION_EXPORT RNGestureHandler *_Nullable RNGHExternalScrollHandler(UIGestureRecognizer *recognizer);
// An explicit app coordinator gate may use the same RNGH relation/responder
// owner, without becoming a scroll pan or changing its own native delegate.
FOUNDATION_EXPORT void RNGHExternalScrollSetAuxiliaryHandler(
    UIGestureRecognizer *recognizer,
    RNGestureHandler *_Nullable handler);
FOUNDATION_EXPORT UIScrollView *_Nullable RNGHExternalScrollOwner(UIGestureRecognizer *recognizer);
FOUNDATION_EXPORT UIView *_Nullable RNGHExternalScrollOriginalView(UIGestureRecognizer *recognizer);
FOUNDATION_EXPORT void RNGHExternalScrollRecordTouches(UIGestureRecognizer *recognizer, NSSet<UITouch *> *touches);
FOUNDATION_EXPORT void RNGHExternalScrollRecordHitView(UIGestureRecognizer *recognizer, UIView *hitView);
FOUNDATION_EXPORT void RNGHExternalScrollResetTouches(UIGestureRecognizer *recognizer);
FOUNDATION_EXPORT BOOL RNGHExternalScrollHasHeaderTouches(UIGestureRecognizer *recognizer);
NS_ASSUME_NONNULL_END
#endif
