#import "RNGHExternalScroll.h"
#if !TARGET_OS_OSX
#import <objc/runtime.h>
#import "Handlers/RNNativeViewHandler.h"
#import "RNGestureHandler.h"

NSNotificationName const RNGHExternalScrollHandlerDidBindNotification = @"RNGHExternalScrollHandlerDidBind";
NSNotificationName const RNGHExternalScrollHandlerDidUnbindNotification = @"RNGHExternalScrollHandlerDidUnbind";

@interface RNGHExternalScrollRegistration : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, weak) RNGestureHandler *handler;
@property (nonatomic, weak) UIGestureRecognizer *panRecognizer;
@property (nonatomic, weak) UIGestureRecognizer *handlerRecognizer;
@property (nonatomic, weak) UIView *panOriginalView;
@property (nonatomic, weak) UIView *handlerOriginalView;
@property (nonatomic) BOOL hasHeaderTouches;
@end
@implementation RNGHExternalScrollRegistration
@end

@interface RNGHExternalScrollWeakOwner : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@end
@implementation RNGHExternalScrollWeakOwner
@end

@interface RNGHExternalScrollWeakHandler : NSObject
@property (nonatomic, weak) RNGestureHandler *handler;
@end
@implementation RNGHExternalScrollWeakHandler
@end

static char registrationKey;
static char viewOwnerKey;
static char auxiliaryHandlerKey;
static RNGHExternalScrollRegistration *Registration(UIGestureRecognizer *recognizer)
{
  NSCAssert(NSThread.isMainThread, @"Scroll ownership is main-thread-only");
  return objc_getAssociatedObject(recognizer, &registrationKey);
}

static BOOL HasActiveTouches(UIGestureRecognizer *recognizer)
{
  return recognizer.numberOfTouches != 0 || recognizer.state == UIGestureRecognizerStateBegan ||
      recognizer.state == UIGestureRecognizerStateChanged;
}

