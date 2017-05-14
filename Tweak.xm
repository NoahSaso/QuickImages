#import "Global.h"

static BOOL isEnabled = YES;
static NSArray *shortcuts = nil;
static NSMutableDictionary *_cachedImages = nil;

@interface CKMessageEntryRichTextView : UITextView
- (void)paste:(id)arg1;
@end

static NSString *getStringInStringFromArray(NSString *masterString, NSArray *array) {
	NSString *ret = nil;
	for(NSString *item in array) {
		if([masterString containsString:item]) {
			ret = item;
			break;
		}
	}
	return ret;
}

%hook CKMessageEntryContentView

- (void)textViewDidChange:(CKMessageEntryRichTextView *)textView {
	%orig;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if(isEnabled) {
			NSString *shortcut = getStringInStringFromArray([textView.text lowercaseString], shortcuts);
			if(shortcut != nil) {
				NSString *imagePath = PATH_FOR_SHORTCUT(shortcut);
				HBLogDebug(@"cached images %@ %@", [_cachedImages.allKeys componentsJoinedByString: @","], [_cachedImages.allValues componentsJoinedByString: @","]);
				UIImage *image = _cachedImages[shortcut];
				HBLogDebug(@"image %@", image);
				if(image != nil || [[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
					if(!image) {
						image = [UIImage imageWithContentsOfFile:imagePath];
						_cachedImages[shortcut] = image;
					}
					if(image != nil) {
						dispatch_async(dispatch_get_main_queue(), ^{
							textView.text = [textView.text stringByReplacingOccurrencesOfString:shortcut withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, textView.text.length)];
							UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
							NSArray *originalItems = pasteboard.items;
							[pasteboard setImage:image];
							[textView paste:nil];
							[pasteboard setItems:originalItems];
						});
					}
				}
			}
		}
	});
}

%end

static void reloadPreferences() {
	CFPreferencesAppSynchronize(APP_ID);

	Boolean isEnabledExists = NO;
	Boolean isEnabledRef = CFPreferencesGetAppBooleanValue(CFSTR("Enabled"), APP_ID, &isEnabledExists);
	isEnabled = isEnabledExists ? isEnabledRef : YES;

	shortcuts = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:SHORTCUTS_PATH error:nil];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		_cachedImages = [NSMutableDictionary new];
		for(NSString *shortcut in shortcuts) {
			NSString *imagePath = PATH_FOR_SHORTCUT(shortcut);
			if([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
				UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
				_cachedImages[shortcut] = image;
			}
		}
	});
}

%ctor {
	reloadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        (CFNotificationCallback)reloadPreferences,
        CFSTR("com.noahsaso.quickimages.pn"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