void RNGHExternalScrollSetViewOwner(UIView *view, UIScrollView *scrollView)
{
  NSCAssert(NSThread.isMainThread, @"Scroll ownership is main-thread-only");
  RNGHExternalScrollWeakOwner *owner = nil;
  if (scrollView) {
    owner = [RNGHExternalScrollWeakOwner new];
    owner.scrollView = scrollView;
  }
  objc_setAssociatedObject(view, &viewOwnerKey, owner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

UIScrollView *RNGHExternalScrollViewOwner(UIView *view)
{
  NSCAssert(NSThread.isMainThread, @"Scroll ownership is main-thread-only");
  return ((RNGHExternalScrollWeakOwner *)objc_getAssociatedObject(view, &viewOwnerKey)).scrollView;
}

BOOL RNGHExternalScrollAttach(UIScrollView *scrollView, RNGestureHandler *handler, UIView *host)
{
  NSCAssert(NSThread.isMainThread, @"Scroll ownership is main-thread-only");
  UIGestureRecognizer *dummy = handler.recognizer;
  UIGestureRecognizer *pan = scrollView.panGestureRecognizer;
  if (![handler isKindOfClass:RNNativeViewGestureHandler.class] || !dummy.view || pan.view != scrollView ||
      handler.manualActivation || handler.virtualViewTag != nil || ![scrollView isDescendantOfView:host] ||
      ![dummy.view isDescendantOfView:host] || [handler retrieveScrollView:dummy.view] != scrollView ||
      Registration(pan) || Registration(dummy) || HasActiveTouches(pan) || HasActiveTouches(dummy)) {
    return NO;
  }
  RNGHExternalScrollRegistration *registration = [RNGHExternalScrollRegistration new];
  registration.scrollView = scrollView;
  registration.handler = handler;
  registration.panRecognizer = pan;
  registration.handlerRecognizer = dummy;
  registration.panOriginalView = pan.view;
  registration.handlerOriginalView = dummy.view;
  objc_setAssociatedObject(pan, &registrationKey, registration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(dummy, &registrationKey, registration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  // UIView moves the original recognizers. UIKit still owns its own pan delegate and targets.
  [host addGestureRecognizer:dummy];
  [host addGestureRecognizer:pan];
  [(RNNativeViewGestureHandler *)handler rnghPrepareExternalScrollView:scrollView];
  [pan addTarget:dummy action:@selector(rnghObserveExternalScrollPan:)];
  return YES;
}

void RNGHExternalScrollRestore(UIScrollView *scrollView, BOOL cancelTouches)
{
  NSCAssert(NSThread.isMainThread, @"Scroll ownership is main-thread-only");
  UIGestureRecognizer *pan = scrollView.panGestureRecognizer;
  RNGHExternalScrollRegistration *registration = Registration(pan);
  if (!registration) {
    return;
  }
  UIGestureRecognizer *dummy = registration.handlerRecognizer;
  if (dummy) {
    [pan removeTarget:dummy action:@selector(rnghObserveExternalScrollPan:)];
  }
  BOOL panEnabled = pan.enabled;
  BOOL dummyEnabled = dummy.enabled;
  if (cancelTouches) {
    pan.enabled = NO;
    dummy.enabled = NO;
  }
  UIView *panView = registration.panOriginalView ?: scrollView;
  UIView *dummyView = registration.handlerOriginalView;
  [panView addGestureRecognizer:pan];
  if (dummy) {
    if (dummyView) {
      [dummyView addGestureRecognizer:dummy];
    } else {
      [dummy.view removeGestureRecognizer:dummy];
    }
  }
  objc_setAssociatedObject(pan, &registrationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if (dummy) {
    objc_setAssociatedObject(dummy, &registrationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  if (cancelTouches) {
    pan.enabled = panEnabled;
    dummy.enabled = dummyEnabled;
  }
}

void RNGHExternalScrollRestoreHandler(RNGestureHandler *handler)
{
  UIScrollView *owner = RNGHExternalScrollOwner(handler.recognizer);
  if (owner) {
    RNGHExternalScrollRestore(owner, YES);
  }
}

BOOL RNGHExternalScrollIsRegistered(UIGestureRecognizer *recognizer)
{
  return Registration(recognizer) != nil;
}
RNGestureHandler *RNGHExternalScrollHandler(UIGestureRecognizer *recognizer)
{
  RNGHExternalScrollWeakHandler *auxiliary = objc_getAssociatedObject(recognizer, &auxiliaryHandlerKey);
  return Registration(recognizer).handler ?: auxiliary.handler;
}
void RNGHExternalScrollSetAuxiliaryHandler(UIGestureRecognizer *recognizer, RNGestureHandler *handler)
{
  NSCAssert(NSThread.isMainThread, @"Scroll ownership is main-thread-only");
  RNGHExternalScrollWeakHandler *association = nil;
  if (handler) {
    association = [RNGHExternalScrollWeakHandler new];
    association.handler = handler;
  }
  objc_setAssociatedObject(recognizer, &auxiliaryHandlerKey, association, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
UIScrollView *RNGHExternalScrollOwner(UIGestureRecognizer *recognizer)
{
  return Registration(recognizer).scrollView;
}
UIView *RNGHExternalScrollOriginalView(UIGestureRecognizer *recognizer)
{
  RNGHExternalScrollRegistration *registration = Registration(recognizer);
  return recognizer == registration.panRecognizer ? registration.panOriginalView : registration.handlerOriginalView;
}
void RNGHExternalScrollRecordTouches(UIGestureRecognizer *recognizer, NSSet<UITouch *> *touches)
{
  RNGHExternalScrollRegistration *registration = Registration(recognizer);
  if (!registration) {
    return;
  }
  for (UITouch *touch in touches) {
    if (touch.view && ![touch.view isDescendantOfView:registration.scrollView]) {
      registration.hasHeaderTouches = YES;
    }
  }
}
void RNGHExternalScrollResetTouches(UIGestureRecognizer *recognizer)
{
  Registration(recognizer).hasHeaderTouches = NO;
}
void RNGHExternalScrollRecordHitView(UIGestureRecognizer *recognizer, UIView *hitView)
{
  RNGHExternalScrollRegistration *registration = Registration(recognizer);
  if (registration && ![hitView isDescendantOfView:registration.scrollView]) {
    registration.hasHeaderTouches = YES;
  }
}
BOOL RNGHExternalScrollHasHeaderTouches(UIGestureRecognizer *recognizer)
{
  return Registration(recognizer).hasHeaderTouches;
}
#endif
